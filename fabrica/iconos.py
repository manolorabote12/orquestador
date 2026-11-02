"""Iconos del juego a la medida exacta de cada tienda y de Android.

	Google Play     512x512 PNG de 32 bits (con canal alfa, opaco). Cuadrado entero: Google
	                redondea las esquinas y pone la sombra; si las pintas tu, salen dobles.
	App Store       1024x1024 PNG SIN canal alfa, cuadrado entero (Apple aplica su mascara).
	Android         Icono adaptativo 432x432 (108 dp a 4x): fondo, primer plano con el heroe
	                dentro del circulo seguro central (66 dp = 264 px) y monocromo para los
	                iconos tematicos de Android 13+. Mas el clasico 192x192.

El dibujo: degradado del color de acento con un brillo detras del heroe, el heroe grande
(pixel art escalado sin suavizar) y una sombra suave a sus pies. Sin texto: en 48 px no se lee.
"""

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


def _hex(h: str) -> tuple:
	h = h.lstrip("#")
	return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _mezcla(a: tuple, b: tuple, k: float) -> tuple:
	return tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3))


def heroe(proyecto: Path) -> Image.Image | None:
	"""Primer fotograma de reposo del heroe, recortado a su contenido (o la ficha sin el magenta)."""
	idle = proyecto / "assets" / "heroe" / "idle.png"
	if idle.exists():
		tira = Image.open(idle).convert("RGBA")
		img = tira.crop((0, 0, min(tira.height, tira.width), tira.height))
	else:
		fichas = sorted((proyecto / "fabrica" / "arte").glob("heroe_ficha*.png"))
		if not fichas:
			return None
		img = Image.open(fichas[0]).convert("RGBA")
		img.putdata([(0, 0, 0, 0) if r > 200 and g < 60 and b > 200 else (r, g, b, a) for r, g, b, a in img.getdata()])
	caja = img.getbbox()
	return img.crop(caja) if caja else img


def _escalar(h: Image.Image, maximo: int) -> Image.Image:
	"""Pixel art: multiplo entero sin suavizar si se puede; si no, vecino mas cercano."""
	k = maximo / max(h.width, h.height)
	if k >= 1:
		k = max(1, int(k))
	return h.resize((max(1, int(h.width * k)), max(1, int(h.height * k))), Image.NEAREST)


def _paleta(proyecto: Path) -> tuple[tuple, tuple]:
	game = json.loads((proyecto / "game.json").read_text(encoding="utf-8"))
	pal = game.get("palette", {})
	return _hex(pal.get("accent", "#e8b04b")), _hex(pal.get("sky", "#1b2a41"))


def fondo(lado: int, acento: tuple, cielo: tuple) -> Image.Image:
	"""Degradado diagonal del acento hacia un tono mas profundo, con brillo radial en el centro."""
	claro = _mezcla(acento, (255, 255, 255), 0.18)
	oscuro = _mezcla(acento, cielo, 0.42)
	img = Image.new("RGB", (lado, lado))
	px = img.load()
	for y in range(lado):
		for x in range(lado):
			k = (x + y) / (2 * (lado - 1))
			px[x, y] = _mezcla(claro, oscuro, k)
	brillo = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
	r = int(lado * 0.36)
	ImageDraw.Draw(brillo).ellipse([lado // 2 - r, lado // 2 - r - lado // 20, lado // 2 + r, lado // 2 + r - lado // 20],
		fill=_mezcla(acento, (255, 255, 255), 0.65) + (120,))
	brillo = brillo.filter(ImageFilter.GaussianBlur(lado / 10))
	base = img.convert("RGBA")
	base.alpha_composite(brillo)
	return base


def _con_heroe(base: Image.Image, h: Image.Image | None, tam: float, centro_y: float, cielo: tuple) -> Image.Image:
	lado = base.width
	if h is None:
		return base
	hh = _escalar(h, int(lado * tam))
	sombra = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
	ancho = int(hh.width * 0.8)
	pie = int(lado * centro_y + hh.height / 2)
	ImageDraw.Draw(sombra).ellipse([lado // 2 - ancho // 2, pie - lado // 40, lado // 2 + ancho // 2, pie + lado // 40],
		fill=cielo + (110,))
	base.alpha_composite(sombra.filter(ImageFilter.GaussianBlur(lado / 90)))
	base.alpha_composite(hh, ((lado - hh.width) // 2, int(lado * centro_y - hh.height / 2)))
	return base


def icono_cuadrado(proyecto: Path, lado: int) -> Image.Image:
	"""Icono a sangre (sin esquinas redondeadas) en RGBA opaco."""
	acento, cielo = _paleta(proyecto)
	return _con_heroe(fondo(lado, acento, cielo), heroe(proyecto), 0.66, 0.5, cielo)


def guardar_play(proyecto: Path, destino: Path) -> Path:
	icono_cuadrado(proyecto, 512).save(destino)
	return destino


def guardar_appstore(proyecto: Path, destino: Path) -> Path:
	icono_cuadrado(proyecto, 1024).convert("RGB").save(destino)
	return destino


def adaptativo(proyecto: Path, carpeta: Path) -> dict[str, Path]:
	"""Los 4 iconos de Android. El heroe cabe en el circulo seguro (264 de 432 px)."""
	carpeta.mkdir(parents=True, exist_ok=True)
	acento, cielo = _paleta(proyecto)
	h = heroe(proyecto)
	fondo(432, acento, cielo).convert("RGB").save(carpeta / "fondo_432.png")
	frente = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
	if h is not None:
		## La diagonal del heroe cabe en el circulo seguro de 264 px (con 5 % de margen).
		r = min(h.width, h.height) / max(h.width, h.height)
		maximo = int(264 * 0.95 / math.sqrt(1 + r * r))
		hh = _escalar(h, maximo)
		frente.alpha_composite(hh, ((432 - hh.width) // 2, (432 - hh.height) // 2))
	frente.save(carpeta / "frente_432.png")
	mono = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
	alfa = frente.getchannel("A").point(lambda a: 255 if a > 40 else 0)
	mono.paste((255, 255, 255, 255), (0, 0), alfa)
	mono.save(carpeta / "monocromo_432.png")
	icono_cuadrado(proyecto, 192).save(carpeta / "icono_192.png")
	return {"fondo": carpeta / "fondo_432.png", "frente": carpeta / "frente_432.png",
		"monocromo": carpeta / "monocromo_432.png", "principal": carpeta / "icono_192.png"}


def aplicar_a_proyecto(proyecto: Path) -> None:
	"""icon.png del juego + iconos adaptativos en el preset de Android (los usa Godot al exportar)."""
	icono_cuadrado(proyecto, 256).save(proyecto / "icon.png")
	rutas = adaptativo(proyecto, proyecto / "android_iconos")
	opciones = {
		"launcher_icons/main_192x192": "res://android_iconos/icono_192.png",
		"launcher_icons/adaptive_foreground_432x432": "res://android_iconos/frente_432.png",
		"launcher_icons/adaptive_background_432x432": "res://android_iconos/fondo_432.png",
		"launcher_icons/adaptive_monochrome_432x432": "res://android_iconos/monocromo_432.png",
	}
	assert all(r.exists() for r in rutas.values())
	poner_opciones_android(proyecto, opciones)


def poner_opciones_android(proyecto: Path, opciones: dict[str, str]) -> None:
	"""Pone (o cambia) opciones en [preset.0.options] del export_presets.cfg."""
	ep = proyecto / "export_presets.cfg"
	lineas = ep.read_text(encoding="utf-8").splitlines()
	seccion = ""
	vistas: set[str] = set()
	out: list[str] = []
	fin_opciones = None
	for l in lineas:
		if l.startswith("["):
			if seccion == "[preset.0.options]":
				fin_opciones = len(out)
			seccion = l
		clave = l.split("=", 1)[0]
		if seccion == "[preset.0.options]" and clave in opciones:
			valor = opciones[clave]
			out.append(f"{clave}={_valor(valor)}")
			vistas.add(clave)
			continue
		out.append(l)
	if seccion == "[preset.0.options]":
		fin_opciones = len(out)
	nuevas = [f"{k}={_valor(v)}" for k, v in opciones.items() if k not in vistas]
	if nuevas:
		## Antes de la linea en blanco que cierra la seccion.
		pos = fin_opciones if fin_opciones is not None else len(out)
		while pos > 0 and out[pos - 1].strip() == "":
			pos -= 1
		out[pos:pos] = nuevas
	ep.write_text("\n".join(out) + "\n", encoding="utf-8")


def _valor(v) -> str:
	if isinstance(v, bool):
		return "true" if v else "false"
	if isinstance(v, int):
		return str(v)
	return f'"{v}"'

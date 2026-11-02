"""Iconos de interfaz dibujados por la IA (vidas, estrellas, trofeos): control y exportacion.

	python -m pruebas.prueba_iconos
"""

import io
import json
import math
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from PIL import Image, ImageDraw  # noqa: E402

from arte import godot_export, iconos  # noqa: E402

MAGENTA = (255, 0, 255)


def _png(img: Image.Image) -> bytes:
	b = io.BytesIO()
	img.save(b, "PNG")
	return b.getvalue()


def estrella(lado: int = 768) -> Image.Image:
	img = Image.new("RGB", (lado, lado), MAGENTA)
	c = lado / 2
	pts = []
	for k in range(10):
		r = lado * (0.42 if k % 2 == 0 else 0.18)
		a = -math.pi / 2 + k * math.pi / 5
		pts.append((c + math.cos(a) * r, c + math.sin(a) * r))
	ImageDraw.Draw(img).polygon(pts, fill=(250, 200, 40), outline=(60, 30, 10))
	return img


def cuadrado(lado: int = 768) -> Image.Image:
	img = Image.new("RGB", (lado, lado), MAGENTA)
	ImageDraw.Draw(img).rectangle((60, 60, lado - 60, lado - 60), fill=(30, 120, 220))
	return img


def raya(lado: int = 768) -> Image.Image:
	img = Image.new("RGB", (lado, lado), MAGENTA)
	ImageDraw.Draw(img).line((100, 380, 680, 390), fill=(30, 120, 220), width=10)
	return img


def torcida(lado: int = 768) -> Image.Image:
	img = Image.new("RGB", (lado, lado), MAGENTA)
	ImageDraw.Draw(img).polygon([(100, 100), (700, 100), (100, 700)], fill=(200, 60, 60))
	return img


class Cliente:
	"""Devuelve siempre la misma imagen (o falla) y cuenta lo que le piden."""

	def __init__(self, imagen: Image.Image | None):
		self.imagen = imagen
		self.prompts: list[str] = []

	def generar(self, flujo: dict, vars_: dict) -> list[bytes]:
		self.prompts.append(vars_["PROMPT"])
		if self.imagen is None:
			raise RuntimeError("sin GPU")
		return [_png(self.imagen)]


def main() -> int:
	fallos = 0

	def check(nombre: str, ok: bool, detalle: str = "") -> None:
		nonlocal fallos
		print(("  OK   " if ok else "  FALLO ") + nombre + (f"  ({detalle})" if detalle and not ok else ""))
		fallos += 0 if ok else 1

	biblia = {"juego": {"titulo": "Prueba"}, "estilo": {"descripcion": "cute pixel art", "fondo_chroma": "#FF00FF", "familia": "pixel_art",
		"paleta": ["#112233", "#FFCC00"]}, "personajes": [], "objetos": [], "escenarios": [{"descripcion": "a forest"}]}
	p = iconos.prompt(biblia, "heart")
	check("el prompt pide el icono, el estilo del juego y el fondo croma, sin texto", "heart" in p and "cute pixel art" in p and "#FF00FF" in p and "no text" in p, p)

	def rev(img: Image.Image) -> list[str]:
		from arte import post
		x = post.quitar_fondo(img.convert("RGBA"), MAGENTA)
		return iconos.revisar(x.crop(post.caja(x)))

	check("una estrella clara pasa el control", rev(estrella()) == [], str(rev(estrella())))
	check("un cuadrado lleno no es un icono", bool(rev(cuadrado())))
	check("una raya fina no es un icono", bool(rev(raya())))
	check("una forma torcida (no simetrica) no pasa", bool(rev(torcida())))
	sq = iconos.cuadrar(Image.new("RGBA", (300, 150), (255, 0, 0, 255)))
	check("cuadrar: 128x128 sin deformar (la pieza ancha queda centrada)", sq.size == (128, 128) and sq.getpixel((64, 64))[3] == 255 and sq.getpixel((64, 5))[3] == 0)

	tmp = Path(tempfile.mkdtemp())
	try:
		cli = Cliente(estrella())
		ico, inf = iconos.generar(biblia, tmp / "iconos", cli, {}, 7)
		check("con buen arte salen los 3 iconos", sorted(ico) == ["heart", "star", "trophy"] and inf["generaciones"] == 3, str(inf))
		check("cada icono es un png cuadrado", all(Image.open(r).size == (128, 128) for r in ico.values()))
		malo, inf2 = iconos.generar(biblia, tmp / "malos", Cliente(cuadrado()), {}, 7)
		check("si no pasan el control se reintenta y se queda sin ellos", malo == {} and inf2["generaciones"] == 6 and len(inf2["fallidos"]) == 3, str(inf2))
		nada, inf3 = iconos.generar(biblia, tmp / "nada", Cliente(None), {}, 7)
		check("sin GPU no hay iconos ni se rompe nada", nada == {} and inf3["generaciones"] == 0)
		## Exportacion al proyecto de Godot: los iconos entran en manifest -> ui -> iconos.
		godot = tmp / "godot"
		m = godot_export.exportar(godot, biblia, {}, {}, {}, fondos={"iconos": ico})
		man = json.loads(Path(m).read_text(encoding="utf-8"))
		check("el manifest lleva los iconos con su ruta res://", man["ui"].get("iconos", {}).get("star") == "res://assets/ui/iconos/star.png", str(man["ui"].get("iconos")))
		check("y los archivos se copian", (godot / "assets" / "ui" / "iconos" / "heart.png").exists() or (Path(m).parent / "ui" / "iconos" / "heart.png").exists())
		m2 = godot_export.exportar(godot, biblia, {}, {}, {}, fusionar=True)
		man2 = json.loads(Path(m2).read_text(encoding="utf-8"))
		check("al rehacer solo una parte del arte se conservan los iconos", "iconos" in man2["ui"])
	finally:
		shutil.rmtree(tmp, ignore_errors=True)
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

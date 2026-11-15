"""Exporta el arte y los sonidos al kit de Godot.

Escribe en <proyecto>/assets/:
	<id>/<anim>.png        hoja de sprites (frames en fila)
	tiles/<id>.png         tile repetible
	sfx/<efecto>.wav       efectos de sonido
	manifest.json          indice que el kit lee al arrancar (Kit.assets), con la interfaz en "ui"
"""

import json
import shutil
from pathlib import Path

from PIL import Image

from . import interfaz


def exportar(proyecto: Path, biblia: dict, hojas: dict, tiles: dict, sfx: dict,
		fusionar: bool = False, quitar: list[str] | None = None, pistas: dict | None = None, voces: dict | None = None,
		fondos: dict | None = None) -> Path:
	"""fusionar=True conserva lo que ya habia en el manifest y solo sustituye lo nuevo (arte parcial).
	quitar: ids de sprites que desaparecen del juego (sus hojas se borran)."""
	base = proyecto / "assets"
	base.mkdir(parents=True, exist_ok=True)
	manifest: dict = {"version": 1, "juego": biblia["juego"]["titulo"], "familia": biblia["estilo"]["familia"],
						"sprites": {}, "tiles": {}, "sfx": {}, "ui": interfaz.derivar(biblia)}
	ruta_previa = base / "manifest.json"
	if fusionar and ruta_previa.exists():
		previo = json.loads(ruta_previa.read_text(encoding="utf-8"))
		for clave in ("sprites", "tiles", "sfx", "musica", "voces"):
			if clave in previo:
				manifest[clave] = previo[clave]
		for k in ("fondo", "fondo_nivel", "skin", "iconos", "efectos", "eventos", "casa"):
			if previo.get("ui", {}).get(k):
				manifest["ui"][k] = previo["ui"][k]
	for sid in quitar or []:
		manifest["sprites"].pop(sid, None)
		shutil.rmtree(base / sid, ignore_errors=True)
	sprites = {s["id"]: s for s in biblia["personajes"] + biblia.get("objetos", [])}
	for sid, anims in hojas.items():
		s = sprites[sid]
		entrada = {"rol": s.get("rol", "objeto"), "celda": list(s["tamano"]), "animaciones": {}}
		for anim, img in anims.items():
			assert isinstance(img, Image.Image)
			ruta = base / sid / f"{anim}.png"
			ruta.parent.mkdir(parents=True, exist_ok=True)
			img.save(ruta)
			cfg = s["animaciones"][anim]
			entrada["animaciones"][anim] = {
				"sheet": f"res://assets/{sid}/{anim}.png", "frames": int(cfg["frames"]),
				"fps": float(cfg["fps"]), "bucle": bool(cfg["bucle"]),
			}
		manifest["sprites"][sid] = entrada
	for tid, img in tiles.items():
		ruta = base / "tiles" / f"{tid}.png"
		ruta.parent.mkdir(parents=True, exist_ok=True)
		img.save(ruta)
		manifest["tiles"][tid] = f"res://assets/tiles/{tid}.png"
	for nombre, origen in sfx.items():
		destino = base / "sfx" / f"{nombre}.wav"
		destino.parent.mkdir(parents=True, exist_ok=True)
		destino.write_bytes(Path(origen).read_bytes())
		manifest["sfx"][nombre] = f"res://assets/sfx/{nombre}.wav"
	for nombre, origen in (pistas or {}).items():
		## .wav (procedural) u .ogg (IA); se borra la version anterior en el otro formato.
		ext = Path(origen).suffix.lower() or ".wav"
		destino = base / "musica" / f"{nombre}{ext}"
		destino.parent.mkdir(parents=True, exist_ok=True)
		for viejo in (base / "musica").glob(f"{nombre}.*"):
			if viejo.suffix.lower() in (".wav", ".ogg") and viejo.suffix.lower() != ext:
				viejo.unlink()
				Path(str(viejo) + ".import").unlink(missing_ok=True)
		destino.write_bytes(Path(origen).read_bytes())
		manifest.setdefault("musica", {})[nombre] = f"res://assets/musica/{nombre}{ext}"
	for evento, origen in (voces or {}).items():
		## OGG mono: el WAV pesaba 10 veces mas (6,3 MB de voces en un juego del 12 nov, mas que todo el arte).
		destino = _voz_ogg(Path(origen), base / "voces", evento)
		manifest.setdefault("voces", {})[evento] = f"res://assets/voces/{destino.name}"
	if isinstance((fondos or {}).get("vertical"), (str, Path)):
		## JPG: el fondo pesa 5 veces menos que en PNG y no necesita transparencia.
		destino = base / "ui" / "fondo_titulo.jpg"
		destino.parent.mkdir(parents=True, exist_ok=True)
		Image.open(fondos["vertical"]).convert("RGB").save(destino, quality=88, optimize=True)
		manifest["ui"]["fondo"] = "res://assets/ui/fondo_titulo.jpg"
	if (fondos or {}).get("nivel"):
		## Detras de los niveles: un poco desenfocado (lejos) para que el juego destaque encima.
		from PIL import ImageFilter
		destino = base / "ui" / "fondo_nivel.jpg"
		destino.parent.mkdir(parents=True, exist_ok=True)
		Image.open(fondos["nivel"]).convert("RGB").filter(ImageFilter.GaussianBlur(2.2)).save(destino, quality=86, optimize=True)
		manifest["ui"]["fondo_nivel"] = "res://assets/ui/fondo_nivel.jpg"
	piel = (fondos or {}).get("piel") or {}
	if piel.get("panel"):
		## Interfaz dibujada por la IA: el kit la usa en paneles y botones (con respaldo a la de siempre).
		(base / "ui").mkdir(parents=True, exist_ok=True)
		skin = {"margen_panel": int(piel["margen_panel"]), "margen_boton": int(piel["margen_boton"])}
		for k in ("panel", "boton", "boton_primario"):
			shutil.copyfile(piel[k], base / "ui" / f"{k}.png")
			skin[k] = f"res://assets/ui/{k}.png"
		manifest["ui"]["skin"] = skin
	## Personajes animados con video (arte/animar.py): sus hojas de 256 px sustituyen a las de antes.
	for sid, a in sorted(((fondos or {}).get("animados") or {}).items()):
		previo_s = manifest["sprites"].get(sid) or {}
		entrada = {"rol": previo_s.get("rol", "npc"), "celda": [animar_celda(), animar_celda()], "animaciones": {}, "animado": True}
		(base / sid).mkdir(parents=True, exist_ok=True)
		for anim, cfg in a["animaciones"].items():
			shutil.copyfile(Path(a["carpeta"]) / f"{anim}.png", base / sid / f"{anim}.png")
			entrada["animaciones"][anim] = {"sheet": f"res://assets/{sid}/{anim}.png", "frames": int(cfg["frames"]),
				"fps": float(cfg["fps"]), "bucle": bool(cfg["bucle"])}
		manifest["sprites"][sid] = entrada
	ico = (fondos or {}).get("iconos") or {}
	if ico:
		## Iconos de interfaz dibujados por la IA (el kit usa los vectoriales para los que falten).
		(base / "ui" / "iconos").mkdir(parents=True, exist_ok=True)
		manifest["ui"]["iconos"] = {}
		for k, ruta in sorted(ico.items()):
			shutil.copyfile(ruta, base / "ui" / "iconos" / f"{k}.png")
			manifest["ui"]["iconos"][k] = f"res://assets/ui/iconos/{k}.png"
	## Arte de GPU para lo que era codigo (arte/extras.py): iconos de mas, efectos y eventos.
	ext = (fondos or {}).get("extras") or {}
	for k, ruta in sorted((ext.get("iconos") or {}).items()):
		(base / "ui" / "iconos").mkdir(parents=True, exist_ok=True)
		shutil.copyfile(ruta, base / "ui" / "iconos" / f"{k}.png")
		manifest["ui"].setdefault("iconos", {})[k] = f"res://assets/ui/iconos/{k}.png"
	## Casa propia (director/casa.py): fondo de la campana en jpg y el resto (botin, iconos de navegacion,
	## marcadores de etapa y jefe) en png recortado.
	if ext.get("casa"):
		(base / "ui" / "casa").mkdir(parents=True, exist_ok=True)
		manifest["ui"].setdefault("casa", {})
		for k, ruta in sorted(ext["casa"].items()):
			dest = base / "ui" / "casa" / (k + Path(ruta).suffix)
			if k.startswith("nav_") or k == "botin":
				dest = dest.with_suffix(".png")
				_sello(Path(ruta), dest)
			elif k.startswith("retrato_"):
				## Cartas de heroe: 512 x 768 bastan en el movil (el APK no puede pasar de 50 MB).
				dest = dest.with_suffix(".jpg")
				im = Image.open(ruta).convert("RGB")
				im.thumbnail((512, 768), Image.LANCZOS)
				im.save(dest, quality=86, optimize=True)
			elif k.startswith("sello_"):
				dest = dest.with_suffix(".png")
				_limpiar_croma(Path(ruta), dest)
			else:
				shutil.copyfile(ruta, dest)
			manifest["ui"]["casa"][k] = f"res://assets/ui/casa/{dest.name}"
	for grupo, ext_f in (("efectos", "png"), ("eventos", "jpg")):
		if ext.get(grupo):
			(base / "ui" / grupo).mkdir(parents=True, exist_ok=True)
			manifest["ui"].setdefault(grupo, {})
			for k, ruta in sorted(ext[grupo].items()):
				shutil.copyfile(ruta, base / "ui" / grupo / f"{k}.{ext_f}")
				manifest["ui"][grupo][k] = f"res://assets/ui/{grupo}/{k}.{ext_f}"
	ruta_m = base / "manifest.json"
	ruta_m.write_text(json.dumps(manifest, indent=1, ensure_ascii=False), encoding="utf-8")
	return ruta_m


def animar_celda() -> int:
	from . import animar
	return int(animar.CELDA)


def _voz_ogg(origen: Path, carpeta: Path, evento: str) -> Path:
	"""Guarda la voz en OGG Vorbis mono (o en WAV si no hay ffmpeg); borra la del otro formato."""
	import subprocess
	carpeta.mkdir(parents=True, exist_ok=True)
	ff = shutil.which("ffmpeg")
	destino = carpeta / f"{evento}.ogg"
	if ff:
		r = subprocess.run([ff, "-hide_banner", "-loglevel", "error", "-y", "-i", str(origen), "-ac", "1", "-ar", "32000",
			"-c:a", "libvorbis", "-q:a", "3", str(destino)], capture_output=True, timeout=60)
		if r.returncode != 0 or not destino.exists() or destino.stat().st_size == 0:
			destino.unlink(missing_ok=True)
			ff = None
	if not ff:
		destino = carpeta / f"{evento}.wav"
		destino.write_bytes(origen.read_bytes())
	for viejo in carpeta.glob(f"{evento}.*"):
		if viejo.suffix.lower() in (".wav", ".ogg") and viejo != destino:
			viejo.unlink()
			Path(str(viejo) + ".import").unlink(missing_ok=True)
	return destino


def _sello(src: Path, dest: Path, lado: int = 256) -> None:
	"""Cara redonda de un sello de la casa (iconos de navegacion y botin): recorte cuadrado del centro con
	mascara circular suave. Si el modelo pinto el objeto con paisaje detras (pasa con Qwen), queda como un
	medallon pintado; si salio suelto, como el objeto sobre su disco."""
	import numpy as np
	from PIL import ImageDraw
	im = Image.open(src).convert("RGBA")
	w, h = im.size
	s = int(min(w, h) * 0.94)
	im = im.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2)).resize((lado, lado), Image.LANCZOS)
	m = Image.new("L", (lado * 4, lado * 4), 0)
	ImageDraw.Draw(m).ellipse((4, 4, lado * 4 - 4, lado * 4 - 4), fill=255)
	m = m.resize((lado, lado), Image.LANCZOS)
	im.putalpha(Image.fromarray(np.minimum(np.asarray(im.getchannel("A")), np.asarray(m))))
	im.save(dest)


def _limpiar_croma(src: Path, dest: Path, lado: int = 160) -> None:
	"""Sellos de cera sobre magenta: Qwen deja motas de croma oscuro alrededor. Se quita todo lo de tono
	magenta (o ya transparente) que toque el borde, rellenando desde fuera; la pieza se queda entera."""
	import numpy as np
	from PIL import ImageDraw
	im = Image.open(src).convert("RGBA")
	a = np.asarray(im).astype(np.int32)
	hsv = np.asarray(im.convert("RGB").convert("HSV")).astype(float)
	h, s, v = hsv[..., 0] * 360 / 255, hsv[..., 1] / 255, hsv[..., 2] / 255
	fondo = ((h > 295) & (h < 352) & (s > 0.3) & (v > 0.12)) | (a[..., 3] < 24)
	m = Image.fromarray(np.pad(np.where(fondo, 255, 0).astype(np.uint8), 1, constant_values=255), "L").copy()
	ImageDraw.floodfill(m, (0, 0), 128)
	fuera = (np.asarray(m)[1:-1, 1:-1] == 128)
	## Motas sueltas: solo se queda lo unido al centro de la pieza.
	solido = Image.fromarray(np.where(fuera | (a[..., 3] < 24), 0, 255).astype(np.uint8), "L").copy()
	cy, cx = a.shape[0] // 2, a.shape[1] // 2
	if solido.getpixel((cx, cy)) == 255:
		ImageDraw.floodfill(solido, (cx, cy), 128)
		fuera = fuera | (np.asarray(solido) == 255)
	a[..., 3] = np.where(fuera, 0, a[..., 3])
	out = Image.fromarray(a.astype(np.uint8), "RGBA")
	bb = out.getbbox()
	if bb:
		out = out.crop(bb)
	out.thumbnail((lado, lado), Image.LANCZOS)
	out.save(dest)

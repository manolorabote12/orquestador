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
		for k in ("fondo", "fondo_nivel", "skin", "iconos"):
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
	ico = (fondos or {}).get("iconos") or {}
	if ico:
		## Iconos de interfaz dibujados por la IA (el kit usa los vectoriales para los que falten).
		(base / "ui" / "iconos").mkdir(parents=True, exist_ok=True)
		manifest["ui"]["iconos"] = {}
		for k, ruta in sorted(ico.items()):
			shutil.copyfile(ruta, base / "ui" / "iconos" / f"{k}.png")
			manifest["ui"]["iconos"][k] = f"res://assets/ui/iconos/{k}.png"
	ruta_m = base / "manifest.json"
	ruta_m.write_text(json.dumps(manifest, indent=1, ensure_ascii=False), encoding="utf-8")
	return ruta_m


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

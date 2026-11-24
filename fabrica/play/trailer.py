"""Trailer automatico (24 nov 2026) para los juegos a medida: un slideshow con zoom lento de las mismas
capturas de la ficha de Google Play (ya llevan el titular quemado encima), mas un cartel final, musica de
fondo si el juego tiene (assets/libre/musica/menu.ogg) y cortes secos entre escenas. Cero IA: solo ffmpeg y
Pillow, el mismo material que ya genera kit_tienda.

	generar(proyecto, titulo, capturas, destino, horizontal=False) -> Path | None

capturas: las imagenes que ya devolvio kit_tienda.generar()["capturas"] (si estan vacias, no hay trailer).
"""

import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from . import kit_tienda

SEG_ESCENA = 2.2
SEG_CIERRE = 2.6
FPS = 30


class ErrorTrailer(Exception):
	pass


def _ffmpeg() -> str:
	f = shutil.which("ffmpeg")
	if not f:
		raise ErrorTrailer("Falta ffmpeg en el PATH")
	return f


def _cartel_cierre(titulo: str, w: int, h: int, dst: Path) -> Path:
	"""Cartel final oscuro con el titulo y una llamada a la accion generica (sin nombre de tienda: el
	juego puede acabar publicandose mas tarde de lo que se genero el trailer)."""
	im = Image.new("RGB", (w, h), (10, 8, 14))
	d = ImageDraw.Draw(im)
	f1 = kit_tienda._fuente("cinzel700.ttf", 92 if w < h else 110)
	while d.textlength(titulo, font=f1) > w * 0.86 and f1.size > 40:
		f1 = kit_tienda._fuente("cinzel700.ttf", f1.size - 6)
	f2 = kit_tienda._fuente("nunito600.ttf", 46 if w < h else 52)
	cta = "Ya disponible"
	alto_bloque = f1.size + 26 + f2.size
	y0 = (h - alto_bloque) / 2
	d.text(((w - d.textlength(titulo, font=f1)) / 2, y0), titulo, font=f1, fill=kit_tienda.COLOR,
		stroke_width=5, stroke_fill=(10, 6, 4))
	d.text(((w - d.textlength(cta, font=f2)) / 2, y0 + f1.size + 26), cta, font=f2, fill=(235, 228, 215),
		stroke_width=3, stroke_fill=(10, 6, 4))
	dst.parent.mkdir(parents=True, exist_ok=True)
	im.save(dst, quality=92)
	return dst


def _escena(ffmpeg: str, img: Path, w: int, h: int, segundos: float, zoom_final: float, tmp: Path) -> Path:
	clip = tmp / (img.stem + "_clip.mp4")
	frames = int(segundos * FPS)
	r = subprocess.run([ffmpeg, "-y", "-hide_banner", "-loglevel", "error", "-loop", "1", "-i", str(img), "-t", f"{segundos:.2f}",
		"-vf", f"scale={w * 2}:{h * 2}:flags=lanczos,zoompan=z='min(zoom+{(zoom_final - 1) / frames:.6f},{zoom_final})':"
			f"x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={frames}:s={w}x{h}:fps={FPS},format=yuv420p",
		"-c:v", "libx264", "-preset", "veryfast", "-crf", "21", "-an", str(clip)], capture_output=True, text=True)
	if r.returncode != 0 or not clip.exists():
		raise ErrorTrailer(f"ffmpeg (escena {img.name}): {r.stderr[-500:]}")
	return clip


def generar(proyecto: Path, titulo: str, capturas: list[Path], destino: Path, horizontal: bool = False) -> Path | None:
	if not capturas:
		return None
	ffmpeg = _ffmpeg()
	w, h = (1920, 1080) if horizontal else (1080, 1920)
	destino.mkdir(parents=True, exist_ok=True)
	with tempfile.TemporaryDirectory(prefix="orq_trailer_") as td:
		tmp = Path(td)
		clips = [_escena(ffmpeg, f, w, h, SEG_ESCENA, 1.08, tmp) for f in capturas[:6]]
		cierre_img = _cartel_cierre(titulo, w, h, tmp / "cierre.jpg")
		clips.append(_escena(ffmpeg, cierre_img, w, h, SEG_CIERRE, 1.015, tmp))
		lista = tmp / "lista.txt"
		lista.write_text("".join(f"file '{c.as_posix()}'\n" for c in clips), encoding="utf-8")
		mudo = tmp / "mudo.mp4"
		r = subprocess.run([ffmpeg, "-y", "-hide_banner", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(lista),
			"-c", "copy", str(mudo)], capture_output=True, text=True)
		if r.returncode != 0 or not mudo.exists():
			raise ErrorTrailer(f"ffmpeg (concat): {r.stderr[-500:]}")
		musica = proyecto / "assets" / "libre" / "musica" / "menu.ogg"
		final = destino / "trailer.mp4"
		duracion = SEG_ESCENA * (len(clips) - 1) + SEG_CIERRE
		if musica.exists():
			r = subprocess.run([ffmpeg, "-y", "-hide_banner", "-loglevel", "error", "-i", str(mudo), "-stream_loop", "-1", "-i", str(musica),
				"-filter_complex", f"[1:a]atrim=0:{duracion:.2f},afade=t=out:st={max(0, duracion - 1.2):.2f}:d=1.2,volume=0.75[a]",
				"-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "128k", "-shortest", str(final)],
				capture_output=True, text=True)
		else:
			r = subprocess.run([ffmpeg, "-y", "-hide_banner", "-loglevel", "error", "-i", str(mudo), "-c", "copy", str(final)],
				capture_output=True, text=True)
		if r.returncode != 0 or not final.exists():
			raise ErrorTrailer(f"ffmpeg (musica/salida): {r.stderr[-500:]}")
		return final

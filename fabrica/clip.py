"""Clip vertical de 15 s para TikTok, YouTube Shorts e Instagram Reels, jugado por el bot.

	python -m clip <proyecto> [--segundos 15]

1 - Graba el juego con el Movie Maker de Godot (qa/clip.tscn): el bot juega, arriba sale un
    gancho los 3 primeros segundos y al final un cartel con el heroe, el titulo y la llamada.
2 - ffmpeg corta el principio sin accion (generos.py -> clip_saltar) y lo pasa a MP4
    1080x1920, H.264 + AAC, 30 fps: el formato que aceptan las tres redes.
Resultado: <proyecto>/fabrica/clip/clip_vertical.mp4 y una portada (portada.jpg).
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
sys.path.insert(0, str(RAIZ))

import cadena  # noqa: E402
import generos  # noqa: E402


class ErrorClip(Exception):
	pass


def generar(proyecto: Path, segundos: float = 15.0) -> Path:
	proyecto = Path(proyecto)
	if not shutil.which("ffmpeg"):
		raise ErrorClip("Falta ffmpeg en el PATH (https://ffmpeg.org)")
	diseno = json.loads((proyecto / "fabrica" / "diseno.json").read_text(encoding="utf-8"))
	saltar = float(generos.de(diseno).get("clip_saltar", 0.5))
	carpeta = proyecto / "fabrica" / "clip"
	carpeta.mkdir(parents=True, exist_ok=True)
	avi = carpeta / "bruto.avi"
	mp4 = carpeta / "clip_vertical.mp4"
	for f in (avi, mp4):
		if f.exists():
			f.unlink()
	## Si no graba nada, otra vez con pantalla virtual propia (en el servidor DISPLAY puede no valer).
	for xvfb in (False, True):
		r = cadena.godot(proyecto, "--resolution", "720x1280", "--rendering-driver", "opengl3", "--write-movie", str(avi),
			"--fixed-fps", "30", "--quit-after", str(int((saltar + segundos + 8.0) * 30)), "res://qa/clip.tscn", "--", f"--skip={saltar}", f"--seconds={segundos}",
			timeout=300, display=True, xvfb=xvfb)
		if avi.exists() and avi.stat().st_size >= 10000:
			break
	if not avi.exists() or avi.stat().st_size < 10000 or "SCRIPT ERROR" in r.stdout + r.stderr:
		raise ErrorClip("Godot no grabo el clip: " + (r.stdout + r.stderr)[-800:])
	cmd = ["ffmpeg", "-y", "-loglevel", "error", "-ss", f"{saltar:.2f}", "-i", str(avi), "-t", f"{segundos:.2f}",
		"-vf", "scale=1080:1920:flags=lanczos,format=yuv420p", "-r", "30",
		"-c:v", "libx264", "-preset", "veryfast", "-crf", "21", "-profile:v", "high",
		"-c:a", "aac", "-b:a", "128k", "-ar", "44100", "-movflags", "+faststart", str(mp4)]
	p = subprocess.run(cmd, capture_output=True, text=True)
	if p.returncode != 0 or not mp4.exists():
		raise ErrorClip("ffmpeg fallo: " + p.stderr[-800:])
	subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", "1.5", "-i", str(mp4), "-frames:v", "1", "-q:v", "3",
		str(carpeta / "portada.jpg")], capture_output=True)
	avi.unlink()
	return mp4


def main() -> int:
	p = argparse.ArgumentParser(description="Clip vertical para redes jugado por el bot")
	p.add_argument("proyecto")
	p.add_argument("--segundos", type=float, default=15.0)
	a = p.parse_args()
	try:
		mp4 = generar(Path(a.proyecto), a.segundos)
	except (ErrorClip, cadena.ErrorCadena) as e:
		print("ERROR:", e)
		return 1
	print(json.dumps({"clip": str(mp4), "mb": round(mp4.stat().st_size / 1e6, 1)}))
	return 0


if __name__ == "__main__":
	sys.exit(main())

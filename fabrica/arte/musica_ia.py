"""Musica con IA: ACE-Step 1.5 XL (ComfyUI en la GPU de RunPod) para menu, nivel y victoria.

La Biblia ya dice el ambiente, el tempo, la tonalidad y los instrumentos; aqui se convierten en
etiquetas para ACE-Step y cada pista vuelve como OGG listo para Godot:
	1 - bucle sin salto (fundido de igual potencia entre el final y el principio);
	2 - volumen igualado entre pistas;
	3 - control de calidad: ni silencio, ni pista cortada, ni saturacion. Si falla, otra semilla;
	    si vuelve a fallar, la cadena usa la musica procedural (el juego nunca se queda mudo).
"""

import json
import shutil
import subprocess
from pathlib import Path

import numpy as np

SR = 44100
NOTAS = ["C", "C#", "Db", "D", "D#", "Eb", "E", "F", "F#", "Gb", "G", "G#", "Ab", "A", "A#", "Bb", "B"]
ES = {"do": "C", "re": "D", "mi": "E", "fa": "F", "sol": "G", "la": "A", "si": "B"}
PAPEL = {
	"menu": "calm inviting title screen theme, memorable melody, seamless loop",
	"nivel": "energetic gameplay background music, steady driving groove, seamless loop",
	"victoria": "short triumphant victory fanfare, bright ending",
	"jefe": "intense boss battle music, urgent drums, seamless loop",
}
GENERO = {
	"plataformas": "platformer adventure", "runner": "fast endless runner", "volador": "arcade flying",
	"horda": "action survival", "puzle": "relaxing puzzle", "torres": "strategic tower defense", "carreras": "racing",
	"naves": "space shooter arcade", "rompebloques": "bouncy arcade brick breaker", "bloques": "calm block puzzle",
	"corredor": "energetic endless runner", "serpiente": "retro arcade snake", "memoria": "gentle playful memory game", "cajas": "calm thoughtful puzzle", "preguntas": "upbeat game show quiz", "apilar": "bouncy arcade rhythm", "topos": "silly cartoon bouncy", "saltos": "upbeat bouncy climbing", "arena": "intense punchy battle arena", "aldea": "epic medieval war drums strategy",
}
FAMILIA = {"pixel_art": "chiptune 8-bit and 16-bit", "cartoon": "playful orchestral cartoon", "low_poly": "modern synth",
	"realista": "cinematic orchestral"}


class MusicaError(Exception):
	pass


def tonalidad(texto: str) -> str:
	"""'D minor', 're menor', 'Bb major' -> el formato de ACE-Step ('D minor'). Por defecto, segun el modo."""
	t = (texto or "").strip().replace("♭", "b").replace("♯", "#")
	partes = t.replace("-", " ").split()
	if not partes:
		return "C major"
	raiz = partes[0]
	raiz = ES.get(raiz.lower(), raiz[:1].upper() + raiz[1:].lower() if len(raiz) > 1 else raiz.upper())
	menor = any(p.lower() in ("minor", "menor", "min", "m") for p in partes[1:]) or (len(partes) == 1 and t.endswith("m") and len(t) <= 3)
	if raiz.endswith("m") and raiz[:-1] in NOTAS:
		raiz, menor = raiz[:-1], True
	if raiz not in NOTAS:
		return "A minor" if menor else "C major"
	return f"{raiz} {'minor' if menor else 'major'}"


def encargos(biblia: dict, semilla: int) -> list[dict]:
	mus = biblia.get("musica", {})
	tempo = int(mus.get("tempo", 118))
	clave = tonalidad(str(mus.get("tonalidad", "")))
	base = [x for x in [
		GENERO.get(str(biblia.get("juego", {}).get("genero", "")), ""),
		FAMILIA.get(str(biblia.get("estilo", {}).get("familia", "")), ""),
		str(mus.get("ambiente", "")).strip(),
		", ".join(str(i) for i in mus.get("instrumentos", [])[:6]),
	] if x]
	pistas = mus.get("pistas") or [{"id": "menu", "segundos": 60, "bucle": True}, {"id": "nivel", "segundos": 90, "bucle": True},
		{"id": "victoria", "segundos": 15, "bucle": False}]
	out = []
	for i, p in enumerate(pistas):
		pid = str(p["id"])
		bpm = max(60, tempo - 16) if pid == "menu" else tempo
		papel = PAPEL.get(pid, "video game background music, seamless loop")
		segundos = int(p.get("segundos", 60))
		if pid == "victoria":
			segundos = min(segundos, 12)
		etiquetas = ", ".join(base + ["video game soundtrack", papel, "instrumental", "no vocals", "high quality mix", f"{bpm} BPM"])
		out.append({"id": pid, "etiquetas": etiquetas[:600], "segundos": max(6, min(segundos, 180)),
			"bucle": bool(p.get("bucle", pid != "victoria")), "bpm": bpm, "tonalidad": clave, "semilla": semilla + 101 * i})
	return out


def valores(enc: dict, intento: int) -> dict:
	semilla = enc["semilla"] + intento * 7919
	return {
		"MUSICA": {"tags": enc["etiquetas"], "lyrics": "[Instrumental]", "bpm": enc["bpm"], "duration": float(enc["segundos"]),
			"keyscale": enc["tonalidad"], "seed": semilla, "language": "en"},
		"DURACION": float(enc["segundos"]),
		"SEED": semilla,
	}


def _ffmpeg() -> str:
	f = shutil.which("ffmpeg")
	if not f:
		raise MusicaError("Falta ffmpeg para preparar la musica")
	return f


def decodificar(datos: bytes) -> np.ndarray:
	"""Cualquier formato (flac, mp3, wav) -> float32 estereo a 44,1 kHz, forma (n, 2)."""
	r = subprocess.run([_ffmpeg(), "-hide_banner", "-loglevel", "error", "-i", "pipe:0", "-f", "f32le", "-ac", "2", "-ar", str(SR), "pipe:1"],
		input=datos, capture_output=True, timeout=120)
	if r.returncode != 0 or not r.stdout:
		raise MusicaError(f"No se pudo leer el audio: {r.stderr.decode('utf-8', 'replace')[:200]}")
	return np.frombuffer(r.stdout, dtype=np.float32).reshape(-1, 2).copy()


def bucle(a: np.ndarray, fundido_s: float = 1.5) -> np.ndarray:
	"""El final se funde con el principio (igual potencia): al repetir no se nota el corte."""
	x = int(fundido_s * SR)
	if len(a) < 4 * x:
		return a
	t = np.linspace(0.0, np.pi / 2, x, dtype=np.float32)[:, None]
	out = a[:-x].copy()
	out[:x] = out[:x] * np.sin(t) + a[-x:] * np.cos(t)
	return out


def cierre(a: np.ndarray, s: float = 0.35) -> np.ndarray:
	x = min(len(a), int(s * SR))
	out = a.copy()
	out[-x:] *= np.linspace(1.0, 0.0, x, dtype=np.float32)[:, None]
	return out


def igualar(a: np.ndarray, rms_obj: float = 0.12, pico: float = 0.89) -> np.ndarray:
	rms = float(np.sqrt(np.mean(a ** 2))) or 1e-9
	g = min(rms_obj / rms, pico / (float(np.max(np.abs(a))) or 1e-9))
	return (a * g).astype(np.float32)


def revisar(a: np.ndarray, segundos: float) -> list[str]:
	problemas = []
	dur = len(a) / SR
	if dur < 0.8 * segundos:
		problemas.append(f"pista cortada ({dur:.1f} s de {segundos})")
	rms = float(np.sqrt(np.mean(a ** 2))) if len(a) else 0.0
	if rms < 0.005:
		problemas.append("casi en silencio")
	if len(a) and float(np.mean(np.abs(a) > 0.999)) > 0.01:
		problemas.append("saturada")
	## Mas de un 25 % de huecos de silencio: la IA se ha quedado a medias.
	if len(a) > SR:
		bloques = np.sqrt(np.mean(a[: len(a) // SR * SR].reshape(-1, SR, 2) ** 2, axis=(1, 2)))
		if float(np.mean(bloques < 0.003)) > 0.25:
			problemas.append("muchos silencios")
	return problemas


def guardar_ogg(a: np.ndarray, ruta: Path) -> Path:
	ruta.parent.mkdir(parents=True, exist_ok=True)
	r = subprocess.run([_ffmpeg(), "-hide_banner", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "pipe:0",
		"-c:a", "libvorbis", "-q:a", "6", str(ruta)], input=a.astype(np.float32).tobytes(), capture_output=True, timeout=120)
	if r.returncode != 0:
		raise MusicaError(f"No se pudo guardar {ruta.name}: {r.stderr.decode('utf-8', 'replace')[:200]}")
	return ruta


def generar(biblia: dict, carpeta: Path, cliente, flujo: dict, semilla: int, intentos: int = 2) -> tuple[dict[str, Path], dict]:
	"""Devuelve ({id: ruta.ogg}, informe). Lanza MusicaError si alguna pista no sale bien."""
	carpeta.mkdir(parents=True, exist_ok=True)
	pistas: dict[str, Path] = {}
	informe: dict = {"motor": "ace-step-1.5-xl", "pistas": {}, "generaciones": 0}
	encs = encargos(biblia, semilla)
	(carpeta / "encargos_musica.json").write_text(json.dumps(encs, indent=1, ensure_ascii=False), encoding="utf-8")
	for enc in encs:
		ultimo: list[str] = []
		for intento in range(intentos):
			datos = cliente.generar(flujo, valores(enc, intento))[0]
			informe["generaciones"] += 1
			a = decodificar(datos)
			ultimo = revisar(a, enc["segundos"])
			if not ultimo:
				a = igualar(a)
				a = bucle(a) if enc["bucle"] else cierre(a)
				pistas[enc["id"]] = guardar_ogg(a, carpeta / f"{enc['id']}.ogg")
				informe["pistas"][enc["id"]] = {"segundos": round(len(a) / SR, 1), "intentos": intento + 1, "bucle": enc["bucle"]}
				break
		else:
			raise MusicaError(f"La pista {enc['id']} no salio bien: {', '.join(ultimo)}")
	return pistas, informe

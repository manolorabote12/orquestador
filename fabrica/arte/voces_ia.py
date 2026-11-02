"""Voz del heroe dentro del juego (Chatterbox Multilingual en la GPU de RunPod).

La Biblia trae la voz "heroe" con tres frases en este orden: inicio, victoria, derrota (las
escribe la directora con la personalidad del personaje). Cada frase se genera con emocion,
se recorta, se le da un tono segun el personaje (pequeno -> mas agudo, gigante -> mas grave,
robot -> un toque metalico) y se guarda en WAV para Godot. Si no hay endpoint de voces, el juego
va sin voz (no pasa nada: los textos siguen en pantalla).
"""

import base64
import shutil
import subprocess
from pathlib import Path

import numpy as np

from . import musica_ia

EVENTOS = ["inicio", "victoria", "derrota"]
AGUDO = ("small", "tiny", "little", "baby", "kid", "child", "fairy", "sprite", "cat", "kitten", "mouse", "bird", "chick", "cute", "bunny")
GRAVE = ("huge", "giant", "big", "ogre", "monster", "bear", "troll", "dragon", "old", "golem", "titan")
METAL = ("robot", "android", "mech", "cyborg", "machine", "metal")


class VozError(Exception):
	pass


def tono(descripcion: str) -> tuple[float, bool]:
	d = (descripcion or "").lower()
	factor = 1.0
	if any(w in d for w in AGUDO):
		factor = 1.12
	if any(w in d for w in GRAVE):
		factor = 0.88
	return factor, any(w in d for w in METAL)


def procesar(wav: bytes, factor: float, metal: bool, destino: Path) -> Path:
	"""Tono del personaje (sin cambiar la duracion), toque metalico opcional, recorte y volumen."""
	ff = shutil.which("ffmpeg")
	if not ff:
		raise VozError("Falta ffmpeg")
	filtros = [f"asetrate=24000*{factor:.3f}", "aresample=44100", f"atempo={1 / factor:.3f}"]
	if metal:
		filtros.append("aecho=0.8:0.7:12:0.35")
	filtros += ["silenceremove=start_periods=1:start_threshold=-45dB", "areverse",
		"silenceremove=start_periods=1:start_threshold=-45dB", "areverse", "loudnorm=I=-16:TP=-1.5"]
	destino.parent.mkdir(parents=True, exist_ok=True)
	r = subprocess.run([ff, "-hide_banner", "-loglevel", "error", "-y", "-i", "pipe:0", "-af", ",".join(filtros),
		"-ac", "1", "-ar", "44100", str(destino)], input=wav, capture_output=True, timeout=60)
	if r.returncode != 0:
		raise VozError(r.stderr.decode("utf-8", "replace")[:200])
	return destino


def revisar(ruta: Path) -> list[str]:
	a = musica_ia.decodificar(ruta.read_bytes())
	dur = len(a) / musica_ia.SR
	problemas = []
	if dur < 0.3:
		problemas.append("demasiado corta")
	if dur > 6.0:
		problemas.append("demasiado larga")
	if len(a) and float(np.sqrt(np.mean(a ** 2))) < 0.01:
		problemas.append("en silencio")
	return problemas


def generar(biblia: dict, carpeta: Path, cliente) -> tuple[dict[str, Path], dict]:
	"""cliente: RunPodCliente del endpoint de voces (metodo trabajo). Devuelve ({evento: wav}, informe)."""
	todas = biblia.get("voces", [])
	voz = next((v for v in todas if v.get("id") == "heroe"), todas[0] if todas else None)
	informe: dict = {"motor": "chatterbox-multilingual", "voces": {}, "fallidas": {}}
	if not voz or len(voz.get("frases", [])) < 3:
		return {}, informe
	factor, metal = tono(voz.get("descripcion", ""))
	salida: dict[str, Path] = {}
	for evento, frase in zip(EVENTOS, voz["frases"][:3]):
		try:
			out = cliente.trabajo({"texto": frase, "idioma": voz.get("idioma", "es"), "emocion": float(voz.get("emocion", 0.7)), "ritmo": 0.5})
			if out.get("error") or not out.get("audio"):
				raise VozError(str(out.get("error") or "sin audio"))
			ruta = procesar(base64.b64decode(out["audio"]), factor, metal, carpeta / f"{evento}.wav")
			problemas = revisar(ruta)
			if problemas:
				raise VozError(", ".join(problemas))
			salida[evento] = ruta
			informe["voces"][evento] = frase
		except Exception as e:  # noqa: BLE001 - una frase que falla no para las demas
			informe["fallidas"][evento] = str(e)[:160]
	return salida, informe


def generar_dialogos(biblia: dict, carpeta: Path, cliente, ya: set[str] | None = None) -> tuple[dict[str, Path], dict]:
	"""Voz de las frases de la historia (biblia["dialogos"]: clave, texto, quien, descripcion).
	Cada personaje con su tono; los malos un punto mas graves. ya: claves que ya existen (no se repiten)."""
	informe: dict = {"voces": {}, "fallidas": {}}
	salida: dict[str, Path] = {}
	for l in biblia.get("dialogos", []):
		clave = str(l.get("clave", ""))
		if not clave or (ya and clave in ya):
			continue
		factor, metal = tono(l.get("descripcion", ""))
		if l.get("quien") in ("rival", "jefe"):
			factor *= 0.9
		try:
			out = cliente.trabajo({"texto": l["texto"], "idioma": "es", "emocion": 0.65, "ritmo": 0.5})
			if out.get("error") or not out.get("audio"):
				raise VozError(str(out.get("error") or "sin audio"))
			ruta = procesar(base64.b64decode(out["audio"]), factor, metal, carpeta / f"{clave}.wav")
			problemas = [p for p in revisar(ruta) if p != "demasiado larga"]
			if problemas:
				raise VozError(", ".join(problemas))
			salida[clave] = ruta
			informe["voces"][clave] = l["texto"]
		except Exception as e:  # noqa: BLE001 - sin esa voz la frase se lee igual
			informe["fallidas"][clave] = str(e)[:160]
	return salida, informe

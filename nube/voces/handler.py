"""Endpoint de voces de Orquestador en RunPod serverless (GPU, por segundos).

Chatterbox Multilingual (Resemble AI, licencia MIT): 23 idiomas con espanol, control de emocion
y clonado de voz con una muestra corta. Cada audio lleva la marca de agua inaudible de Resemble
(Perth), que permite identificar que es voz sintetica.

	entrada: {"texto": "...", "idioma": "es", "emocion": 0.5, "ritmo": 0.5, "voz_ref": "<wav en base64, opcional>"}
	salida:  {"audio": "<wav base64>", "formato": "wav", "sr": 24000, "segundos": 7.3}  o  {"error": "..."}
	{"tarea": "descargar_modelos"} deja el modelo en el volumen (/runpod-volume/hf) para arrancar rapido.
"""

import base64
import io
import os
import re
import tempfile
import wave

import numpy as np

REPO = "ResembleAI/chatterbox"
ARCHIVOS = ["ve.pt", "t3_mtl23ls_v2.safetensors", "s3gen.pt", "grapheme_mtl_merged_expanded_v1.json", "conds.pt", "Cangjie5_TC.json"]
IDIOMAS = {"ar", "da", "de", "el", "en", "es", "fi", "fr", "he", "hi", "it", "ja", "ko", "ms", "nl", "no", "pl", "pt", "ru", "sv", "sw", "tr", "zh"}
MAX_TEXTO = 1200
MAX_REF = 6 * 1024 * 1024
MODELO = None


def cargar():
	"""Una vez por arranque en frio (el modelo sale del volumen de red)."""
	global MODELO
	if MODELO is None:
		import torch
		from chatterbox.mtl_tts import ChatterboxMultilingualTTS
		MODELO = ChatterboxMultilingualTTS.from_pretrained(device="cuda" if torch.cuda.is_available() else "cpu")
	return MODELO


def frases(texto: str, maximo: int = 260) -> list[str]:
	"""Trozos por frases (el modelo es mas estable con frases cortas)."""
	partes = [p.strip() for p in re.split(r"(?<=[.!?¡¿;:])\s+", texto.strip()) if p.strip()]
	out: list[str] = []
	for p in partes:
		while len(p) > maximo:
			corte = p.rfind(",", 0, maximo)
			corte = corte if corte > 40 else p.rfind(" ", 0, maximo)
			corte = corte if corte > 0 else maximo
			out.append(p[:corte + 1].strip())
			p = p[corte + 1:].strip()
		if p:
			out.append(p)
	return out


def _a_wav(audio: np.ndarray, sr: int) -> bytes:
	b = io.BytesIO()
	with wave.open(b, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(sr)
		w.writeframes((np.clip(audio, -1, 1) * 32767).astype(np.int16).tobytes())
	return b.getvalue()


def _limitar(v, defecto: float, bajo: float, alto: float) -> float:
	try:
		return max(bajo, min(alto, float(v)))
	except (TypeError, ValueError):
		return defecto


def handler(trabajo: dict) -> dict:
	entrada = (trabajo or {}).get("input") or {}
	if entrada.get("tarea") == "descargar_modelos":
		from huggingface_hub import snapshot_download
		ruta = snapshot_download(repo_id=REPO, repo_type="model", allow_patterns=ARCHIVOS, token=os.getenv("HF_TOKEN"))
		return {"descargados": ARCHIVOS, "ruta": ruta}
	texto = str(entrada.get("texto", "")).strip()
	if not texto:
		return {"error": "Falta el texto"}
	if len(texto) > MAX_TEXTO:
		return {"error": f"Texto demasiado largo (maximo {MAX_TEXTO} caracteres)"}
	idioma = str(entrada.get("idioma", "es")).lower()
	if idioma not in IDIOMAS:
		return {"error": f"Idioma no disponible: {idioma}"}
	emocion = _limitar(entrada.get("emocion"), 0.5, 0.25, 1.2)
	ritmo = _limitar(entrada.get("ritmo"), 0.5, 0.1, 0.9)
	ref_path = None
	try:
		if entrada.get("voz_ref"):
			datos = base64.b64decode(str(entrada["voz_ref"]).split(",", 1)[-1])
			if len(datos) > MAX_REF:
				return {"error": "La muestra de voz es demasiado grande"}
			f = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
			f.write(datos)
			f.close()
			ref_path = f.name
		modelo = cargar()
		sr = int(modelo.sr)
		pausa = np.zeros(int(0.12 * sr), dtype=np.float32)
		trozos = []
		for i, frase in enumerate(frases(texto)):
			wav = modelo.generate(frase, language_id=idioma, audio_prompt_path=ref_path if i == 0 else None,
				exaggeration=emocion, cfg_weight=ritmo)
			trozos += [np.asarray(wav).reshape(-1).astype(np.float32), pausa]
		audio = np.concatenate(trozos[:-1]) if trozos else np.zeros(1, np.float32)
	except Exception as e:  # noqa: BLE001 - el error vuelve a la fabrica, que usa otra voz
		return {"error": f"No se pudo generar la voz: {str(e)[:400]}"}
	finally:
		if ref_path:
			os.unlink(ref_path)
	return {"audio": base64.b64encode(_a_wav(audio, sr)).decode("ascii"), "formato": "wav", "sr": sr,
		"segundos": round(len(audio) / sr, 2)}


if __name__ == "__main__":
	import runpod

	cargar()
	runpod.serverless.start({"handler": handler})

"""Voz en off de los clips. Proveedores (variable ORQ_VOZ, o automatico):

	runpod      Chatterbox Multilingual (MIT) en la GPU de RunPod, por segundos: voz natural en espanol
	            con emocion. RUNPOD_VOZ_ENDPOINT y RUNPOD_API_KEY (los pone el despliegue).
	elevenlabs  Servicio externo de pago. ELEVENLABS_API_KEY y ELEVENLABS_VOZ (id de la voz; si falta, una
	            voz multilingue por defecto). Modelo eleven_multilingual_v2. Coste por caracter.
	piper       Gratis y local (CPU, vale el PC o el trabajador): pip install piper-tts y una voz
	            .onnx en ORQ_PIPER_VOZ (p. ej. es_ES-davefx-medium.onnx con su .onnx.json al lado).
	simulado    Pitidos suaves con el ritmo de las palabras: solo para pruebas sin voz real.
	ninguna     Sin voz (el clip lleva subtitulos y musica).

Automatico: runpod si hay endpoint, si no elevenlabs si hay clave, si no piper si hay voz, si no ninguna.
Todas devuelven un WAV mono 44.1 kHz, o None si no hay voz.
"""

import json
import os
import shutil
import subprocess
import urllib.error
import urllib.request
import wave
from pathlib import Path

VOZ_ELEVEN_DEFECTO = "pNInz6obpgDQGcFmaJgB"
## Precio orientativo de ElevenLabs (planes de pago, ~0,18 $ por 1000 caracteres). Revisalo en su web.
USD_POR_CARACTER_ELEVEN = 0.00018
## Coste real de la ultima voz generada (RunPod cobra por segundo de GPU; ElevenLabs por caracter).
ULTIMO_USD = 0.0
## Emocion por estilo de video (exaggeration de Chatterbox: 0.5 neutro, mas alto = mas expresivo).
EMOCION = {"reto": 0.65, "curiosidad": 0.5, "humor": 0.8}


class ErrorVoz(Exception):
	pass


def proveedor() -> str:
	p = os.environ.get("ORQ_VOZ", "").strip().lower()
	if p:
		return p
	if os.environ.get("RUNPOD_VOZ_ENDPOINT") and os.environ.get("RUNPOD_API_KEY"):
		return "runpod"
	if os.environ.get("ELEVENLABS_API_KEY"):
		return "elevenlabs"
	if os.environ.get("ORQ_PIPER_VOZ") and Path(os.environ["ORQ_PIPER_VOZ"]).exists():
		return "piper"
	return "ninguna"


def _a_wav(origen: Path, destino: Path) -> None:
	r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(origen), "-ac", "1", "-ar", "44100", str(destino)],
		capture_output=True, text=True)
	if r.returncode != 0:
		raise ErrorVoz("ffmpeg no pudo convertir la voz: " + r.stderr[-300:])


def runpod(texto: str, destino: Path, emocion: float = 0.5, idioma: str = "es") -> Path:
	global ULTIMO_USD
	import base64

	from arte.comfy import ComfyError
	from arte.runpod import RunPodCliente
	endpoint = os.environ.get("RUNPOD_VOZ_ENDPOINT", "")
	if not endpoint:
		raise ErrorVoz("Falta RUNPOD_VOZ_ENDPOINT")
	try:
		cli = RunPodCliente(endpoint, timeout=600, usd_seg=float(os.environ.get("ORQ_VOZ_USD_SEG", "0.00019")))
		out = cli.trabajo({"texto": texto, "idioma": idioma, "emocion": emocion, "ritmo": 0.5})
	except ComfyError as e:
		raise ErrorVoz(str(e)) from e
	if out.get("error") or not out.get("audio"):
		raise ErrorVoz(f"Voz en RunPod: {out.get('error') or 'sin audio'}")
	ULTIMO_USD = cli.usd
	tmp = destino.with_name(destino.stem + "_rp.wav")
	tmp.write_bytes(base64.b64decode(out["audio"]))
	_a_wav(tmp, destino)
	tmp.unlink()
	return destino


def elevenlabs(texto: str, destino: Path) -> Path:
	clave = os.environ.get("ELEVENLABS_API_KEY", "")
	if not clave:
		raise ErrorVoz("Falta ELEVENLABS_API_KEY")
	voz = os.environ.get("ELEVENLABS_VOZ", VOZ_ELEVEN_DEFECTO)
	cuerpo = json.dumps({"text": texto, "model_id": "eleven_multilingual_v2",
		"voice_settings": {"stability": 0.45, "similarity_boost": 0.8, "style": 0.35}}).encode("utf-8")
	req = urllib.request.Request(f"https://api.elevenlabs.io/v1/text-to-speech/{voz}?output_format=mp3_44100_128",
		data=cuerpo, method="POST", headers={"xi-api-key": clave, "content-type": "application/json", "accept": "audio/mpeg"})
	try:
		with urllib.request.urlopen(req, timeout=60) as r:
			mp3 = r.read()
	except urllib.error.HTTPError as e:
		raise ErrorVoz(f"ElevenLabs HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:200]}") from e
	except urllib.error.URLError as e:
		raise ErrorVoz("No se pudo contactar con ElevenLabs: " + str(e)) from e
	tmp = destino.with_suffix(".mp3")
	tmp.write_bytes(mp3)
	_a_wav(tmp, destino)
	tmp.unlink()
	return destino


def piper(texto: str, destino: Path) -> Path:
	modelo = os.environ.get("ORQ_PIPER_VOZ", "")
	if not modelo or not Path(modelo).exists():
		raise ErrorVoz("Falta la voz de Piper (ORQ_PIPER_VOZ=ruta/a/voz.onnx)")
	tmp = destino.with_name(destino.stem + "_piper.wav")
	try:
		from piper import PiperVoice  # type: ignore
		voz = PiperVoice.load(modelo)
		with wave.open(str(tmp), "wb") as w:
			if hasattr(voz, "synthesize_wav"):
				voz.synthesize_wav(texto, w)
			else:
				voz.synthesize(texto, w)
	except ImportError:
		## Sin el paquete de Python, se prueba con el programa piper del PATH.
		exe = shutil.which("piper")
		if not exe:
			raise ErrorVoz("Instala Piper: pip install piper-tts") from None
		r = subprocess.run([exe, "--model", modelo, "--output_file", str(tmp)], input=texto, capture_output=True, text=True)
		if r.returncode != 0:
			raise ErrorVoz("Piper fallo: " + r.stderr[-300:]) from None
	_a_wav(tmp, destino)
	tmp.unlink()
	return destino


def simulado(texto: str, destino: Path) -> Path:
	"""Un pitido corto por palabra (0.36 s cada una): sirve para probar tiempos y mezcla."""
	n = max(1, len(texto.split()))
	dur = n * 0.36
	expr = "0.18*sin(2*PI*330*t)*lt(mod(t\\,0.36)\\,0.22)"
	r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", f"aevalsrc={expr}:s=44100:d={dur:.2f}",
		"-ac", "1", str(destino)], capture_output=True, text=True)
	if r.returncode != 0:
		raise ErrorVoz("ffmpeg no pudo crear la voz simulada: " + r.stderr[-300:])
	return destino


def generar(texto: str, destino: Path, quien: str = "", emocion: float = 0.5) -> Path | None:
	"""WAV con la voz en off, o None si no hay proveedor."""
	global ULTIMO_USD
	quien = quien or proveedor()
	destino.parent.mkdir(parents=True, exist_ok=True)
	ULTIMO_USD = 0.0
	if quien == "runpod":
		return runpod(texto, destino, emocion)
	if quien == "elevenlabs":
		ULTIMO_USD = len(texto) * USD_POR_CARACTER_ELEVEN
		return elevenlabs(texto, destino)
	if quien == "piper":
		return piper(texto, destino)
	if quien == "simulado":
		return simulado(texto, destino)
	return None


def duracion(wav: Path) -> float:
	with wave.open(str(wav), "rb") as w:
		return w.getnframes() / float(w.getframerate())

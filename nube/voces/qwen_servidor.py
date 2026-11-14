"""Qwen3-TTS VoiceDesign (Apache-2.0) en su propio entorno de Python (/opt/qwen), al lado de Chatterbox.

Lo arranca handler.py la primera vez que un trabajo pide {"motor": "qwen"} y se queda vivo mientras dure el
trabajador (el modelo se carga una vez). Habla por lineas JSON:
	entrada  {"texto": "...", "idioma": "Spanish", "voz": "descripcion de la voz en ingles"}
	salida   {"audio": "<wav base64>", "sr": 24000}  o  {"error": "..."}
La voz se describe con palabras (locutor de estadio, nina traviesa, pirata viejo...): no hace falta muestra.
"""

import base64
import io
import json
import os
import sys
import wave

import numpy as np

REPO = os.environ.get("ORQ_QWEN_TTS", "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign")


def _wav(audio, sr: int) -> bytes:
	a = np.asarray(audio, dtype=np.float32).reshape(-1)
	b = io.BytesIO()
	with wave.open(b, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(int(sr))
		w.writeframes((np.clip(a, -1, 1) * 32767).astype(np.int16).tobytes())
	return b.getvalue()


def main() -> None:
	import torch
	from qwen_tts import Qwen3TTSModel

	modelo = Qwen3TTSModel.from_pretrained(REPO, device_map="cuda:0" if torch.cuda.is_available() else "cpu",
		dtype=torch.bfloat16 if torch.cuda.is_available() else torch.float32)
	print(json.dumps({"listo": True}), flush=True)
	for linea in sys.stdin:
		try:
			p = json.loads(linea)
			wavs, sr = modelo.generate_voice_design(text=str(p["texto"])[:400], language=str(p.get("idioma") or "Spanish"),
				instruct=str(p.get("voz") or "A clear, friendly voice")[:400])
			r = {"audio": base64.b64encode(_wav(wavs[0], sr)).decode("ascii"), "sr": int(sr)}
		except Exception as e:  # noqa: BLE001 - el servidor sigue vivo para el siguiente
			r = {"error": f"Qwen3-TTS: {str(e)[:300]}"}
		print(json.dumps(r), flush=True)


if __name__ == "__main__":
	main()

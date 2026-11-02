"""Voces con IA en RunPod sin GPU: fabrica (marketing/voz.py) -> RunPod local -> nube/voces/handler.py
con un Chatterbox falso (mismo contrato: generate(texto, language_id, audio_prompt_path, exaggeration, cfg_weight)).

	python -m pruebas.prueba_voces_runpod
"""

import base64
import importlib.util
import os
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ))

from marketing import voz  # noqa: E402
from pruebas.prueba_imagenes_runpod import runpod_local  # noqa: E402

fallos: list[str] = []
LLAMADAS: list[dict] = []


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
	if not ok:
		fallos.append(nombre)


class ChatterboxFalso:
	sr = 24000

	def generate(self, texto, language_id=None, audio_prompt_path=None, exaggeration=0.5, cfg_weight=0.5):
		LLAMADAS.append({"texto": texto, "idioma": language_id, "ref": audio_prompt_path, "emocion": exaggeration, "ritmo": cfg_weight})
		n = int(0.07 * len(texto) * self.sr)
		t = np.arange(n) / self.sr
		return (0.3 * np.sin(2 * np.pi * 180 * t)).astype(np.float32)[None, :]


def main() -> int:
	spec = importlib.util.spec_from_file_location("handler_voces", RAIZ.parent / "nube" / "voces" / "handler.py")
	h = importlib.util.module_from_spec(spec)
	spec.loader.exec_module(h)
	h.MODELO = ChatterboxFalso()
	srv = runpod_local(h.handler)
	os.environ.update({"ORQ_RUNPOD_API": f"http://127.0.0.1:{srv.server_address[1]}/v2", "RUNPOD_API_KEY": "rp-local",
		"RUNPOD_VOZ_ENDPOINT": "orq-voces"})
	os.environ.pop("ORQ_VOZ", None)
	print("== Voces con IA (Chatterbox Multilingual en RunPod) ==")
	try:
		check("con endpoint de voces, la voz es la de RunPod", voz.proveedor() == "runpod", voz.proveedor())
		texto = "¿Crees que puedes pasar el nivel tres? Nadie lo ha conseguido a la primera. ¡Demuéstralo!"
		destino = Path(tempfile.mkdtemp()) / "voz.wav"
		r = voz.generar(texto, destino, emocion=voz.EMOCION["reto"])
		with wave.open(str(r)) as w:
			ok_fmt = w.getnchannels() == 1 and w.getframerate() == 44100
			dur = w.getnframes() / w.getframerate()
		check("WAV mono 44,1 kHz listo para el montaje", ok_fmt, f"{dur:.1f} s")
		check("frase a frase (mas estable) y en espanol", len(LLAMADAS) == 3 and all(x["idioma"] == "es" for x in LLAMADAS), str(len(LLAMADAS)))
		check("emocion del estilo reto", all(abs(x["emocion"] - 0.65) < 1e-6 for x in LLAMADAS))
		check("se apunta el coste de GPU", voz.ULTIMO_USD > 0, f"{voz.ULTIMO_USD:.5f} USD")
		LLAMADAS.clear()
		muestra = base64.b64encode(b"RIFF" + b"\0" * 100).decode()
		out = h.handler({"input": {"texto": "Hola. Adios.", "voz_ref": muestra}})
		check("la muestra de voz solo se usa en la primera frase y se borra", LLAMADAS[0]["ref"] and LLAMADAS[1]["ref"] is None
			and not Path(LLAMADAS[0]["ref"]).exists() and "audio" in out)
		check("texto vacio -> error", "error" in h.handler({"input": {"texto": "  "}}))
		check("idioma raro -> error", "Idioma" in h.handler({"input": {"texto": "hola", "idioma": "xx"}}).get("error", ""))
		check("texto enorme -> error", "largo" in h.handler({"input": {"texto": "a" * 5000}}).get("error", ""))
		check("emocion fuera de rango se limita", (h.handler({"input": {"texto": "Hola.", "emocion": 9}}) and LLAMADAS[-1]["emocion"] == 1.2))
		trozos = h.frases("Una frase muy larga, " * 40 + "fin.")
		check("las frases largas se cortan por comas", all(len(t) <= 261 for t in trozos) and len(trozos) > 1, str(len(trozos)))
		h.MODELO = None
		def roto():
			raise RuntimeError("CUDA out of memory")
		h.cargar = roto
		try:
			voz.generar("Hola.", destino)
			check("si la GPU falla, error claro (la fabrica usa Piper)", False)
		except voz.ErrorVoz as e:
			check("si la GPU falla, error claro (la fabrica usa Piper)", "out of memory" in str(e), str(e)[:80])
	finally:
		srv.shutdown()
		os.environ.pop("RUNPOD_VOZ_ENDPOINT", None)
	print(f"== {len(fallos)} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

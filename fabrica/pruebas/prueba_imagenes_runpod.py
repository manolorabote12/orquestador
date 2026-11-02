"""El endpoint de imagenes (nube/imagenes/handler.py) de punta a punta, sin GPU:

	fabrica (RunPodCliente) -> RunPod local (este archivo) -> handler.py -> ComfyUI

	python -m pruebas.prueba_imagenes_runpod                      (ComfyUI simulado)
	python -m pruebas.prueba_imagenes_runpod http://127.0.0.1:8189 (ComfyUI de verdad, CPU)

Con un ComfyUI de verdad usa nodos que no necesitan modelos (LoadImage -> ImageInvert -> SaveImage)
y comprueba que un modelo que falta vuelve como error claro (FAILED), no como cuelgue.
"""

import base64
import importlib.util
import io
import json
import os
import sys
import threading
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ))
HANDLER = RAIZ.parent / "nube" / "imagenes" / "handler.py"

from arte.comfy import ComfyError  # noqa: E402
from arte.runpod import RunPodCliente  # noqa: E402
from pruebas import comfy_simulado  # noqa: E402

fallos: list[str] = []
TRABAJOS: dict[str, dict] = {}


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
	if not ok:
		fallos.append(nombre)


def cargar_handler():
	spec = importlib.util.spec_from_file_location("handler_imagenes", HANDLER)
	mod = importlib.util.module_from_spec(spec)
	sys.path.insert(0, str(RAIZ / "arte"))  # el contenedor lleva comfy.py al lado del handler
	spec.loader.exec_module(mod)
	return mod


def runpod_local(handler):
	"""RunPod serverless en miniatura: /run ejecuta el handler en un hilo, /status lo cuenta."""

	class M(BaseHTTPRequestHandler):
		def log_message(self, *a):
			pass

		def _json(self, d, code=200):
			b = json.dumps(d).encode()
			self.send_response(code)
			self.send_header("Content-Type", "application/json")
			self.send_header("Content-Length", str(len(b)))
			self.end_headers()
			self.wfile.write(b)

		def do_POST(self):
			cuerpo = json.loads(self.rfile.read(int(self.headers.get("Content-Length") or 0)) or b"{}")
			if not self.path.endswith("/run"):
				return self._json({"status": "CANCELLED"})
			tid = uuid.uuid4().hex
			TRABAJOS[tid] = {"status": "IN_PROGRESS"}

			def correr():
				out = handler({"id": tid, "input": cuerpo.get("input")})
				if isinstance(out, dict) and out.get("error"):
					TRABAJOS[tid] = {"status": "FAILED", "error": out["error"]}
				else:
					TRABAJOS[tid] = {"status": "COMPLETED", "output": out, "executionTime": 1500}

			threading.Thread(target=correr, daemon=True).start()
			self._json({"id": tid, "status": "IN_QUEUE"})

		def do_GET(self):
			tid = self.path.rsplit("/", 1)[-1]
			self._json({"id": tid, **TRABAJOS.get(tid, {"status": "FAILED", "error": "no existe"})})

	srv = ThreadingHTTPServer(("127.0.0.1", 0), M)
	threading.Thread(target=srv.serve_forever, daemon=True).start()
	return srv


def png(color, lado=64) -> bytes:
	b = io.BytesIO()
	Image.new("RGB", (lado, lado), color).save(b, format="PNG")
	return b.getvalue()


def prueba_descarga() -> None:
	"""Descarga de modelos al volumen: servidor local con dos 'modelos' (uno corta la conexion)."""
	import tempfile

	class Modelos(BaseHTTPRequestHandler):
		def log_message(self, *a):
			pass

		def do_GET(self):
			datos = b"M" * 3000
			self.send_response(200)
			self.send_header("Content-Length", str(len(datos)))
			self.end_headers()
			self.wfile.write(datos if "bueno" in self.path else datos[:1000])

	srv = ThreadingHTTPServer(("127.0.0.1", 0), Modelos)
	threading.Thread(target=srv.serve_forever, daemon=True).start()
	base = f"http://127.0.0.1:{srv.server_address[1]}"
	tmp = Path(tempfile.mkdtemp())
	man = tmp / "modelos.json"
	man.write_text(json.dumps({"modelos": [
		{"carpeta": "vae", "archivo": "bueno.safetensors", "url": base + "/bueno"},
		{"carpeta": "loras", "archivo": "cortado.safetensors", "url": base + "/cortado"},
		{"carpeta": "loras", "archivo": "extra.safetensors", "url": base + "/bueno", "opcional": True}]}))
	os.environ["ORQ_MODELOS_MANIFIESTO"] = str(man)
	os.environ["ORQ_MODELOS_DIR"] = str(tmp / "models")
	h = cargar_handler()
	r = h.handler({"input": {"tarea": "descargar_modelos"}})
	check("descarga los modelos al volumen", r["descargados"] == ["bueno.safetensors"] and (tmp / "models/vae/bueno.safetensors").stat().st_size == 3000, str(r))
	check("una descarga cortada no deja modelo roto", "cortado" in r.get("error", "") and not list((tmp / "models/loras").glob("*")), str(r.get("error"))[:80])
	check("los opcionales solo si se piden", "extra.safetensors" not in r["descargados"])
	r2 = h.handler({"input": {"tarea": "descargar_modelos"}})
	check("la segunda vez no vuelve a bajar nada", r2["ya_estaban"] == ["bueno.safetensors"] and not r2["descargados"])
	srv.shutdown()
	os.environ.pop("ORQ_MODELOS_MANIFIESTO")
	os.environ.pop("ORQ_MODELOS_DIR")


def main() -> int:
	real = sys.argv[1] if len(sys.argv) > 1 else ""
	srv_comfy = None
	if not real:
		srv_comfy = comfy_simulado.arrancar(8197)
	os.environ["ORQ_COMFY_URL"] = real or "http://127.0.0.1:8197"
	os.environ["ORQ_COMFY_EXTERNO"] = "1"
	h = cargar_handler()
	h.arrancar_comfy(30)
	srv = runpod_local(h.handler)
	os.environ["ORQ_RUNPOD_API"] = f"http://127.0.0.1:{srv.server_address[1]}/v2"
	os.environ["RUNPOD_API_KEY"] = "rp-local"
	print("== Endpoint de imagenes (" + ("ComfyUI real" if real else "ComfyUI simulado") + ") ==")
	try:
		c = RunPodCliente("runpod://orq-imagen")
		if real:
			c.subir_imagen("ficha_heroe.png", png((10, 200, 30)))
			wf = {
				"1": {"class_type": "LoadImage", "inputs": {"image": "x.png"}, "_meta": {"title": "REF1"}},
				"2": {"class_type": "ImageInvert", "inputs": {"image": ["1", 0]}},
				"3": {"class_type": "SaveImage", "inputs": {"images": ["2", 0], "filename_prefix": "orq"}, "_meta": {"title": "SALIDA"}},
			}
			imgs = c.generar(wf, {"REF1": "ficha_heroe.png"})
			px = Image.open(io.BytesIO(imgs[0])).convert("RGB").getpixel((5, 5))
			check("la referencia llega y ComfyUI la procesa (invertida)", max(abs(x - y) for x, y in zip(px, (245, 55, 225))) <= 1, str(px))
			check("cobra el tiempo de GPU", c.usd > 0, f"{c.usd:.5f} USD")
			## Audio de verdad por el mismo camino que ACE-Step: LoadAudio -> SaveAudio (flac).
			from pruebas import comfy_simulado as cs
			c.subir_imagen("tono_prueba.wav", cs.sonar({"d": {"class_type": "x", "inputs": {"seconds": 3.0}, "_meta": {"title": "DURACION"}}}))
			wfa = {"1": {"class_type": "LoadAudio", "inputs": {"audio": "tono_prueba.wav"}},
				"2": {"class_type": "SaveAudio", "inputs": {"audio": ["1", 0], "filename_prefix": "orq/prueba"}, "_meta": {"title": "SALIDA"}}}
			try:
				aud = c.generar(wfa, {})
				from arte import musica_ia
				a = musica_ia.decodificar(aud[0])
				check("el audio sale de ComfyUI y llega entero (flac)", aud[0][:4] == b"fLaC" and abs(len(a) / 44100 - 3.0) < 0.1, f"{len(a) / 44100:.2f} s")
			except ComfyError as e:
				check("el audio sale de ComfyUI y llega entero (flac)", False, str(e)[:200])
			malo = json.loads((RAIZ / "plantillas" / "runpod" / "crear_zimage.json").read_text(encoding="utf-8"))
			for n in malo.values():
				if n["class_type"] == "UNETLoader":
					n["inputs"]["unet_name"] = "no_existe.safetensors"
			try:
				c.generar(malo, {"PROMPT": "x", "SEED": 1, "ANCHO": 512, "ALTO": 512})
				check("modelo que falta -> error claro", False)
			except ComfyError as e:
				check("modelo que falta -> error claro", "no_existe" in str(e), str(e)[:90])
		else:
			crear = json.loads((RAIZ / "plantillas" / "runpod" / "crear_zimage.json").read_text(encoding="utf-8"))
			editar = json.loads((RAIZ / "plantillas" / "runpod" / "editar_klein.json").read_text(encoding="utf-8"))
			a = c.generar(crear, {"PROMPT": "a brave cat hero, full body", "SEED": 7, "ANCHO": 256, "ALTO": 256})
			check("crea desde texto (Z-Image)", Image.open(io.BytesIO(a[0])).size[0] > 0)
			c.subir_imagen("ficha_gato.png", a[0])
			b2 = c.generar(editar, {"PROMPT": "same cat, running pose", "SEED": 8, "ANCHO": 256, "ALTO": 256, "REF1": "ficha_gato.png"})
			check("edita desde la ficha (FLUX.2 klein)", len(b2) == 1)
		check("nombres peligrosos rechazados", "no valido" in h.handler({"input": {"workflow": {"1": {"class_type": "SaveImage", "inputs": {}}},
			"images": [{"name": "../../etc/passwd", "image": base64.b64encode(b"x").decode()}]}}).get("error", ""))
		check("sin SaveImage -> error", "SaveImage" in h.handler({"input": {"workflow": {"1": {"class_type": "LoadImage", "inputs": {}}}}}).get("error", ""))
	finally:
		srv.shutdown()
		if srv_comfy:
			srv_comfy.shutdown()
	print("== Modelos en el volumen de red ==")
	prueba_descarga()
	print(f"== {len(fallos)} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

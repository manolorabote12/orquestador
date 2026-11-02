"""RunPod serverless simulado (API de runpod/worker-comfyui) para probar sin GPU ni cuenta.

/v2/<endpoint>/run      -> {"id", "status": "IN_QUEUE"}
/v2/<endpoint>/status/<id> -> la primera consulta IN_PROGRESS (arranque en frio), luego COMPLETED con
                              output.images en base64, dibujadas con el ComfyUI simulado.
Comprueba como lo haria el worker real: clave, workflow en formato API y que cada imagen que
pide un LoadImage viaja en input.images.
"""

import base64
import io
import json
import threading
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from pruebas import comfy_simulado

ESTADO = {"trabajos": {}, "peticiones": 0, "consultas": 0, "errores": [], "clave": "rp-clave-prueba",
	"fallar": 0, "colgar": 0, "canceladas": 0, "refs": 0}
BLOQUEO = threading.Lock()


class Manejador(BaseHTTPRequestHandler):
	def log_message(self, *a: object) -> None:
		pass

	def _json(self, data: object, code: int = 200) -> None:
		cuerpo = json.dumps(data).encode()
		self.send_response(code)
		self.send_header("Content-Type", "application/json")
		self.send_header("Content-Length", str(len(cuerpo)))
		self.end_headers()
		self.wfile.write(cuerpo)

	def _auth(self) -> bool:
		if self.headers.get("Authorization") != f"Bearer {ESTADO['clave']}":
			self._json({"error": "unauthorized"}, 401)
			return False
		return True

	def do_POST(self) -> None:
		if not self._auth():
			return
		largo = int(self.headers.get("Content-Length") or 0)
		datos = json.loads(self.rfile.read(largo) or b"{}")
		if self.path.endswith("/run") and "/orq-voces/" in self.path and ESTADO.get("voz"):
			## Endpoint de voces simulado: el handler real de nube/voces con un Chatterbox falso.
			out = ESTADO["voz"]({"input": datos.get("input", {})})
			tid = uuid.uuid4().hex
			with BLOQUEO:
				ESTADO["voces"] = ESTADO.get("voces", 0) + 1
				ESTADO["trabajos"][tid] = {"wf": {}, "consultas": 1, "modo": "voz", "salida": out}
			return self._json({"id": tid, "status": "IN_QUEUE"})
		if self.path.endswith("/run"):
			entrada = datos.get("input", {})
			wf = entrada.get("workflow", {})
			nombres = {i["name"] for i in entrada.get("images", [])}
			ESTADO["refs"] += len(nombres)
			for n in wf.values():
				if n.get("class_type") == "LoadImage" and n["inputs"].get("image") not in nombres:
					ESTADO["errores"].append(f"falta la imagen {n['inputs'].get('image')}")
			if not any(str(n.get("class_type", "")).startswith(("SaveImage", "SaveAudio")) for n in wf.values()):
				ESTADO["errores"].append("workflow sin SaveImage ni SaveAudio")
			tid = uuid.uuid4().hex
			with BLOQUEO:
				ESTADO["peticiones"] += 1
				modo = "ok"
				if ESTADO["fallar"] > 0:
					ESTADO["fallar"] -= 1
					modo = "falla"
				elif ESTADO["colgar"] > 0:
					ESTADO["colgar"] -= 1
					modo = "cuelga"
				ESTADO["trabajos"][tid] = {"wf": wf, "consultas": 0, "modo": modo}
			return self._json({"id": tid, "status": "IN_QUEUE"})
		if "/cancel/" in self.path:
			ESTADO["canceladas"] += 1
			return self._json({"status": "CANCELLED"})
		self._json({"error": "no"}, 404)

	def do_GET(self) -> None:
		if not self._auth():
			return
		if "/status/" not in self.path:
			return self._json({"error": "no"}, 404)
		tid = self.path.rsplit("/", 1)[-1]
		t = ESTADO["trabajos"].get(tid)
		if t is None:
			return self._json({"error": "no existe"}, 404)
		with BLOQUEO:
			t["consultas"] += 1
			ESTADO["consultas"] += 1
		if t["modo"] == "voz":
			out = t["salida"]
			if out.get("error"):
				return self._json({"id": tid, "status": "FAILED", "error": out["error"]})
			return self._json({"id": tid, "status": "COMPLETED", "executionTime": 1800, "output": out})
		if t["modo"] == "falla":
			return self._json({"id": tid, "status": "FAILED", "error": "CUDA out of memory (simulado)"})
		if t["consultas"] == 1 or t["modo"] == "cuelga":
			return self._json({"id": tid, "status": "IN_PROGRESS"})
		if comfy_simulado.es_audio(t["wf"]):
			return self._json({"id": tid, "status": "COMPLETED", "executionTime": 4100, "delayTime": 600,
				"output": {"images": [{"filename": "orq_00001_.wav", "type": "base64", "data": base64.b64encode(comfy_simulado.sonar(t["wf"])).decode()}]}})
		texto, semilla, lado = comfy_simulado._prompt_de(t["wf"])
		img = comfy_simulado.dibujar(texto, semilla, lado)
		buf = io.BytesIO()
		img.save(buf, format="PNG")
		self._json({"id": tid, "status": "COMPLETED", "executionTime": 2300, "delayTime": 800,
			"output": {"images": [{"filename": "orq_00001_.png", "type": "base64", "data": base64.b64encode(buf.getvalue()).decode()}]}})


def arrancar(puerto: int = 0) -> ThreadingHTTPServer:
	srv = ThreadingHTTPServer(("127.0.0.1", puerto), Manejador)
	threading.Thread(target=srv.serve_forever, daemon=True).start()
	return srv

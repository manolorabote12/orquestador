"""desplegar.py contra una API de RunPod simulada (REST v1 + serverless v2).

	python nube/prueba_desplegar.py
"""

import json
import os
import sys
import threading
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

OBJ: dict[str, dict[str, dict]] = {"templates": {}, "endpoints": {}, "networkvolumes": {}, "containerregistryauth": {}}
LLAMADAS: list[tuple[str, str]] = []
TRABAJOS: dict[str, int] = {}
ENTRADAS: dict[str, dict] = {}
MUESTRAS: list[dict] = []


class Falso(BaseHTTPRequestHandler):
	def log_message(self, *a):
		pass

	def _json(self, d, code=200):
		b = json.dumps(d).encode()
		self.send_response(code)
		self.send_header("Content-Type", "application/json")
		self.send_header("Content-Length", str(len(b)))
		self.end_headers()
		self.wfile.write(b)

	def _cuerpo(self):
		return json.loads(self.rfile.read(int(self.headers.get("Content-Length") or 0)) or b"{}")

	def _ok(self):
		if self.headers.get("Authorization") != "Bearer rp-prueba":
			self._json({"error": "unauthorized"}, 401)
			return False
		LLAMADAS.append((self.command, self.path))
		return True

	def do_GET(self):
		if not self._ok():
			return
		partes = self.path.strip("/").split("/")
		if partes[0] == "v1":
			return self._json(list(OBJ[partes[1]].values()))
		tid = partes[-1]
		TRABAJOS[tid] += 1
		if TRABAJOS[tid] < 2:
			return self._json({"id": tid, "status": "IN_PROGRESS"})
		if (ENTRADAS.get(tid) or {}).get("tarea") == "muestras":
			MUESTRAS.append(ENTRADAS[tid])
			## Primera tanda: hace una y falta otra; segunda: hace la que faltaba.
			out = {"hechas": ["arquero"], "fallos": {}, "faltan": ["flechas"]} if len(MUESTRAS) == 1 else {"hechas": ["flechas"], "fallos": {}, "faltan": []}
			return self._json({"id": tid, "status": "COMPLETED", "output": out})
		self._json({"id": tid, "status": "COMPLETED", "output": {"descargados": ["z_image_turbo_bf16.safetensors"], "ya_estaban": [], "errores": []}})

	def do_POST(self):
		if not self._ok():
			return
		partes = self.path.strip("/").split("/")
		d = self._cuerpo()
		if partes[0] == "v1":
			if partes[1] == "endpoints" and d.get("computeType") == "GPU" and any(g not in ("NVIDIA GeForce RTX 4090", "NVIDIA L4", "NVIDIA RTX A5000", "NVIDIA GeForce RTX 3090", "NVIDIA RTX A4500") for g in d["gpuTypeIds"]):
				return self._json({"error": "bad gpu"}, 400)
			oid = uuid.uuid4().hex[:10]
			OBJ[partes[1]][oid] = {"id": oid, **d}
			return self._json(OBJ[partes[1]][oid])
		tid = uuid.uuid4().hex
		TRABAJOS[tid] = 0
		ENTRADAS[tid] = d.get("input") or {}
		self._json({"id": tid, "status": "IN_QUEUE"})

	def do_PATCH(self):
		if not self._ok():
			return
		_, coleccion, oid = self.path.strip("/").split("/")
		OBJ[coleccion][oid].update(self._cuerpo())
		self._json(OBJ[coleccion][oid])


fallos: list[str] = []


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
	if not ok:
		fallos.append(nombre)


def main() -> int:
	srv = ThreadingHTTPServer(("127.0.0.1", 0), Falso)
	threading.Thread(target=srv.serve_forever, daemon=True).start()
	base = f"http://127.0.0.1:{srv.server_address[1]}"
	os.environ.update({"ORQ_RUNPOD_REST": base + "/v1", "ORQ_RUNPOD_API": base + "/v2", "RUNPOD_API_KEY": "rp-prueba",
		"GHCR_USUARIO": "daniel", "GHCR_TOKEN": "ghp_x", "SUPABASE_URL": "https://x.supabase.co",
		"SUPABASE_SERVICE_ROLE_KEY": "srv", "SUPABASE_ANON_KEY": "anon", "ANTHROPIC_API_KEY": "sk-ant",
		"ORQ_LLAVES_SECRETO": "s" * 32})
	import desplegar

	print("== Despliegue en RunPod ==")
	salida = Path(os.environ.get("TMPDIR", "/tmp")) / f"gh_out_{os.getpid()}"
	r = desplegar.main(["--imagen-fabrica", "ghcr.io/d/orq-fabrica:1", "--imagen-gpu", "ghcr.io/d/orq-imagenes:1", "--imagen-voces", "ghcr.io/d/orq-voces:1", "--modelos", "--motor", "--salida", str(salida)])
	check("primer despliegue sin errores", r == 0)
	check("crea 3 plantillas, 3 endpoints, 1 volumen, 1 acceso al registro",
		[len(OBJ[k]) for k in ("templates", "endpoints", "networkvolumes", "containerregistryauth")] == [3, 3, 1, 1])
	eps = {e["name"]: e for e in OBJ["endpoints"].values()}
	tpls = {t["name"]: t for t in OBJ["templates"].values()}
	gpu, cpu = eps["orq-imagenes"], eps["orq-fabrica"]
	check("imagenes: GPU, escala a cero, con el volumen de modelos", gpu["computeType"] == "GPU" and gpu["workersMin"] == 0
		and gpu["networkVolumeId"] == next(iter(OBJ["networkvolumes"])))
	check("fabrica: CPU, escala a cero", cpu["computeType"] == "CPU" and cpu["workersMin"] == 0 and cpu["cpuFlavorIds"])
	env = tpls["orq-fabrica"]["env"]
	check("la fabrica sabe donde dibujar", env.get("RUNPOD_IMAGEN_ENDPOINT") == gpu["id"])
	check("la fabrica sabe donde poner voz", env.get("RUNPOD_VOZ_ENDPOINT") == eps["orq-voces"]["id"])
	check("voces en GPU barata y con el volumen (modelo en cache)", eps["orq-voces"]["gpuTypeIds"][0] == "NVIDIA L4"
		and eps["orq-voces"]["networkVolumeId"] == gpu["networkVolumeId"])
	check("la fabrica conoce el precio por segundo de la GPU", abs(float(env["ORQ_RUNPOD_USD_SEG"]) - 1.10 / 3600) < 1e-6)
	check("la GPU no recibe secretos de la fabrica", "SUPABASE_SERVICE_ROLE_KEY" not in tpls["orq-imagenes"]["env"])
	check("imagenes privadas con su acceso", tpls["orq-fabrica"].get("containerRegistryAuthId") == next(iter(OBJ["containerregistryauth"])))
	runs = [p for m, p in LLAMADAS if p.endswith("/run")]
	check("descarga modelos (imagen+musica y voz) y sube el motor web", len(runs) == 3 and gpu["id"] in runs[0]
		and eps["orq-voces"]["id"] in runs[1] and cpu["id"] in runs[2], str(runs))
	out = salida.read_text() if salida.exists() else ""
	check("deja los ids para el siguiente paso (Supabase)", f"fabrica={cpu['id']}" in out and f"imagenes={gpu['id']}" in out, out.strip())

	r = desplegar.main(["--imagen-fabrica", "ghcr.io/d/orq-fabrica:2", "--imagen-gpu", "ghcr.io/d/orq-imagenes:2", "--imagen-voces", "ghcr.io/d/orq-voces:2", "--salida", ""])
	check("segundo despliegue actualiza sin duplicar", r == 0 and [len(OBJ[k]) for k in ("templates", "endpoints", "networkvolumes")] == [3, 3, 1])
	tpls = {t["name"]: t for t in OBJ["templates"].values()}
	check("la nueva version de la imagen queda puesta", tpls["orq-fabrica"]["imageName"].endswith(":2"))

	r = desplegar.main(["--muestras-en", cpu["id"], "--muestras", "todas"])
	check("muestras: repite tandas hasta que no falta ninguna (la primera, rehaciendo todas)", r == 0 and len(MUESTRAS) == 2
		and MUESTRAS[0] == {"tarea": "muestras", "todas": True} and MUESTRAS[1] == {"tarea": "muestras"}, str(MUESTRAS))

	os.environ.pop("ANTHROPIC_API_KEY")
	r = desplegar.main(["--imagen-fabrica", "a", "--imagen-gpu", "b", "--salida", ""])
	check("si falta un secreto lo dice y no toca nada", r == 1)
	srv.shutdown()
	salida.unlink(missing_ok=True)
	print(f"== {len(fallos)} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

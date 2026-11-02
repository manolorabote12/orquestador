"""ComfyUI en RunPod serverless: se paga por segundo de GPU y a cero cuando no hay trabajo.

El endpoint usa la imagen oficial runpod/worker-comfyui (ver runpod/LEEME.md):
	POST https://api.runpod.ai/v2/<endpoint>/run   {"input": {"workflow": {...}, "images": [{"name", "image"}]}}
	GET  https://api.runpod.ai/v2/<endpoint>/status/<id>  -> {"status": "COMPLETED", "output": {"images": [...]}}

Mismo uso que ComfyCliente (subir_imagen + generar), asi la cadena de arte no cambia:
	--comfy runpod://<id_del_endpoint>      (la clave va en RUNPOD_API_KEY, nunca en la app)

Coste: RunPod devuelve executionTime (ms de GPU); con ORQ_RUNPOD_USD_SEG (precio por segundo de la
GPU elegida) se apunta el coste real de cada imagen en self.usd.
"""

import base64
import json
import os
import time
import urllib.error
import urllib.request

from .comfy import ComfyError, rellenar

API = "https://api.runpod.ai/v2"


def _api() -> str:
	return os.environ.get("ORQ_RUNPOD_API", API).rstrip("/")


class RunPodCliente:
	def __init__(self, endpoint: str, clave: str = "", timeout: float = 900.0, usd_seg: float | None = None):
		self.endpoint = endpoint.replace("runpod://", "").strip("/")
		self.clave = clave or os.environ.get("RUNPOD_API_KEY", "")
		if not self.clave:
			raise ComfyError("Falta RUNPOD_API_KEY para usar ComfyUI en RunPod")
		self.timeout = timeout
		self.usd_seg = usd_seg if usd_seg is not None else float(os.environ.get("ORQ_RUNPOD_USD_SEG", "0.00031"))
		self.imagenes: dict[str, bytes] = {}
		self.usd = 0.0
		self.segundos_gpu = 0.0
		self.trabajos = 0

	def _pedir(self, metodo: str, ruta: str, cuerpo: dict | None = None) -> dict:
		req = urllib.request.Request(f"{_api()}/{self.endpoint}{ruta}", method=metodo,
			data=json.dumps(cuerpo).encode("utf-8") if cuerpo is not None else None,
			headers={"Authorization": f"Bearer {self.clave}", "Content-Type": "application/json",
				## Cloudflare de RunPod corta el agente por defecto de Python (error 1010).
				"User-Agent": "Orquestador/1.0 (+https://github.com)"})
		for intento in range(4):
			try:
				with urllib.request.urlopen(req, timeout=120) as r:
					return json.loads(r.read().decode("utf-8"))
			except urllib.error.HTTPError as e:
				txt = e.read().decode("utf-8", "replace")[:300]
				if e.code in (429, 500, 502, 503) and intento < 3:
					time.sleep(2 * (intento + 1))
					continue
				raise ComfyError(f"RunPod HTTP {e.code}: {txt}") from e
			except urllib.error.URLError as e:
				if intento < 3:
					time.sleep(2 * (intento + 1))
					continue
				raise ComfyError(f"No se pudo contactar con RunPod: {e}") from e
		raise ComfyError("RunPod: reintentos agotados")

	def subir_imagen(self, nombre: str, contenido: bytes) -> str:
		"""La referencia viaja dentro de la peticion (worker-comfyui la deja en input/)."""
		self.imagenes[nombre] = contenido
		return nombre

	def generar(self, workflow: dict, valores: dict) -> list[bytes]:
		wf = rellenar(workflow, valores)
		usadas = {n["inputs"].get("image") for n in wf.values() if n.get("class_type") == "LoadImage"}
		usadas |= {n["inputs"].get("audio") for n in wf.values() if n.get("class_type") == "LoadAudio"}
		entrada: dict = {"workflow": wf}
		refs = [{"name": k, "image": base64.b64encode(v).decode("ascii")} for k, v in self.imagenes.items() if k in usadas]
		if refs:
			entrada["images"] = refs
		salida = self.trabajo(entrada)
		if isinstance(salida, dict) and salida.get("error"):
			raise ComfyError(f"Error en ComfyUI (RunPod): {salida['error']}")
		imgs = [base64.b64decode(i["data"].split(",", 1)[-1]) for i in (salida.get("images") or [])
			if i.get("type", "base64") == "base64"]
		if not imgs:
			raise ComfyError(f"RunPod termino sin imagenes: {str(salida)[:300]}")
		return imgs

	def trabajo(self, entrada: dict) -> dict:
		"""Lanza un trabajo en el endpoint, espera (arranque en frio incluido) y apunta el coste real."""
		r = self._pedir("POST", "/run", {"input": entrada})
		tid = r.get("id")
		if not tid:
			raise ComfyError(f"RunPod no acepto el trabajo: {r}")
		limite = time.time() + self.timeout
		espera = 0.5
		while time.time() < limite:
			e = self._pedir("GET", f"/status/{tid}")
			estado = e.get("status")
			if estado == "COMPLETED":
				seg = float(e.get("executionTime", 0)) / 1000.0
				self.segundos_gpu += seg
				self.usd += seg * self.usd_seg
				self.trabajos += 1
				salida = e.get("output") or {}
				return salida if isinstance(salida, dict) else {"resultado": salida}
			if estado in ("FAILED", "CANCELLED", "TIMED_OUT"):
				raise ComfyError(f"RunPod {estado}: {str(e.get('error') or e.get('output'))[:400]}")
			## En cola o arrancando la maquina (arranque en frio): se espera cada vez un poco mas.
			time.sleep(espera)
			espera = min(3.0, espera * 1.4)
		try:
			self._pedir("POST", f"/cancel/{tid}")
		except ComfyError:
			pass
		raise ComfyError("Tiempo de espera agotado esperando a RunPod")


def cliente(url: str):
	"""ComfyUI local (http://...) o en RunPod (runpod://<endpoint>)."""
	if url.startswith("runpod://"):
		return RunPodCliente(url)
	from .comfy import ComfyCliente
	return ComfyCliente(url)

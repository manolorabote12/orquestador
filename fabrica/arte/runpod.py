"""ComfyUI en RunPod serverless: se paga por segundo de GPU y a cero cuando no hay trabajo.

El endpoint usa la imagen oficial runpod/worker-comfyui (ver runpod/LEEME.md):
	POST https://api.runpod.ai/v2/<endpoint>/run   {"input": {"workflow": {...}, "images": [{"name", "image"}]}}
	GET  https://api.runpod.ai/v2/<endpoint>/status/<id>  -> {"status": "COMPLETED", "output": {"images": [...]}}

Mismo uso que ComfyCliente (subir_imagen + generar), asi la cadena de arte no cambia:
	--comfy runpod://<id_del_endpoint>      (la clave va en RUNPOD_API_KEY, nunca en la app)

Coste: RunPod devuelve executionTime (ms de GPU); con ORQ_RUNPOD_USD_SEG (precio por segundo de la
GPU elegida) se apunta el coste real de cada imagen en self.usd. RunPod tambien cobra el arranque en
frio (cargar el modelo) y los segundos de espera antes de apagarse: si el trabajo espero mas de
ARRANQUE_MIN segundos (delayTime) se cuenta como arranque y se suma, con el apagado, al coste.
"""

import base64
import json
import os
import time
import urllib.error
import urllib.request

from .comfy import ComfyError, rellenar

API = "https://api.runpod.ai/v2"

## Tope de GPU por juego (todas las maquinas juntas: imagenes, musica y voces). Al pasar el SUAVE
## la fabrica deja de repetir lo que el control de calidad rechaza; al pasar el DURO ya no pide mas
## (lo que falte sale procedural o el juego falla y se devuelven las tuercas). Nunca mas sustos.
GASTO = {"usd": 0.0, "cancelado": False, "imprescindible": False}
## Lo imprescindible (ficha del heroe, del primer enemigo y el suelo: sin ellos el juego no pasa la
## validacion) puede pasarse del tope duro hasta este multiplo; es una imagen o dos, no un susto.
MARGEN_IMPRESCINDIBLE = 1.5


def tope_suave() -> float:
	return float(os.environ.get("ORQ_TOPE_GPU_SUAVE") or "0.25")


def tope_duro() -> float:
	return float(os.environ.get("ORQ_TOPE_GPU_DURO") or "0.50")


class TopeGPU(ComfyError):
	"""Este juego ya gasto su tope duro de GPU: lo que falte se hace sin GPU (o se deja como estaba)."""


class TrabajoCancelado(ComfyError):
	"""El servidor dio el trabajo por terminado (caducado): no se gasta nada mas en el."""


## Arranque en frio: lo que espera un trabajo por encima de esto se cobra (cargar el modelo).
ARRANQUE_MIN = 5.0


def arranque_max() -> float:
	return float(os.environ.get("ORQ_RUNPOD_ARRANQUE_MAX") or "240")


def apagado_seg() -> float:
	"""Segundos que la maquina sigue encendida (y cobrando) tras el ultimo trabajo (idleTimeout)."""
	return float(os.environ.get("ORQ_RUNPOD_APAGADO") or "10")


def reiniciar_gasto() -> None:
	GASTO["usd"] = 0.0
	GASTO["cancelado"] = False
	GASTO["imprescindible"] = False


def en_ahorro() -> bool:
	"""True cuando este juego ya ha gastado el tope suave de GPU: nada de repeticiones."""
	return GASTO["usd"] >= tope_suave()


def _api() -> str:
	return os.environ.get("ORQ_RUNPOD_API", API).rstrip("/")


class RunPodCliente:
	def __init__(self, endpoint: str, clave: str = "", timeout: float = 600.0, usd_seg: float | None = None):
		self.endpoint = endpoint.replace("runpod://", "").strip("/")
		self.clave = clave or os.environ.get("RUNPOD_API_KEY", "")
		if not self.clave:
			raise ComfyError("Falta RUNPOD_API_KEY para usar ComfyUI en RunPod")
		self.timeout = timeout
		self.usd_seg = usd_seg if usd_seg is not None else float(os.environ.get("ORQ_RUNPOD_USD_SEG") or "0.000372")
		self.imagenes: dict[str, bytes] = {}
		self.usd = 0.0
		self.segundos_gpu = 0.0
		self.segundos_arranque = 0.0
		self.arranques = 0
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
		if GASTO["cancelado"]:
			raise TrabajoCancelado("El servidor dio este trabajo por terminado: no se piden mas imagenes")
		limite = tope_duro() * (MARGEN_IMPRESCINDIBLE if GASTO.get("imprescindible") else 1.0)
		if GASTO["usd"] >= limite:
			raise TopeGPU(f"Tope de gasto de GPU de este juego alcanzado ({GASTO['usd']:.2f} $)")
		inicio = time.time()
		r = self._pedir("POST", "/run", {"input": entrada})
		tid = r.get("id")
		if not tid:
			raise ComfyError(f"RunPod no acepto el trabajo: {r}")
		limite = time.time() + self.timeout
		espera = 0.5
		try:
			return self._esperar(tid, limite, espera)
		except BaseException as e:
			## Si la fabrica falla o se corta, el trabajo no se queda en RunPod gastando GPU.
			if getattr(e, "terminado", False):
				raise
			try:
				self._pedir("POST", f"/cancel/{tid}")
			except ComfyError:
				pass
			## Sin saber cuanto llego a correr, se apunta todo el tiempo esperado (mejor de mas).
			self._apuntar({}, seg=min(time.time() - inicio, self.timeout))
			raise

	def _apuntar(self, e: dict, seg: float | None = None) -> None:
		"""Suma al coste los segundos de GPU de un trabajo y, si arranco en frio, el arranque."""
		if seg is None:
			seg = float(e.get("executionTime", 0) or 0) / 1000.0
		self.segundos_gpu += seg
		## Arranque en frio: la maquina estaba apagada y cobra lo que tarda en cargar el modelo
		## (y el apagado de la tanda anterior). En cola detras de otro juego tambien cuenta: mejor
		## pasarse que quedarse corto con los topes.
		retraso = float(e.get("delayTime", 0) or 0) / 1000.0
		if retraso > ARRANQUE_MIN:
			extra = min(retraso, arranque_max()) + apagado_seg()
			self.segundos_arranque += extra
			self.arranques += 1
			seg += extra
		self.usd += seg * self.usd_seg
		GASTO["usd"] += seg * self.usd_seg

	def _esperar(self, tid: str, limite: float, espera: float) -> dict:
		while time.time() < limite:
			e = self._pedir("GET", f"/status/{tid}")
			estado = e.get("status")
			if estado == "COMPLETED":
				self._apuntar(e)
				self.trabajos += 1
				salida = e.get("output") or {}
				return salida if isinstance(salida, dict) else {"resultado": salida}
			if estado in ("FAILED", "CANCELLED", "TIMED_OUT"):
				## Un trabajo que falla tambien se cobra lo que estuvo en marcha.
				self._apuntar(e)
				err = ComfyError(f"RunPod {estado}: {str(e.get('error') or e.get('output'))[:400]}")
				err.terminado = True
				raise err
			## En cola o arrancando la maquina (arranque en frio): se espera cada vez un poco mas.
			time.sleep(espera)
			espera = min(3.0, espera * 1.4)
		raise ComfyError("Tiempo de espera agotado esperando a RunPod")


def cliente(url: str):
	"""ComfyUI local (http://...) o en RunPod (runpod://<endpoint>)."""
	if url.startswith("runpod://"):
		return RunPodCliente(url)
	from .comfy import ComfyCliente
	return ComfyCliente(url)

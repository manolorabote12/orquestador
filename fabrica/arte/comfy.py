"""Cliente minimo de la API de ComfyUI (solo libreria estandar).

Los flujos se exportan desde ComfyUI en "formato API" y se rellenan por el
TITULO de los nodos, asi funcionan con cualquier modelo (Z-Image, FLUX.2 klein...)
sin depender de nombres internos:

	PROMPT    texto positivo        NEGATIVO  texto negativo (opcional)
	SEED      semilla               ANCHO / ALTO  tamano (opcional)
	REF1      imagen de referencia  SALIDA    nodo que guarda la imagen (o el audio)
	MUSICA    nodo de texto de ACE-Step: recibe un diccionario {tags, lyrics, bpm, duration, keyscale, seed}
	DURACION  segundos del latente de audio
"""

import copy
import json
import time
import urllib.parse
import urllib.request
import uuid

CAMPOS = {
	"PROMPT": ["text", "prompt", "positive"],
	"NEGATIVO": ["text", "prompt", "negative"],
	"SEED": ["seed", "noise_seed"],
	"ANCHO": ["width"],
	"ALTO": ["height"],
	"REF1": ["image"],
	"REF2": ["image"],
	"DURACION": ["seconds", "duration"],
}


class ComfyError(Exception):
	pass


def rellenar(workflow: dict, valores: dict) -> dict:
	wf = copy.deepcopy(workflow)
	usados = set()
	for nodo in wf.values():
		titulo = nodo.get("_meta", {}).get("title", "")
		if titulo not in valores:
			continue
		entradas = nodo.setdefault("inputs", {})
		## Un diccionario rellena varias entradas del mismo nodo (solo las que ya existen).
		if isinstance(valores[titulo], dict):
			for k, v in valores[titulo].items():
				if k in entradas and not isinstance(entradas[k], list):
					entradas[k] = v
					usados.add(titulo)
			continue
		for campo in CAMPOS.get(titulo, []):
			if campo in entradas:
				entradas[campo] = valores[titulo]
				usados.add(titulo)
				break
		## Un nodo de lienzo titulado ANCHO lleva tambien el alto (EmptySD3LatentImage, EmptyLatentImage...).
		if titulo == "ANCHO" and "ALTO" in valores and "height" in entradas and not isinstance(entradas["height"], list):
			entradas["height"] = valores["ALTO"]
	faltan = [t for t in valores if t not in usados and t in ("PROMPT", "SEED", "REF1")]
	if faltan:
		raise ComfyError(f"El flujo no tiene nodos con titulo {faltan}. Revisa los titulos en ComfyUI.")
	return wf


class ComfyCliente:
	def __init__(self, url: str, timeout: float = 900.0):
		self.url = url.rstrip("/")
		self.timeout = timeout
		self.client_id = str(uuid.uuid4())

	def _get(self, ruta: str) -> bytes:
		with urllib.request.urlopen(self.url + ruta, timeout=60) as r:
			return r.read()

	def _post_json(self, ruta: str, data: dict) -> dict:
		req = urllib.request.Request(
			self.url + ruta, data=json.dumps(data).encode("utf-8"),
			headers={"Content-Type": "application/json"}, method="POST",
		)
		with urllib.request.urlopen(req, timeout=60) as r:
			return json.loads(r.read().decode("utf-8"))

	def subir_imagen(self, nombre: str, contenido: bytes) -> str:
		"""1 - Sube una imagen de referencia y devuelve el nombre que usa LoadImage."""
		frontera = "----orq" + uuid.uuid4().hex
		cuerpo = b"".join([
			f"--{frontera}\r\n".encode(),
			f'Content-Disposition: form-data; name="image"; filename="{nombre}"\r\n'.encode(),
			b"Content-Type: image/png\r\n\r\n", contenido, b"\r\n",
			f"--{frontera}\r\n".encode(),
			b'Content-Disposition: form-data; name="overwrite"\r\n\r\ntrue\r\n',
			f"--{frontera}--\r\n".encode(),
		])
		req = urllib.request.Request(
			self.url + "/upload/image", data=cuerpo, method="POST",
			headers={"Content-Type": f"multipart/form-data; boundary={frontera}"},
		)
		with urllib.request.urlopen(req, timeout=60) as r:
			info = json.loads(r.read().decode("utf-8"))
		return f"{info['subfolder']}/{info['name']}" if info.get("subfolder") else info["name"]

	def generar(self, workflow: dict, valores: dict) -> list[bytes]:
		"""2 - Encola el flujo, espera a que termine y devuelve las imagenes del nodo SALIDA."""
		wf = rellenar(workflow, valores)
		res = self._post_json("/prompt", {"prompt": wf, "client_id": self.client_id})
		if "prompt_id" not in res:
			raise ComfyError(f"ComfyUI rechazo el flujo: {res}")
		pid = res["prompt_id"]
		salida_ids = {k for k, n in wf.items() if n.get("_meta", {}).get("title") == "SALIDA"}
		limite = time.time() + self.timeout
		while time.time() < limite:
			hist = json.loads(self._get(f"/history/{pid}").decode("utf-8"))
			if pid in hist:
				entrada = hist[pid]
				estado = entrada.get("status", {})
				if estado.get("status_str") == "error":
					raise ComfyError(f"Error en ComfyUI: {estado.get('messages')}")
				imagenes = []
				for nodo_id, out in entrada.get("outputs", {}).items():
					if salida_ids and nodo_id not in salida_ids:
						continue
					## Imagenes (SaveImage) y audio (SaveAudio) salen igual: nombre, carpeta y tipo.
					for img in out.get("images", []) + out.get("audio", []):
						q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img.get("subfolder", ""), "type": img.get("type", "output")})
						imagenes.append(self._get("/view?" + q))
				if imagenes:
					return imagenes
			time.sleep(0.5)
		raise ComfyError("Tiempo de espera agotado esperando a ComfyUI")

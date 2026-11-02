"""Endpoint de imagenes de Orquestador en RunPod serverless (GPU, se paga por segundo).

Misma API que runpod/worker-comfyui, para que la fabrica no dependa de una imagen ajena:
	entrada: {"workflow": {...formato API de ComfyUI...}, "images": [{"name": "x.png", "image": "<base64>"}]}
	salida:  {"images": [{"filename": "...", "type": "base64", "data": "<base64>"}]}  o  {"error": "..."}

Los modelos viven en el volumen de red (/runpod-volume/models, ver modelos.json): se descargan
una vez con descargar_modelos.py y todos los trabajadores los comparten.
"""

import base64
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from comfy import ComfyCliente, ComfyError  # noqa: E402  (copiado de fabrica/arte/comfy.py)

URL = os.environ.get("ORQ_COMFY_URL", "http://127.0.0.1:8188")
MAX_REFS = 8
MAX_REF_BYTES = 12 * 1024 * 1024
_comfy: subprocess.Popen | None = None


def arrancar_comfy(espera_s: float = 600.0) -> None:
	"""Lanza ComfyUI dentro del contenedor (una vez por arranque en frio) y espera a que responda."""
	global _comfy
	if os.environ.get("ORQ_COMFY_EXTERNO") != "1" and _comfy is None:
		_comfy = subprocess.Popen([sys.executable, "/comfyui/main.py", "--listen", "127.0.0.1", "--port", "8188",
			"--disable-auto-launch", "--disable-metadata"])
	limite = time.time() + espera_s
	while time.time() < limite:
		try:
			with urllib.request.urlopen(URL + "/system_stats", timeout=5):
				return
		except OSError:
			if _comfy is not None and _comfy.poll() is not None:
				raise RuntimeError("ComfyUI se cerro al arrancar")
			time.sleep(0.5)
	raise RuntimeError("ComfyUI no arranco a tiempo")


def _nombre_seguro(nombre: str) -> str:
	base = os.path.basename(str(nombre))
	if base != str(nombre) or not re.fullmatch(r"[A-Za-z0-9_.-]{1,120}", base) or base.startswith("."):
		raise ValueError(f"nombre de imagen no valido: {nombre!r}")
	return base


MODELOS_DIR = os.environ.get("ORQ_MODELOS_DIR", "/runpod-volume/models")
MANIFIESTO = os.environ.get("ORQ_MODELOS_MANIFIESTO", os.path.join(os.path.dirname(os.path.abspath(__file__)), "modelos.json"))


def descargar_modelos(con_opcionales: bool = False) -> dict:
	"""Baja al volumen de red los modelos que falten (una vez; despues todos los trabajadores los usan).
	Descarga a .part y renombra al terminar: un corte nunca deja un modelo a medias."""
	lista = json.loads(open(MANIFIESTO, encoding="utf-8").read())["modelos"]
	hechos, ya, errores = [], [], []
	token = os.environ.get("HF_TOKEN", "")
	for m in lista:
		if m.get("opcional") and not con_opcionales:
			continue
		destino = os.path.join(MODELOS_DIR, m["carpeta"], m["archivo"])
		if os.path.exists(destino) and os.path.getsize(destino) > 0:
			ya.append(m["archivo"])
			continue
		os.makedirs(os.path.dirname(destino), exist_ok=True)
		parte = destino + ".part"
		try:
			req = urllib.request.Request(m["url"], headers={"Authorization": f"Bearer {token}"} if token else {})
			with urllib.request.urlopen(req, timeout=120) as r, open(parte, "wb") as f:
				esperado = int(r.headers.get("Content-Length") or 0)
				while True:
					bloque = r.read(8 * 1024 * 1024)
					if not bloque:
						break
					f.write(bloque)
			if esperado and os.path.getsize(parte) != esperado:
				raise OSError(f"descarga incompleta ({os.path.getsize(parte)} de {esperado} bytes)")
			os.replace(parte, destino)
			hechos.append(m["archivo"])
		except Exception as e:  # noqa: BLE001 - un modelo que falla no para los demas
			errores.append(f"{m['archivo']}: {e}")
			if os.path.exists(parte):
				os.remove(parte)
	return {"descargados": hechos, "ya_estaban": ya, "errores": errores}


def handler(trabajo: dict) -> dict:
	entrada = (trabajo or {}).get("input") or {}
	if entrada.get("tarea") == "descargar_modelos":
		r = descargar_modelos(bool(entrada.get("opcionales")))
		return {**r, "error": "; ".join(r["errores"])} if r["errores"] else r
	wf = entrada.get("workflow")
	if not isinstance(wf, dict) or not wf:
		return {"error": "Falta input.workflow (formato API de ComfyUI)"}
	if not any(isinstance(n, dict) and str(n.get("class_type", "")).startswith(("SaveImage", "SaveAudio")) for n in wf.values()):
		return {"error": "El workflow no tiene SaveImage ni SaveAudio"}
	refs = entrada.get("images") or []
	if len(refs) > MAX_REFS:
		return {"error": f"Demasiadas imagenes de referencia (max {MAX_REFS})"}
	cliente = ComfyCliente(URL, timeout=float(os.environ.get("ORQ_COMFY_TIMEOUT", "600")))
	try:
		cambios: dict[str, str] = {}
		for r in refs:
			nombre = _nombre_seguro(r.get("name", ""))
			datos = base64.b64decode(str(r.get("image", "")).split(",", 1)[-1])
			if len(datos) > MAX_REF_BYTES:
				return {"error": f"La imagen {nombre} es demasiado grande"}
			cambios[r["name"]] = cliente.subir_imagen(nombre, datos)
		for n in wf.values():
			if n.get("class_type") == "LoadImage" and n.get("inputs", {}).get("image") in cambios:
				n["inputs"]["image"] = cambios[n["inputs"]["image"]]
		imagenes = cliente.generar(wf, {})
	except urllib.error.HTTPError as e:
		## 400 de /prompt: ComfyUI explica que nodo o modelo falla.
		return {"error": f"ComfyUI rechazo el flujo: {e.read().decode('utf-8', 'replace')[:600]}"}
	except (ComfyError, ValueError, OSError) as e:
		return {"error": str(e)[:600]}
	## "images" por compatibilidad con worker-comfyui; tambien lleva el audio (flac) de ACE-Step.
	return {"images": [{"filename": f"orq_{i:02d}{_extension(b)}", "type": "base64", "data": base64.b64encode(b).decode("ascii")}
		for i, b in enumerate(imagenes)]}


def _extension(b: bytes) -> str:
	if b[:4] == b"fLaC":
		return ".flac"
	if b[:4] == b"RIFF":
		return ".wav"
	if b[:3] == b"ID3" or b[:2] == b"\xff\xfb":
		return ".mp3"
	if b[:4] == b"OggS":
		return ".ogg"
	return ".png"


if __name__ == "__main__":
	import runpod

	arrancar_comfy()
	runpod.serverless.start({"handler": handler})

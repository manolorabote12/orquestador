"""Despliega Orquestador en RunPod. Lo ejecuta GitHub Actions (.github/workflows/desplegar.yml);
no hace falta correr nada en el PC. Es idempotente: si ya existe, lo actualiza; nunca duplica.

Crea o actualiza (todo con nombre "orq-..."):
	1 - orq-ghcr         acceso de RunPod a las imagenes privadas de GitHub (ghcr.io)
	2 - orq-modelos      volumen de red con los modelos de imagen (se paga por GB al mes)
	3 - orq-imagenes     endpoint serverless con GPU: Z-Image, FLUX.2 klein, Qwen-Image-Edit y musica ACE-Step 1.5 XL
	4 - orq-voces        endpoint serverless con GPU: Chatterbox Multilingual (voces con emocion)
	5 - orq-fabrica      endpoint serverless con CPU: Godot, Android, ffmpeg (la fabrica)
	6 - con --modelos, descarga los modelos al volumen (una vez; tarda unos minutos)
	7 - con --motor, la fabrica exporta y sube el motor web de Godot («Jugar ya» en la app)

Variables (secretos de GitHub):
	RUNPOD_API_KEY, GHCR_USUARIO, GHCR_TOKEN
	SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY, ANTHROPIC_API_KEY, ORQ_LLAVES_SECRETO
	opcionales: ORQ_PLAY_CUENTA, ELEVENLABS_API_KEY, HF_TOKEN, ORQ_RUNPOD_DC (por defecto EU-RO-1),
	            ORQ_GPU (lista separada por comas), ORQ_GPU_USD_HORA (precio de la primera GPU)

	python nube/desplegar.py --imagen-fabrica ghcr.io/yo/orq-fabrica:abc --imagen-gpu ghcr.io/yo/orq-imagenes:abc --modelos
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

REST = (os.environ.get("ORQ_RUNPOD_REST") or "https://rest.runpod.io/v1").rstrip("/")
SERVERLESS = (os.environ.get("ORQ_RUNPOD_API") or "https://api.runpod.ai/v2").rstrip("/")

## 1 - GPUs por orden de preferencia: 24 GB sobran para Z-Image + FLUX.2 klein (y Qwen en fp8).
## La 4090 cuesta ~1,12 $/h pero dibuja unas 2 veces mas rapido que las de 24 GB normales (~0,68 $/h):
## por imagen sale mas barata. La L4 es la mas lenta: la ultima.
GPUS = ["NVIDIA GeForce RTX 4090", "NVIDIA GeForce RTX 3090", "NVIDIA RTX A5000", "NVIDIA L4"]
USD_HORA_GPU = 1.10
## Voces: Chatterbox cabe de sobra en GPUs de 16-24 GB mas baratas.
GPUS_VOZ = ["NVIDIA L4", "NVIDIA RTX A5000", "NVIDIA GeForce RTX 3090", "NVIDIA RTX A4500", "NVIDIA GeForce RTX 4090"]
USD_HORA_VOZ = 0.69
SECRETOS_FABRICA = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_ANON_KEY", "ANTHROPIC_API_KEY",
	"ORQ_LLAVES_SECRETO", "ORQ_PLAY_CUENTA", "ELEVENLABS_API_KEY", "GOOGLE_OAUTH_CLIENT_ID", "GOOGLE_OAUTH_CLIENT_SECRET", "ORQ_WEB"]
OBLIGATORIOS = ["RUNPOD_API_KEY", "SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_ANON_KEY",
	"ANTHROPIC_API_KEY", "ORQ_LLAVES_SECRETO"]


class ErrorRunPod(Exception):
	pass


def pedir(metodo: str, url: str, cuerpo: dict | None = None) -> object:
	req = urllib.request.Request(url, method=metodo, data=json.dumps(cuerpo).encode() if cuerpo is not None else None,
		headers={"Authorization": "Bearer " + os.environ["RUNPOD_API_KEY"], "Content-Type": "application/json",
			## Cloudflare de RunPod corta el agente por defecto de Python (error 1010).
			"User-Agent": "Orquestador/1.0 (+https://github.com)"})
	for intento in range(4):
		try:
			with urllib.request.urlopen(req, timeout=60) as r:
				txt = r.read().decode("utf-8")
				return json.loads(txt) if txt.strip() else {}
		except urllib.error.HTTPError as e:
			cuerpo_err = e.read().decode("utf-8", "replace")[:500]
			if e.code in (429, 500, 502, 503) and intento < 3:
				## 429: el limite de RunPod es por minuto, asi que se espera de verdad (20, 40 y 60 s).
				time.sleep((20 if e.code == 429 else 3) * (intento + 1))
				continue
			raise ErrorRunPod(f"{metodo} {url}: HTTP {e.code} {cuerpo_err}") from e
		except (urllib.error.URLError, ConnectionError, TimeoutError, OSError) as e:
			## Cortes de red sueltos (RemoteDisconnected, reset...): se reintenta igual que un 503.
			if intento < 3:
				time.sleep(5 * (intento + 1))
				continue
			raise ErrorRunPod(f"{metodo} {url}: sin respuesta ({type(e).__name__}: {e})") from e
	raise ErrorRunPod("reintentos agotados")


def lista(ruta: str) -> list[dict]:
	r = pedir("GET", REST + ruta)
	if r is None:
		## Una lista vacia de RunPod llega como "null".
		return []
	return r if isinstance(r, list) else list(r.get("data") or r.get("items") or [])


def por_nombre(ruta: str, nombre: str) -> dict | None:
	return next((x for x in lista(ruta) if x.get("name") == nombre), None)


def asegurar(ruta: str, nombre: str, datos: dict, actualizar: bool = True) -> tuple[dict, str]:
	"""Crea o actualiza por nombre. Devuelve (objeto, 'creado'|'actualizado'|'igual')."""
	ya = por_nombre(ruta, nombre)
	if ya is None:
		return pedir("POST", REST + ruta, {"name": nombre, **datos}), "creado"
	if not actualizar:
		return ya, "igual"
	cambios = dict(datos)
	for _ in range(3):
		try:
			pedir("PATCH", f"{REST}{ruta}/{ya['id']}", cambios)
			break
		except ErrorRunPod as e:
			## Al actualizar, RunPod no admite algunos campos que si pide al crear (p. ej. isServerless o
			## category de una plantilla): los quita y lo vuelve a intentar.
			sobran = set(re.findall(r"not in input schema: '([A-Za-z0-9_]+)'", str(e))) & set(cambios)
			if not sobran:
				raise
			cambios = {k: v for k, v in cambios.items() if k not in sobran}
	return {**ya, **cambios}, "actualizado"


def borrar_volumenes_viejos(actual: str) -> list[str]:
	borrados = []
	for v in lista("/networkvolumes"):
		if str(v.get("name", "")).startswith("orq-modelos") and v.get("id") != actual:
			try:
				pedir("DELETE", f"{REST}/networkvolumes/{v['id']}")
				borrados.append(f"{v['name']} ({v.get('size')} GB)")
			except ErrorRunPod as e:
				borrados.append(f"{v['name']}: no se pudo borrar ({str(e)[:120]})")
	return borrados


def entorno(nombres: list[str]) -> dict:
	return {k: os.environ[k] for k in nombres if os.environ.get(k)}


def desplegar(imagen_fabrica: str, imagen_gpu: str, modelos: bool = False, motor: bool = False, espera_modelos_s: float = 3600,
		imagen_voces: str = "", muestras: str = "") -> dict:
	faltan = [k for k in OBLIGATORIOS if not os.environ.get(k)]
	if faltan:
		raise ErrorRunPod("Faltan secretos en GitHub: " + ", ".join(faltan))
	dc = (os.environ.get("ORQ_RUNPOD_DC") or "EU-RO-1")
	gpus = [g.strip() for g in (os.environ.get("ORQ_GPU") or ",".join(GPUS)).split(",") if g.strip()]
	usd_hora = float((os.environ.get("ORQ_GPU_USD_HORA") or str(USD_HORA_GPU)))
	informe: dict = {"centro_datos": dc}

	auth_id = ""
	if os.environ.get("GHCR_TOKEN"):
		auth, estado = asegurar("/containerregistryauth", "orq-ghcr",
			{"username": os.environ.get("GHCR_USUARIO", ""), "password": os.environ["GHCR_TOKEN"]}, actualizar=False)
		auth_id = auth["id"]
		informe["registro"] = estado

	## Volumen de modelos: se paga por GB al mes. RunPod no deja encogerlo, asi que para cambiar de tamano
	## se crea otro con otro nombre (variable ORQ_VOLUMEN_NOMBRE, p. ej. orq-modelos-65), se bajan los
	## modelos y despues se borran los viejos (12 nov: de 100 GB a 65; los modelos ocupan unos 58).
	nombre_vol = os.environ.get("ORQ_VOLUMEN_NOMBRE") or "orq-modelos"
	vol, estado = asegurar("/networkvolumes", nombre_vol, {"size": int((os.environ.get("ORQ_VOLUMEN_GB") or "100")),
		"dataCenterId": dc}, actualizar=False)
	informe["volumen"] = {"id": vol["id"], "nombre": nombre_vol, "estado": estado}
	if estado == "creado":
		## Volumen nuevo y vacio: hay que bajar los modelos si o si.
		modelos = True

	base_tpl = {"isServerless": True, "volumeInGb": 0, **({"containerRegistryAuthId": auth_id} if auth_id else {})}
	tpl_gpu, estado = asegurar("/templates", "orq-imagenes", {**base_tpl, "imageName": imagen_gpu,
		"containerDiskInGb": 30, "category": "NVIDIA", "env": entorno(["HF_TOKEN"])})
	ep_gpu, estado_ep = asegurar("/endpoints", "orq-imagenes", {"templateId": tpl_gpu["id"], "computeType": "GPU",
		"gpuTypeIds": gpus, "gpuCount": 1, "workersMin": 0, "workersMax": int((os.environ.get("ORQ_GPU_MAX") or "1")),
		## Una sola GPU: la fabrica pide las imagenes de una en una, y con mas maquinas RunPod arrancaba
		## (y cobraba) varias a la vez mientras la primera aun cargaba los modelos.
		## idleTimeout 30 s (ORQ_GPU_IDLE): entre dos imagenes pasan segundos (revision con Claude, post-proceso);
		## con 10 s la maquina se apagaba entre medias y cada arranque en frio cobraba otra vez la carga de modelos.
		"idleTimeout": int(os.environ.get("ORQ_GPU_IDLE") or "30"), "flashboot": True, "scalerType": "QUEUE_DELAY", "scalerValue": 4,
		"executionTimeoutMs": 600000, "networkVolumeId": vol["id"], "dataCenterIds": [dc]})
	informe["imagenes"] = {"id": ep_gpu["id"], "estado": estado_ep, "gpus": gpus}

	ep_voz = None
	if imagen_voces:
		tpl_voz, _ = asegurar("/templates", "orq-voces", {**base_tpl, "imageName": imagen_voces,
			"containerDiskInGb": 25, "category": "NVIDIA", "env": entorno(["HF_TOKEN"])})
		ep_voz, estado_ep = asegurar("/endpoints", "orq-voces", {"templateId": tpl_voz["id"], "computeType": "GPU",
			"gpuTypeIds": GPUS_VOZ, "gpuCount": 1, "workersMin": 0, "workersMax": int((os.environ.get("ORQ_VOZ_MAX") or "1")),
			"idleTimeout": int(os.environ.get("ORQ_GPU_IDLE") or "30"), "flashboot": True, "scalerType": "QUEUE_DELAY", "scalerValue": 4,
			"executionTimeoutMs": 600000, "networkVolumeId": vol["id"], "dataCenterIds": [dc]})
		informe["voces"] = {"id": ep_voz["id"], "estado": estado_ep}

	env_fabrica = {**entorno(SECRETOS_FABRICA), "RUNPOD_API_KEY": os.environ["RUNPOD_API_KEY"],
		"RUNPOD_IMAGEN_ENDPOINT": ep_gpu["id"], "ORQ_RUNPOD_USD_SEG": f"{usd_hora / 3600:.6f}",
		**({"RUNPOD_VOZ_ENDPOINT": ep_voz["id"], "ORQ_VOZ_USD_SEG": f"{USD_HORA_VOZ / 3600:.6f}"} if ep_voz else {})}
	tpl_cpu, _ = asegurar("/templates", "orq-fabrica", {**base_tpl, "imageName": imagen_fabrica,
		"containerDiskInGb": 30, "category": "CPU", "env": env_fabrica})
	ep_cpu, estado_ep = asegurar("/endpoints", "orq-fabrica", {"templateId": tpl_cpu["id"], "computeType": "CPU",
		"cpuFlavorIds": ["cpu5c", "cpu3c"], "vcpuCount": 4, "workersMin": 0, "workersMax": int((os.environ.get("ORQ_FABRICA_MAX") or "2")),
		"idleTimeout": 30, "flashboot": True, "scalerType": "REQUEST_COUNT", "scalerValue": 1, "executionTimeoutMs": 3600000})
	informe["fabrica"] = {"id": ep_cpu["id"], "estado": estado_ep}

	if modelos:
		informe["modelos"] = ejecutar(ep_gpu["id"], {"tarea": "descargar_modelos"}, espera_modelos_s)
		if ep_voz:
			informe["modelos_voz"] = ejecutar(ep_voz["id"], {"tarea": "descargar_modelos"}, espera_modelos_s)
		## Con los modelos ya en el volumen actual y los endpoints apuntando a el: fuera los volumenes
		## de modelos antiguos (cada GB se paga cada mes aunque no se use).
		informe["volumenes_borrados"] = borrar_volumenes_viejos(vol["id"])
	if motor:
		try:
			informe["motor"] = ejecutar(ep_cpu["id"], {"tarea": "motor"}, 1800)
		except ErrorRunPod as e:
			## La primera vez la base de datos (y su almacen "motor") aun no existe: se sube despues de Supabase.
			if "Bucket not found" not in str(e):
				raise
			informe["motor"] = "despues_de_supabase"
	if muestras:
		informe["muestras"] = hacer_muestras(ep_cpu["id"], muestras == "todas")
	return informe


def hacer_muestras(endpoint: str, todas: bool, tandas: int = 8) -> dict:
	"""Partidas de muestra de cada genero («Probar» en el taller). Cada llamada fabrica las que le dan
	tiempo; se repite mientras falten y se avance. Con todas=True la primera las rehace todas."""
	hechas: list[str] = []
	fallos: dict = {}
	faltan: list[str] = []
	for k in range(tandas):
		r = ejecutar(endpoint, {"tarea": "muestras", **({"todas": True} if todas and k == 0 else {})}, 3700)
		hechas += r.get("hechas", [])
		fallos.update(r.get("fallos", {}))
		faltan = r.get("faltan", [])
		if not faltan or not r.get("hechas"):
			break
	return {"hechas": len(hechas), "faltan": faltan, "fallos": fallos}


def ejecutar(endpoint: str, entrada: dict, espera_s: float) -> dict:
	"""Lanza un trabajo en un endpoint serverless y espera su resultado."""
	## El limite de este trabajo va con el (descargar modelos tarda mas que el limite normal del endpoint).
	r = pedir("POST", f"{SERVERLESS}/{endpoint}/run", {"input": entrada, "policy": {"executionTimeout": int(espera_s * 1000)}})
	tid = r["id"]
	limite = time.time() + espera_s
	pausa = 1.0
	while time.time() < limite:
		e = pedir("GET", f"{SERVERLESS}/{endpoint}/status/{tid}")
		if e.get("status") == "COMPLETED":
			return e.get("output") or {}
		if e.get("status") in ("FAILED", "CANCELLED", "TIMED_OUT"):
			raise ErrorRunPod(f"El trabajo {entrada} acabo en {e.get('status')}: {str(e.get('error') or e.get('output'))[:400]}")
		time.sleep(pausa)
		pausa = min(15.0, pausa * 1.5)
	try:
		pedir("POST", f"{SERVERLESS}/{endpoint}/cancel/{tid}")
	except ErrorRunPod:
		pass
	raise ErrorRunPod("Tiempo agotado esperando el trabajo " + json.dumps(entrada))


def _anotar(e: BaseException) -> None:
	"""En el despliegue real (ORQ_ANOTAR=1), el error sale en el resumen de GitHub sin abrir el registro."""
	if os.environ.get("ORQ_ANOTAR"):
		import traceback
		donde = traceback.extract_tb(e.__traceback__)[-2:] if e.__traceback__ else []
		sitio = " <- ".join(f"{f.name}:{f.lineno}" for f in reversed(donde))
		print("::error::" + (type(e).__name__ + ": " + str(e) + (f" [{sitio}]" if sitio else "")).replace("\n", " ")[:900])


def main(argv: list[str] | None = None) -> int:
	p = argparse.ArgumentParser(description="Despliega Orquestador en RunPod")
	p.add_argument("--imagen-fabrica", default="")
	p.add_argument("--imagen-gpu", default="")
	p.add_argument("--imagen-voces", default="", help="Imagen del endpoint de voces (Chatterbox)")
	p.add_argument("--modelos", action="store_true", help="Descarga los modelos al volumen de red")
	p.add_argument("--motor", action="store_true", help="Sube el motor web de Godot (una vez por version)")
	p.add_argument("--muestras", choices=["faltan", "todas"], default="",
		help="Partidas de muestra de cada genero para «Probar» en la app (las que faltan o todas otra vez)")
	p.add_argument("--muestras-en", default="", help="Solo las muestras, en este endpoint de la fabrica ya desplegado")
	p.add_argument("--motor-en", default="", help="Solo subir el motor web, en este endpoint de la fabrica ya desplegado")
	p.add_argument("--salida", default=os.environ.get("GITHUB_OUTPUT", ""))
	a = p.parse_args(argv)
	if a.motor_en:
		try:
			print(json.dumps(ejecutar(a.motor_en, {"tarea": "motor"}, 1800), indent=1, ensure_ascii=False))
			return 0
		except ErrorRunPod as e:
			print("ERROR:", e, file=sys.stderr)
			_anotar(e)
			return 1
	if a.muestras_en:
		try:
			print(json.dumps(hacer_muestras(a.muestras_en, a.muestras == "todas"), indent=1, ensure_ascii=False))
			return 0
		except ErrorRunPod as e:
			print("ERROR:", e, file=sys.stderr)
			_anotar(e)
			return 1
	if not a.imagen_fabrica or not a.imagen_gpu:
		p.error("--imagen-fabrica e --imagen-gpu son obligatorias (salvo con --muestras-en o --motor-en)")
	try:
		inf = desplegar(a.imagen_fabrica, a.imagen_gpu, a.modelos, a.motor, imagen_voces=a.imagen_voces, muestras=a.muestras)
	except ErrorRunPod as e:
		print("ERROR:", e, file=sys.stderr)
		_anotar(e)
		return 1
	print(json.dumps(inf, indent=1, ensure_ascii=False))
	if a.salida:
		with open(a.salida, "a", encoding="utf-8") as f:
			f.write(f"fabrica={inf['fabrica']['id']}\nimagenes={inf['imagenes']['id']}\n")
	return 0


if __name__ == "__main__":
	try:
		sys.exit(main())
	except Exception as e:
		_anotar(e)
		raise

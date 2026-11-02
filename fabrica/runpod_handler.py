"""La fabrica en RunPod serverless (CPU): se enciende cuando hay trabajo y se apaga sola.

Nada corre en el PC de nadie. El ciclo:
	1 - La app encarga algo -> la funcion del servidor lo mete en la cola de Supabase y llama a
	    POST https://api.runpod.ai/v2/<RUNPOD_FABRICA_ENDPOINT>/run  {"input": {"despertar": "juego"}}
	2 - RunPod arranca un contenedor (Dockerfile de runpod/fabrica) y llama a handler().
	3 - handler() vacia la cola con el mismo codigo que el trabajador propio (trabajador.vaciar_cola):
	    fabrica, dibuja en la GPU de RunPod (runpod://<RUNPOD_IMAGEN_ENDPOINT>), compila, sube.
	4 - Cola vacia -> devuelve y RunPod apaga la maquina (se paga solo el tiempo usado).
	{"input": {"tarea": "aprender"}} recalibra la dificultad con los jugadores (GitHub Actions cada 6 h).
	{"input": {"tarea": "motor"}} exporta y sube el motor web comun de Godot (una vez por version; lo
	lanza el despliegue). Sin el, «Jugar ya» no funciona dentro de la app.
	{"input": {"tarea": "muestras"}} fabrica y sube las partidas de muestra de los generos que aun no
	la tienen («Probar» en el catalogo del taller); {"todas": true} las rehace todas y
	{"generos": ["arquero", ...]} solo esas. Cada llamada para antes del limite: se repite hasta
	que no falte ninguna (lo hace el despliegue con --muestras).

Variables (secretos de RunPod, nunca en la app):
	SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY, ANTHROPIC_API_KEY, RUNPOD_API_KEY,
	RUNPOD_IMAGEN_ENDPOINT, ORQ_LLAVES_SECRETO, ORQ_PLAY_CUENTA, ELEVENLABS_API_KEY (opcional)
	ORQ_FABRICA_SALIDAS   que se genera (por defecto apk,web,ficha,clip,capturas)
	ORQ_FABRICA_LIMITE_S  segundos maximos por despertar (por defecto 3000; menos que el timeout del endpoint)
	ORQ_SIMULADO=1 / ORQ_ARTE_SIMULADO=1   solo para pruebas

Probar en local sin RunPod:  python runpod_handler.py --test_input '{"input": {"despertar": "prueba"}}'
"""

import os
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import cadena
import muestras
import subir_motor
import trabajador

SALIDAS = ("apk", "web", "ficha", "clip", "capturas")


def opciones():
	a = trabajador.argumentos().parse_args([])
	elegidas = [x.strip() for x in os.environ.get("ORQ_FABRICA_SALIDAS", ",".join(SALIDAS)).split(",") if x.strip()]
	for s in SALIDAS:
		setattr(a, s, s in elegidas)
	a.simulado = os.environ.get("ORQ_SIMULADO") == "1"
	a.arte_simulado = os.environ.get("ORQ_ARTE_SIMULADO") == "1"
	if not os.environ.get("ORQ_COMFY") and os.environ.get("RUNPOD_IMAGEN_ENDPOINT"):
		a.comfy = "runpod://" + os.environ["RUNPOD_IMAGEN_ENDPOINT"]
	return a


def motor_web(sb) -> dict:
	"""Exporta el preset Web del kit y sube el motor comun al bucket publico 'motor'."""
	kit = cadena.RAIZ.parent / "orqkit"
	tmp = Path(tempfile.mkdtemp(prefix="orq_motor_"))
	r = subprocess.run([cadena.godot_bin(), "--headless", "--path", str(kit), "--export-release", "Web", str(tmp / "index.html")],
		capture_output=True, text=True, timeout=900)
	try:
		lista = subir_motor.archivos_motor(tmp)
	except FileNotFoundError as e:
		return {"error": f"{e}. Godot dijo: {(r.stderr or r.stdout)[-400:]}"}
	for f in lista:
		sb.subir(f"godot/{subir_motor.VERSION_GODOT}/{f.name}", f, bucket="motor")
	return {"motor": [f.name for f in lista], "version": subir_motor.VERSION_GODOT}


def muestras_web(sb, entrada: dict) -> dict:
	"""Partidas de muestra de cada genero (fabrica/muestras.py) con el arte de la GPU si la hay."""
	op = opciones()
	todos = muestras.lista_generos()
	pedidos = [g for g in (entrada.get("generos") or []) if g in todos]
	if pedidos:
		lista = pedidos
	elif entrada.get("todas"):
		lista = todos
	else:
		ya = muestras.indice_remoto(sb)
		lista = [g for g in todos if g not in ya]
	limite = float(os.environ.get("ORQ_FABRICA_LIMITE_S", "3000"))
	salida = Path(tempfile.mkdtemp(prefix="orq_muestras_"))
	r = muestras.hacer(lista, salida, sb, simulado=True, arte_simulado=op.arte_simulado, comfy=op.comfy, limite_s=limite)
	faltan = [g for g in todos if g not in r["indice"]]
	return {"hechas": r["hechas"], "fallos": r["fallos"], "faltan": faltan, "segundos": r["segundos"]}


def handler(evento: dict, sb=None) -> dict:
	inicio = time.time()
	entrada = (evento or {}).get("input") or {}
	if sb is None:
		url = os.environ.get("SUPABASE_URL", "")
		clave = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
		if not url or not clave:
			return {"error": "Faltan SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY en los secretos del endpoint"}
		sb = trabajador.Supabase(url, clave)
		trabajador.conectar_aprendizaje(sb)
	trabajador.preparar_entorno()
	if entrada.get("tarea") == "motor":
		return motor_web(sb)
	if entrada.get("tarea") == "muestras":
		return muestras_web(sb, entrada)
	aprender = entrada.get("tarea") == "aprender"
	trabajador.mantenimiento(sb, aprender)
	op = opciones()
	if not op.arte_simulado and not op.comfy.startswith("runpod://") and "127.0.0.1" in op.comfy:
		return {"error": "Falta RUNPOD_IMAGEN_ENDPOINT (o ORQ_COMFY): la fabrica no tiene donde dibujar"}
	nombre = "runpod-" + os.environ.get("RUNPOD_POD_ID", socket.gethostname())
	limite = float(os.environ.get("ORQ_FABRICA_LIMITE_S", "3000"))
	hechos = trabajador.vaciar_cola(sb, op, nombre, limite_s=limite)
	return {"atendidos": hechos, "aprendio": aprender, "segundos": round(time.time() - inicio, 1)}


if __name__ == "__main__":
	import runpod  # solo existe en la imagen de la fabrica

	runpod.serverless.start({"handler": handler})
	sys.exit(0)

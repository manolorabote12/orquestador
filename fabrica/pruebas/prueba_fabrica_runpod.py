"""La fabrica tal y como corre en RunPod: handler() con un Supabase falso con cola y el arte en el
RunPod de imagenes simulado. Todo en la nube, nada en el PC.

	python -m pruebas.prueba_fabrica_runpod
"""

import os
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ))

import runpod_handler  # noqa: E402
from pruebas import runpod_simulado  # noqa: E402
from pruebas.prueba_trabajador import SupabaseFalso  # noqa: E402

fallos: list[str] = []


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
	if not ok:
		fallos.append(nombre)


class ConCola(SupabaseFalso):
	def __init__(self, trabajos: list[dict]):
		super().__init__()
		self.cola = list(trabajos)

	def rpc(self, funcion: str, **params):
		self.rpcs.append((funcion, params))
		if funcion == "claim_game_job":
			return [self.cola.pop(0)] if self.cola else []
		if funcion == "expire_stuck_jobs":
			return 0
		if funcion == "estadisticas_globales":
			return []
		return True


def main() -> int:
	srv = runpod_simulado.arrancar(0)
	entorno = {
		"ORQ_RUNPOD_API": f"http://127.0.0.1:{srv.server_address[1]}/v2", "RUNPOD_API_KEY": "rp-clave-prueba",
		"RUNPOD_IMAGEN_ENDPOINT": "orq-imagen", "ORQ_SIMULADO": "1", "ORQ_FABRICA_SALIDAS": "",
		"ORQ_DATOS": str(RAIZ / "salida_prueba" / "datos_runpod"),
	}
	viejo = {k: os.environ.get(k) for k in list(entorno) + ["ORQ_COMFY", "ORQ_ARTE_SIMULADO"]}
	os.environ.update(entorno)
	os.environ.pop("ORQ_COMFY", None)
	os.environ.pop("ORQ_ARTE_SIMULADO", None)
	try:
		print("== Fabrica en RunPod ==")
		op = runpod_handler.opciones()
		check("dibuja en el endpoint de imagenes de RunPod", op.comfy == "runpod://orq-imagen", op.comfy)
		check("flujos por defecto: Z-Image + FLUX.2 klein", op.crear.endswith("crear_zimage.json") and op.editar.endswith("editar_klein.json"))

		sb = ConCola([
			{"job_id": "00000000-aaaa-0000-0000-000000000001", "user_id": "u1", "kind": "game",
				"idea": "un gato que salta entre tejados recogiendo pescado"},
			{"job_id": "00000000-bbbb-0000-0000-000000000002", "user_id": "u1", "kind": "game",
				"idea": "una nave que esquiva asteroides en el espacio"},
		])
		r = runpod_handler.handler({"id": "rp1", "input": {"despertar": "juego"}}, sb=sb)
		hechos = [p for f, p in sb.rpcs if f == "complete_game_job"]
		check("vacia la cola entera en un despertar", r.get("atendidos") == 2 and len(hechos) == 2, str(r))
		check("limpia trabajos caducados al despertar", any(f == "expire_stuck_jobs" for f, _ in sb.rpcs))
		check("el arte se pinto en RunPod", runpod_simulado.ESTADO["peticiones"] > 10, f"{runpod_simulado.ESTADO['peticiones']} imagenes")
		check("cobra el coste real de GPU", all(h["p_cost_usd"] > 0 for h in hechos), str([h["p_cost_usd"] for h in hechos]))
		check("sube el proyecto al almacen", any(k.endswith(".zip") for k in sb.archivos), str(list(sb.archivos)[:4]))

		r2 = runpod_handler.handler({"input": {"despertar": "juego"}}, sb=ConCola([]))
		check("cola vacia: se apaga enseguida", r2.get("atendidos") == 0 and r2["segundos"] < 5, str(r2))
		r3 = runpod_handler.handler({"input": {"tarea": "aprender"}}, sb=ConCola([]))
		check("tarea aprender no rompe", r3.get("aprendio") is True, str(r3))

		sb5 = ConCola([])
		r5 = runpod_handler.handler({"input": {"tarea": "motor"}}, sb=sb5)
		check("sube el motor web comun (Jugar ya)", any(k.startswith("motor/godot/") and k.endswith("index.wasm") for k in sb5.archivos), str(r5)[:200])

		os.environ.pop("RUNPOD_IMAGEN_ENDPOINT")
		r4 = runpod_handler.handler({"input": {}}, sb=ConCola([]))
		check("sin endpoint de imagenes avisa claro", "RUNPOD_IMAGEN_ENDPOINT" in r4.get("error", ""), str(r4))
	finally:
		srv.shutdown()
		for k, v in viejo.items():
			if v is None:
				os.environ.pop(k, None)
			else:
				os.environ[k] = v
	print(f"== {len(fallos)} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

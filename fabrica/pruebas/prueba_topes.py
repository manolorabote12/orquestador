"""Topes de gasto de GPU y limite de imagenes: que un juego caro no se convierta en un fallo caro.

python -m pruebas.prueba_topes

1 - El arranque en frio de RunPod se cobra (delayTime) y entra en el coste.
2 - Pasado el tope duro no se pide mas GPU; si el servidor da el trabajo por terminado, tampoco.
3 - Si un juego llega al tope mientras dibuja, se termina igual: heroe, primer enemigo y suelo
    dibujados, el resto con frames quietos o el dibujo provisional del kit.
4 - El limite de imagenes por juego recorta animaciones sin romper la biblia.
5 - Si el servidor da el juego por terminado, la fabrica para tambien la CPU (el siguiente evento).
"""

import argparse
import copy
import json
import os
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ))

from arte import biblia as bib  # noqa: E402
from arte import cli, runpod  # noqa: E402
from arte.runpod import RunPodCliente  # noqa: E402
from pruebas import runpod_simulado  # noqa: E402

fallos: list[str] = []


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
	if not ok:
		fallos.append(nombre)


def main() -> int:
	srv = runpod_simulado.arrancar(0)
	os.environ["ORQ_RUNPOD_API"] = f"http://127.0.0.1:{srv.server_address[1]}/v2"
	os.environ["RUNPOD_API_KEY"] = "rp-clave-prueba"
	os.environ["ORQ_RUNPOD_USD_SEG"] = "0.001"
	E = runpod_simulado.ESTADO
	wf = json.loads((RAIZ / "plantillas" / "runpod" / "crear_zimage.json").read_text(encoding="utf-8"))
	valores = {"PROMPT": "un gato", "SEED": 1, "ANCHO": 512, "ALTO": 512}
	try:
		print("== Coste con arranque en frio ==")
		runpod.reiniciar_gasto()
		c = RunPodCliente("runpod://x")
		c.generar(wf, valores)
		check("sin arranque (espera corta) solo la GPU", abs(c.usd - 2.3 * 0.001) < 1e-9 and c.arranques == 0, f"{c.usd}")
		E["retraso_ms"] = 30000
		c.generar(wf, valores)
		check("arranque en frio: espera + apagado", c.arranques == 1 and abs(c.segundos_arranque - 40.0) < 1e-6, f"{c.segundos_arranque} s")
		check("y entra en el coste", abs(c.usd - (2.3 * 2 + 40) * 0.001) < 1e-9 and abs(runpod.GASTO["usd"] - c.usd) < 1e-9, f"{c.usd}")
		E["retraso_ms"] = 900000
		c.generar(wf, valores)
		check("una espera enorme cuenta como mucho el maximo de arranque", abs(c.segundos_arranque - (40 + 240 + 10)) < 1e-6, f"{c.segundos_arranque}")
		E["retraso_ms"] = 800

		print("== Topes ==")
		runpod.reiniciar_gasto()
		runpod.GASTO["usd"] = 0.60
		try:
			c.generar(wf, valores)
			check("pasado el tope duro no se pide GPU", False)
		except runpod.TopeGPU:
			check("pasado el tope duro no se pide GPU", True)
		runpod.GASTO["imprescindible"] = True
		pedidas = E["peticiones"]
		c.generar(wf, valores)
		check("lo imprescindible aun cabe (margen x1.5)", E["peticiones"] == pedidas + 1)
		runpod.GASTO["usd"] = 0.80
		try:
			c.generar(wf, valores)
			check("ni lo imprescindible pasa del margen", False)
		except runpod.TopeGPU:
			check("ni lo imprescindible pasa del margen", True)
		runpod.reiniciar_gasto()
		runpod.GASTO["cancelado"] = True
		try:
			c.generar(wf, valores)
			check("trabajo caducado: nada de GPU", False)
		except runpod.TrabajoCancelado:
			check("trabajo caducado: nada de GPU", True)
		runpod.reiniciar_gasto()

		print("== Juego que llega al tope mientras dibuja ==")
		## 2,3 s por imagen a 0,001 $/s: el tope duro (0,012 $) llega a la 6a imagen, en los frames del heroe.
		os.environ["ORQ_TOPE_GPU_SUAVE"] = "0.006"
		os.environ["ORQ_TOPE_GPU_DURO"] = "0.012"
		salida = RAIZ / "salida_prueba" / "topes"
		inf = cli.fabricar(argparse.Namespace(
			biblia=str(RAIZ / "ejemplos" / "biblia_salto.json"), comfy="runpod://orq-imagen",
			crear=str(RAIZ / "plantillas" / "runpod" / "crear_zimage.json"),
			editar=str(RAIZ / "plantillas" / "runpod" / "editar_klein.json"),
			salida=str(salida), godot="", lado=256, musica="", sfx="", voces="", fondos=False))
		check("el juego se termina igual", inf.get("tope_gpu") is True, str(inf["avisos"][:3]))
		check("heroe dibujado con todas sus animaciones", sorted(inf["sprites"].get("heroe", {})) == ["fall", "idle", "jump", "run"], str(inf["sprites"].keys()))
		check("el primer enemigo tambien (imprescindible)", "chatarrilla" in inf["sprites"], str(inf["sprites"].keys()))
		## Primero se dibujan todas las fichas y luego los frames: lo que no cabe sale quieto (o provisional).
		check("lo que no cabe sale sin GPU (quieto o provisional)", "moneda" not in inf["sprites"]
			or any("quietos" in x or "moneda" in x for x in inf["avisos"]), str(inf["avisos"][:4]))
		check("suelo dibujado", "suelo" in inf["tiles"] or bool(inf["tiles"]), str(inf["tiles"]))
		check("no pasa del margen de lo imprescindible", runpod.GASTO["usd"] <= 0.012 * 1.5 + 0.0024, f"{runpod.GASTO['usd']:.4f} $")
		check("informe con segundos por imagen", inf.get("seg_por_imagen", 0) > 0 and "segundos_arranque" in inf, str(inf.get("seg_por_imagen")))
		for k in ("ORQ_TOPE_GPU_SUAVE", "ORQ_TOPE_GPU_DURO"):
			os.environ.pop(k)
		runpod.reiniciar_gasto()

		print("== Limite de imagenes por juego ==")
		grande = json.loads((RAIZ / "ejemplos" / "biblia_salto.json").read_text(encoding="utf-8"))
		for i in range(3):
			e = copy.deepcopy(next(p for p in grande["personajes"] if p["rol"] == "enemigo"))
			e["id"] = f"enemigo_{i}"
			e["animaciones"]["hurt"] = {"frames": 1, "fps": 1, "bucle": False}
			grande["personajes"].append(e)
		antes = bib.imagenes(grande, 8)
		ahorro = bib.recortar(grande, 36, 8)
		despues = bib.imagenes(grande, 8)
		bib.validar(grande)
		check("deja la biblia en el limite", despues <= 36 and ahorro == antes - despues, f"{antes} -> {despues}")
		heroe = next(p for p in grande["personajes"] if p["rol"] == "jugador")
		check("la carrera del heroe conserva 4 frames", heroe["animaciones"]["run"]["frames"] >= 4)
		check("ninguna animacion en bucle baja de 2 frames", all(int(c["frames"]) >= 2 for p in grande["personajes"] + grande["objetos"]
			for c in p["animaciones"].values() if c.get("bucle", True) and not c.get("desde_ficha")))
		check("el golpe de los enemigos sale de la ficha", all(p["animaciones"].get("hurt", {}).get("desde_ficha", True)
			for p in grande["personajes"] if p["rol"] == "enemigo"))
		from arte import prompts
		encs = prompts.encargos_imagen(grande)
		check("los encargos cuadran con la cuenta", len(encs) == despues - 8, f"{len(encs)} encargos")
		pequena = json.loads((RAIZ / "ejemplos" / "biblia_salto.json").read_text(encoding="utf-8"))
		check("una biblia pequena no se toca", bib.recortar(pequena, 36, 8) == 0)

		print("== Caducado: la CPU tambien para ==")
		import cadena
		runpod.GASTO["cancelado"] = True
		try:
			cadena.evento("validacion", "inicio", "Probando el juego con bots...")
			check("el siguiente evento corta la fabrica", False)
		except cadena.ErrorCadena:
			check("el siguiente evento corta la fabrica", True)
		runpod.reiniciar_gasto()
		cadena.evento("validacion", "inicio", "sigue")
		check("sin caducar, sigue", True)
	finally:
		srv.shutdown()
	print(f"== {len(fallos)} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

"""El agente que crea generos: con una IA falsa que primero se equivoca y luego acierta.

	python -m pruebas.prueba_agente

Ronda 1: codigo peligroso -> se rechaza sin ejecutarlo.
Ronda 2: un error de sintaxis de GDScript -> la prueba real falla y el error vuelve a la IA.
Ronda 3: la plantilla correcta -> PRUEBA SUPERADA. Al final se deshace el genero de prueba.
"""

import subprocess
import sys

import agente_genero
from director import llm


def main() -> int:
	fallos = 0

	def check(nombre: str, ok: bool, detalle: str = "") -> None:
		nonlocal fallos
		print(("  OK   " if ok else "  FALLO ") + nombre + (f"  ({detalle})" if detalle and not ok else ""))
		fallos += 0 if ok else 1

	es, kit = "rejillaagente", "gridagent"
	buena = agente_genero.plantilla(es, kit)
	mala_seguridad = dict(buena, juego_gd=buena["juego_gd"] + "\n\nfunc _x() -> void:\n\tOS.execute(\"calc\", [])\n")
	mala_sintaxis = dict(buena, mapa_gd=buena["mapa_gd"].replace("static func analyze(level: Dictionary) -> Dictionary:",
		"static func analyze(level: Dictionary) -> Dictionary\n", 1))
	respuestas = [mala_seguridad, mala_sintaxis, buena]
	vistos: list[str] = []

	def falsa(modelo, sistema, mensajes, herramienta, gasto, nota, max_tokens=3000, reintentos=3):
		vistos.append(mensajes[-1]["content"] if isinstance(mensajes[-1]["content"], str) else "")
		return dict(respuestas[len(vistos) - 1], notas=f"ronda {len(vistos)}")

	llm.llamar_herramienta = falsa
	agente_genero.llm.llamar_herramienta = falsa
	sys.argv = ["agente_genero", "rejilla de prueba del agente: recoge monedas", es, kit, "--claves", es]
	try:
		codigo = agente_genero.main()
	finally:
		subprocess.run([sys.executable, "-m", "nuevo_genero", es, kit, "--quitar"], cwd=agente_genero.RAIZ, capture_output=True)
	import json
	inf = json.loads((agente_genero.RAIZ / "datos" / "agente" / f"{es}.json").read_text(encoding="utf-8"))
	r = inf["rondas"]
	check("termina bien a la tercera", codigo == 0 and inf["ok"] and len(r) == 3, str([(x["ronda"], x["fase"], x.get("ok")) for x in r]))
	check("ronda 1: el codigo peligroso se rechaza sin ejecutarlo", r[0]["fase"] == "revision" and "seguridad" in r[0]["errores"])
	check("ronda 2: el error de sintaxis se detecta en la prueba real", r[1]["fase"] == "prueba" and not r[1]["ok"]
		and ("Parse Error" in r[1]["errores"] or "SCRIPT ERROR" in r[1]["errores"] or "rror" in r[1]["errores"]), r[1]["errores"][:300])
	check("los errores vuelven a la IA en la ronda siguiente", "seguridad" in vistos[1] and len(vistos) == 3 and r[1]["errores"][:40] in vistos[2])
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

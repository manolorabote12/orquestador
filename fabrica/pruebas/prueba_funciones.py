"""Lo que lleva el juego publicado (tienda, pase, avisos, nube, online) y el modo para ninos.

	python -m pruebas.prueba_funciones
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from director import cambios, director, simulado  # noqa: E402
from play import cuestionarios  # noqa: E402


def main() -> int:
	fallos = 0

	def check(nombre: str, ok: bool, detalle: str = "") -> None:
		nonlocal fallos
		print(("  OK   " if ok else "  FALLO ") + nombre + (f"  ({detalle})" if detalle and not ok else ""))
		fallos += 0 if ok else 1

	d = director.normalizar(simulado.disenar("un gato ninja que salta por tejados"))
	mapas = director.generar_niveles(d, 3, {i: 0 for i in range(len(d["niveles"]))}, [None] * len(d["niveles"]), {})
	g = director.a_game(d, mapas)
	check("por defecto, todo encendido", all(g["features"].values()) and g["iap"] and not g["kids"])
	plan = {"resumen": "Quito la tienda", "operaciones": [{"op": "funciones", "tienda": False, "avisos": False}]}
	check("el plan 'funciones' es valido y solo cuesta la base", not cambios.validar_plan(plan, d) and cambios.coste(plan) == cambios.PRECIOS["base"],
		str(cambios.validar_plan(plan, d)))
	d2, ef = cambios.aplicar_diseno(d, mapas, plan)
	g2 = director.a_game(d2, mapas)
	check("sin tienda ni avisos, lo demas igual", not g2["features"]["tienda"] and not g2["iap"] and not g2["features"]["avisos"]
		and g2["features"]["pase"] and g2["features"]["online"])
	check("no rehace arte ni niveles", not ef["arte"] and not ef["niveles"])
	d3, _ = cambios.aplicar_diseno(d2, mapas, {"resumen": "Para peques", "operaciones": [{"op": "funciones", "publico": "infantil", "tienda": True}]})
	g3 = director.a_game(d3, mapas)
	check("para ninos: tienda, avisos y online apagados aunque se pidan", g3["kids"] and not g3["features"]["tienda"]
		and not g3["features"]["online"] and not g3["features"]["avisos"] and g3["features"]["nube"])
	guia = cuestionarios.guia(d3, "com.a.b", "a@b.c", "https://x", True, True)
	campos = {k: v for p in guia["pasos"] for k, v in p.get("campos", {}).items()}
	check("ficha para ninos: atrae a ninos, sin compras ni interaccion", campos["¿Atrae a niños?"] == "Sí"
		and campos["Compras digitales"] == "No" and campos["Interacción entre usuarios o chat"] == "No")
	guia = cuestionarios.guia(d, "com.a.b", "a@b.c", "https://x", True, True)
	campos = {k: v for p in guia["pasos"] for k, v in p.get("campos", {}).items()}
	check("ficha normal: declara compras e interaccion por apodos", campos["Compras digitales"].startswith("Sí")
		and campos["Interacción entre usuarios o chat"].startswith("Sí"))
	pol = cuestionarios.privacidad_cuerpo(d3, "a@b.c", True, True)
	check("politica para ninos: apta, sin compras ni online", "apto para niños" in pol and "Compras dentro" not in pol and "Juego online" not in pol)
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

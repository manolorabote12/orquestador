"""Pruebas A/B de un nivel: la version B se genera, se valida con los bots como un nivel mas, va en
game.json colgada de su nivel y, al terminar, se queda la que gana.

	python -m pruebas.prueba_ab           (unidades + cadena entera simulada con Godot)
	python -m pruebas.prueba_ab rapido    (solo unidades)
"""

import argparse
import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from director import cambios, director, simulado  # noqa: E402

SALIDA = Path(__file__).resolve().parent.parent.parent / "proyectos_prueba_ab"


def main() -> int:
	fallos = 0

	def check(nombre: str, ok: bool, detalle: str = "") -> None:
		nonlocal fallos
		print(("  OK   " if ok else "  FALLO ") + nombre + (f"  ({detalle})" if detalle and not ok else ""))
		fallos += 0 if ok else 1

	print("== Unidades ==")
	d = director.normalizar(simulado.disenar("un gato ninja que salta por tejados"))
	n = len(d["niveles"])
	mapas = director.generar_niveles(d, 3, {i: 0 for i in range(n)}, [None] * n, {})
	empezar = {"resumen": "Pruebo el nivel 2 mas facil", "operaciones": [{"op": "prueba_ab", "indice": 1, "hacia": "mas_facil"}]}
	check("plan valido y cuesta como rehacer un nivel", not cambios.validar_plan(empezar, d)
		and cambios.coste(empezar) == cambios.PRECIOS["base"] + cambios.PRECIOS["prueba_ab"], str(cambios.validar_plan(empezar, d)))
	check("terminar sin prueba en marcha no vale", bool(cambios.validar_plan({"resumen": "x", "operaciones": [{"op": "prueba_ab", "ganadora": "b"}]}, d)))
	check("sin indice no vale", bool(cambios.validar_plan({"resumen": "x", "operaciones": [{"op": "prueba_ab", "hacia": "mas_facil"}]}, d)))
	check("no se mezcla con anadir niveles", bool(cambios.validar_plan({"resumen": "x", "operaciones": [empezar["operaciones"][0],
		{"op": "anadir_nivel", "nombre": "Otro"}]}, d)))
	d2, ef = cambios.aplicar_diseno(d, mapas, empezar)
	check("diseno con la prueba y solo se genera la B", d2.get("prueba_ab", {}).get("nivel") == 1 and ef["niveles"] == {n} and len(ef["mapas"]) == n + 1,
		str((d2.get("prueba_ab"), ef["niveles"])))
	m2 = director.generar_niveles(d2, 3, {i: 0 for i in ef["niveles"]}, ef["mapas"], ef["ajustes_nivel"])
	check("los niveles A no cambian y la B es distinta", m2[:n] == mapas and m2[n] != mapas[1])
	g = director.a_game(d2, m2)
	check("game.json: B colgada del nivel 2 y bloque ab", g["levels"][1].get("variant_b", {}).get("map") == m2[n] and "name" not in g["levels"][1]["variant_b"]
		and g["ab"]["level"] == 1 and len(g["levels"]) == n)
	check("mapas_de devuelve la B al final", director.mapas_de(g) == m2)
	check("otra prueba con una en marcha no vale", bool(cambios.validar_plan(empezar, d2)))
	textos = {"resumen": "Titulo", "operaciones": [{"op": "textos", "titulo": "Gato Nuevo"}]}
	d3, ef3 = cambios.aplicar_diseno(d2, m2, textos)
	check("otros cambios conservan la prueba y su B", d3.get("prueba_ab") == d2["prueba_ab"] and ef3["mapas"][n] == m2[n] and n not in ef3["niveles"])
	d4, ef4 = cambios.aplicar_diseno(d2, m2, {"resumen": "Mas dificil", "operaciones": [{"op": "ajustes", "dificultad": "dificil"}]})
	check("si se rehacen todos los niveles, la B tambien", d4.get("prueba_ab") and n in ef4["niveles"])
	d5, _ = cambios.aplicar_diseno(d2, m2, {"resumen": "Rehago", "operaciones": [{"op": "rehacer_nivel", "indice": 1}]})
	check("rehacer el nivel probado termina la prueba", "prueba_ab" not in d5)
	ganab = {"resumen": "Gana la B", "operaciones": [{"op": "prueba_ab", "ganadora": "b"}]}
	check("terminar cuesta poco", cambios.coste(ganab) == cambios.PRECIOS["base"] + cambios.PRECIOS["prueba_ab_fin"])
	d6, ef6 = cambios.aplicar_diseno(d2, m2, ganab)
	check("gana la B: pasa a ser el nivel de todos sin regenerar", "prueba_ab" not in d6 and ef6["mapas"][1] == m2[n] and not ef6["niveles"]
		and len(ef6["mapas"]) == n)
	g6 = director.a_game(d6, ef6["mapas"])
	check("sin prueba no hay bloque ab ni variante", "ab" not in g6 and not any("variant_b" in lv for lv in g6["levels"]))
	d7, ef7 = cambios.aplicar_diseno(d2, m2, {"resumen": "Gana la A", "operaciones": [{"op": "prueba_ab", "ganadora": "a"}]})
	check("gana la A: se queda el nivel de siempre", "prueba_ab" not in d7 and ef7["mapas"] == mapas)
	check("un juego nuevo nunca nace con prueba", "prueba_ab" not in director.disenar("un gato ninja que salta por tejados", True, None)[0])

	if len(sys.argv) > 1 and sys.argv[1] == "rapido":
		print(f"== {fallos} fallos ==")
		return 1 if fallos else 0

	print("== Cadena entera (Godot y bots) ==")
	import cadena
	import cambio
	shutil.rmtree(SALIDA, ignore_errors=True)
	inf = cadena.fabricar(argparse.Namespace(idea="un gato ninja rápido que salta por tejados de noche", salida=str(SALIDA),
		simulado=True, arte_simulado=True, comfy="", crear="", editar="", lado=512, semilla=5, apk=False, capturas=False))
	P = Path(inf["proyecto"])

	def plan(p: dict) -> dict:
		return cambio.cambiar(argparse.Namespace(proyecto=str(P), instruccion=p["resumen"], plan=json.dumps(p), solo_plan=False, simulado=True,
			arte_simulado=True, comfy="", crear="", editar="", lado=512, semilla=5, slug="", apk=False, capturas=False))

	def game() -> dict:
		return json.loads((P / "game.json").read_text(encoding="utf-8"))

	antes = [lv["map"] for lv in game()["levels"]]
	r = plan(empezar)
	g = game()
	vb = g["levels"][1].get("variant_b")
	niveles = r["validacion"]["niveles"]
	check("cadena: version con la prueba", r["aplicado"] and g.get("ab", {}).get("level") == 1 and vb is not None)
	check("cadena: los bots han jugado tambien la B", len(niveles) == len(antes) + 1 and all(cadena.nivel_ok(x, True) for x in niveles),
		json.dumps(niveles)[:400])
	check("cadena: los niveles A siguen igual", [lv["map"] for lv in g["levels"]] == antes)
	r = plan(ganab)
	g = game()
	check("cadena: gana la B y queda como nivel 2", r["aplicado"] and g["levels"][1]["map"] == vb["map"] and "ab" not in g
		and len(r["validacion"]["niveles"]) == len(antes))
	shutil.rmtree(SALIDA, ignore_errors=True)
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

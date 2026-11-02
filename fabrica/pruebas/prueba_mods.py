"""Agente programador sin gastar: mod simulado y un Claude falso que primero se equivoca.

	python -m pruebas.prueba_mods
"""

import argparse
import json
import re
import shutil
import sys
import tempfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ))

import agente_mods  # noqa: E402
import cadena  # noqa: E402
from director import llm  # noqa: E402

fallos: list[str] = []


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
	if not ok:
		fallos.append(nombre)


BUENO = 'extends "res://kit/mod_base.gd"\n\nvar saltos: int = 0\n\n\nfunc on_event(event_name: String, _data: Dictionary) -> void:\n\tif event_name == "coin":\n\t\tadd_wallet(1)\n'
PELIGROSO = 'extends "res://kit/mod_base.gd"\n\nfunc on_level_start() -> void:\n\tOS.execute("rm", ["-rf", "/"])\n'
ROMPE = 'extends "res://kit/mod_base.gd"\n\nfunc on_level_start() -> void:\n\tvar n: Node = null\n\tn.queue_free()\n'
NO_COMPILA = 'extends "res://kit/mod_base.gd"\n\nfunc on_level_start() -> void:\n\tvar x: int = "texto"\n'


def main() -> int:
	tmp = Path(tempfile.mkdtemp())
	inf = cadena.fabricar(argparse.Namespace(idea="un gato ninja que salta por tejados", salida=str(tmp), simulado=True,
		arte_simulado=True, comfy="", crear="", editar="", lado=512, semilla=5, apk=False, capturas=False))
	proyecto = Path(inf["proyecto"])
	print("== Revision de seguridad ==")
	check("rechaza OS.execute", any("OS." in e or "seguridad" in e for e in agente_mods.revisar("x_mod", PELIGROSO)))
	check("rechaza load()", any("load" in e for e in agente_mods.revisar("x_mod", BUENO + '\nvar t: Texture2D = load("res://icon.png")\n')))
	check("rechaza tocar Save", bool(agente_mods.revisar("x_mod", BUENO + "\nfunc on_tick(_d: float) -> void:\n\tSave.reset_all()\n")))
	check("exige heredar de la base", any("primera linea" in e for e in agente_mods.revisar("x_mod", "extends Node\n")))
	check("exige tabulaciones", any("espacios" in e for e in agente_mods.revisar("x_mod", BUENO.replace("\t", "    "))))
	check("un mod correcto pasa", agente_mods.revisar("monedas_extra", BUENO) == [], str(agente_mods.revisar("monedas_extra", BUENO)))

	print("== Mod simulado ==")
	r = agente_mods.programar(proyecto, "chispas doradas al empezar", True, llm.Gasto())
	game = json.loads((proyecto / "game.json").read_text())
	check("escribe el mod y lo engancha al juego", Path(r["ruta"]).exists() and "res://mods/chispas_doradas.gd" in game.get("mods", []))
	check("compila y la partida de humo va limpia", r["rondas"] == 1)

	print("== Claude se equivoca y lo corrige ==")
	respuestas = [{"nombre": "monedas_extra", "codigo": PELIGROSO, "resumen": "x"},
		{"nombre": "monedas_extra", "codigo": BUENO, "resumen": "Cada moneda da 1 extra para la tienda"}]
	vistos: list = []

	def falso(sistema, mensajes):
		vistos.append(mensajes)
		return respuestas[len(vistos) - 1]
	r2 = agente_mods.programar(proyecto, "una moneda extra por cada moneda", False, llm.Gasto(), llamar=falso)
	check("segunda ronda tras el rechazo de seguridad", r2["rondas"] == 2)
	check("a Claude le llegan los errores", "seguridad" in json.dumps(vistos[1], ensure_ascii=False))
	print("== Un mod que rompe el juego no se queda ==")
	antes = json.loads((proyecto / "game.json").read_text())["mods"]
	malos = iter([{"nombre": "roto", "codigo": NO_COMPILA, "resumen": "x"}, {"nombre": "roto", "codigo": ROMPE, "resumen": "x"},
		{"nombre": "roto", "codigo": ROMPE, "resumen": "x"}])
	try:
		agente_mods.programar(proyecto, "algo imposible", False, llm.Gasto(), llamar=lambda s, m: next(malos))
		check("tras 3 rondas fallidas, error", False)
	except cadena.ErrorCadena as e:
		check("tras 3 rondas fallidas, error", "romper" in str(e), str(e)[:100])
	check("el proyecto queda como estaba", json.loads((proyecto / "game.json").read_text())["mods"] == antes
		and not (proyecto / "mods" / "roto.gd").exists())
	print("== Los bots siguen ganando con los mods ==")
	diseno = json.loads((proyecto / "fabrica" / "diseno.json").read_text())
	mapas = [lv["map"] for lv in json.loads((proyecto / "game.json").read_text())["levels"]]
	val, _ = cadena.validar_con_bots(proyecto, diseno, mapas, 5, {}, {})
	check("validacion con bots OK", bool(val.get("ok")), str(val.get("fallos_qa"))[:200])
	print("== Reglas: cambiar la mecanica (caida con piezas de agua) ==")
	agua = (cadena.KIT / "qa" / "regla_agua.gd").read_text(encoding="utf-8")
	check("una regla correcta pasa", agente_mods.revisar("piezas_de_agua", agua, "regla") == [])
	check("una regla con azar del motor no pasa", bool(agente_mods.revisar("x_regla", agua + "\nfunc a() -> float:\n\treturn randf()\n", "regla")))
	check("una regla que toca la escena no pasa", bool(agente_mods.revisar("x_regla", agua + "\nfunc b(st: Dictionary) -> void:\n\tvar n: Node2D = null\n", "regla")))
	tmp2 = Path(tempfile.mkdtemp())
	inf2 = cadena.fabricar(argparse.Namespace(idea="un tetris de bloques que caen en un salon de neon", salida=str(tmp2), simulado=True,
		arte_simulado=True, comfy="", crear="", editar="", lado=512, semilla=7, apk=False, capturas=False))
	p2 = Path(inf2["proyecto"])
	r3 = agente_mods.programar(p2, "que algunas piezas sean de agua y se derramen", True, llm.Gasto())
	g2 = json.loads((p2 / "game.json").read_text())
	check("la regla se engancha como regla", r3.get("tipo") == "regla" and "res://mods/piezas_de_agua.gd" in g2.get("rules", []), str(r3))
	d2 = json.loads((p2 / "fabrica" / "diseno.json").read_text())
	val2, _ = cadena.validar_con_bots(p2, d2, [lv["map"] for lv in g2["levels"]], 5, {}, {})
	check("con la regla puesta, los bots siguen ganando", bool(val2.get("ok")), str(val2.get("fallos_qa"))[:200])
	ya = sorted(agente_mods.GENEROS_REGLAS)
	## Cada genero con reglas llama de verdad a sus ganchos en su simulacion.
	sin = [k for k in ya if k in agente_mods.GENEROS_SIM and not any("Rules.hook(st, \"on_start\")" in p.read_text(encoding="utf-8") for p in (cadena.KIT / "kit" / k).glob("*.gd"))]
	check("los generos con reglas tienen ganchos", len(ya) >= 10 and not sin, str(ya) + " sin ganchos: " + str(sin))
	mods_gd = (cadena.KIT / "kit" / "mods.gd").read_text(encoding="utf-8")
	check("las reglas vivas son las mismas en la fabrica y en el kit", all(f'"{g}"' in mods_gd.split("const LIVE_GENRES")[1].split("\n")[0] for g in agente_mods.GENEROS_VIVOS))
	sim_kit = mods_gd.split("const SIM_RULES")[1].split("= [")[1].split("]")[0]
	check("los generos con simulacion propia son los mismos en la fabrica y en el kit", sorted(re.findall(r'"([a-z0-9_]+)"', sim_kit)) == sorted(agente_mods.GENEROS_SIM))
	check("todos los generos admiten reglas (los de escena, al menos la velocidad)", len(agente_mods.GENEROS_REGLAS) >= 98)
	## Reglas vivas: en un plataformas la regla cambia los mandos y los bots la vuelven a comprobar.
	tmp3 = Path(tempfile.mkdtemp())
	inf3 = cadena.fabricar(argparse.Namespace(idea="un gato ninja que salta por tejados de noche", salida=str(tmp3), simulado=True,
		arte_simulado=True, comfy="", crear="", editar="", lado=512, semilla=7, apk=False, capturas=False))
	p3 = Path(inf3["proyecto"])
	r4 = agente_mods.programar(p3, "que cada moneda me haga correr mas rapido (regla)", True, llm.Gasto())
	g3 = json.loads((p3 / "game.json").read_text())
	check("plataformas: la regla viva se engancha como regla", r4.get("tipo") == "regla" and "res://mods/monedas_turbo.gd" in g3.get("rules", []), str(r4))
	d3 = json.loads((p3 / "fabrica" / "diseno.json").read_text())
	val3, _ = cadena.validar_con_bots(p3, d3, [lv["map"] for lv in g3["levels"]], 5, {}, {})
	check("plataformas: con la regla viva, los bots siguen ganando", bool(val3.get("ok")), str(val3.get("fallos_qa"))[:200])
	## Generos de escena sin mandos propios: la regla solo cambia la velocidad (aqui, la serpiente).
	tmp4 = Path(tempfile.mkdtemp())
	inf4 = cadena.fabricar(argparse.Namespace(idea="una serpiente que come fresas en un huerto", salida=str(tmp4), simulado=True,
		arte_simulado=True, comfy="", crear="", editar="", lado=512, semilla=7, apk=False, capturas=False))
	p4 = Path(inf4["proyecto"])
	r5 = agente_mods.programar(p4, "camara lenta al perder una vida (regla)", True, llm.Gasto())
	g4 = json.loads((p4 / "game.json").read_text())
	check("serpiente: la regla de velocidad se engancha como regla", r5.get("tipo") == "regla" and "res://mods/camara_lenta.gd" in g4.get("rules", []), str(r5))
	d4 = json.loads((p4 / "fabrica" / "diseno.json").read_text())
	val4, _ = cadena.validar_con_bots(p4, d4, [lv["map"] for lv in g4["levels"]], 5, {}, {})
	check("serpiente: con la regla, los bots siguen ganando", bool(val4.get("ok")), str(val4.get("fallos_qa"))[:200])
	shutil.rmtree(tmp2, ignore_errors=True)
	shutil.rmtree(tmp, ignore_errors=True)
	print(f"== {len(fallos)} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

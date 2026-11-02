"""Giros y mezclas: que se pongan bien, que los bots los prueben y que la fabrica aprenda de sus
errores (si un giro rompe un juego se quita, se rehace sin el y se apunta la leccion).

	python -m pruebas.prueba_giros
	python -m pruebas.prueba_giros rapido     (sin Godot)
"""

import argparse
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

DATOS = tempfile.mkdtemp(prefix="orq_giros_")
os.environ["ORQ_DATOS"] = DATOS

import giros  # noqa: E402
from director import cambios, director, simulado  # noqa: E402
from niveles import generador  # noqa: E402

SALIDA = Path(__file__).resolve().parent.parent.parent / "proyectos_prueba_giros"


def main() -> int:
	fallos = 0

	def check(nombre: str, ok: bool, detalle: str = "") -> None:
		nonlocal fallos
		print(("  OK   " if ok else "  FALLO ") + nombre + (f"  ({detalle})" if detalle and not ok else ""))
		fallos += 0 if ok else 1

	print("== Unidades ==")
	check("cola solo en laberinto, racha en todos", giros.compatibles("laberinto").count("cola") == 1 and "cola" not in giros.compatibles("golf")
		and "racha" in giros.compatibles("fusion"))
	d = {"genero": "plataformas", "giros": ["oscuridad", "cola", "espejo", "racha"]}
	check("limpiar: fuera lo incompatible y como mucho 2", giros.limpiar(dict(d))["giros"] == ["oscuridad", "espejo"])
	idea, gancho = giros.separar("[gancho:laberinto:cola,monstruos] un gato en una piramide")
	check("gancho: genero y giros validos (monstruos no es de laberinto)", gancho == {"genero": "laberinto", "giros": ["cola"]} and idea == "un gato en una piramide")
	check("gancho: genero inventado no vale", giros.separar("[gancho:hacker:cola] algo raro aqui")[1] is None)
	check("directora sin IA: entiende 'a oscuras'", giros.de_la_idea("un gato a oscuras con linterna", "plataformas") == ["oscuridad"])
	dd, _ = director.disenar("[gancho:golf:monstruos] un minigolf en un castillo encantado", True, None)
	check("gancho en la fabrica: golf con monstruos", dd["genero"] == "golf" and dd.get("giros") == ["monstruos"])
	g = director.a_game(dd, director.generar_niveles(dd, 3))
	check("game.json lleva los giros y monstruos en el campo", g.get("twists") == ["monstruos"] and any("M" in "".join(lv["map"]) for lv in g["levels"]))
	dl, _ = director.disenar("[gancho:laberinto:cola] un laberinto de serpiente en una piramide", True, None)
	gl = director.a_game(dl, director.generar_niveles(dl, 3))
	check("laberinto serpiente: niveles con cola y con camino", all(lv.get("cola") for lv in gl["levels"])
		and all(generador.analizar_laberinto(lv["map"], cola=True) for lv in gl["levels"]))
	## El taller: poner y quitar giros.
	base = director.normalizar(simulado.disenar("un laberinto con llaves y puertas"))
	mapas = director.generar_niveles(base, 3)
	op = {"op": "giros", "giros": ["contrarreloj", "oscuridad"]}
	plan = {"resumen": "Pongo giros", "operaciones": [op]}
	check("taller: giros validos", not cambios.validar_plan(plan, base) and cambios.coste(plan) == cambios.PRECIOS["base"] + cambios.PRECIOS["giros"])
	d2, ef = cambios.aplicar_diseno(base, mapas, plan)
	check("taller: giros que no tocan niveles no los rehacen", d2["giros"] == ["contrarreloj", "oscuridad"] and not ef["niveles"])
	d3, ef3 = cambios.aplicar_diseno(base, mapas, {"resumen": "Mezcla", "operaciones": [{"op": "giros", "giros": ["cola"]}]})
	check("taller: una mezcla rehace los niveles", ef3["niveles"] == set(range(len(base["niveles"]))))
	check("taller: giro de otro genero no vale", bool(cambios.validar_plan({"resumen": "Pongo giros", "operaciones": [{"op": "giros", "giros": ["monstruos"]}]}, base)))
	## Aprender: 5 fallos seguidos en un genero lo dejan de ofrecer alli (y solo alli).
	for _ in range(5):
		giros.anotar("golf", ["espejo"], False, "prueba: los bots no lo superan")
	check("aprende: espejo deja de ofrecerse en golf", "espejo" not in giros.fiables("golf") and "espejo" in giros.fiables("laberinto"))
	check("aprende: la leccion llega a la directora", "golf con espejo" in giros.guia("golf"))
	for _ in range(15):
		giros.anotar("golf", ["espejo"], True)
	check("aprende: si vuelve a ir bien, se vuelve a ofrecer", "espejo" in giros.fiables("golf"))

	if len(sys.argv) > 1 and sys.argv[1] == "rapido":
		print(f"== {fallos} fallos ==")
		return 1 if fallos else 0

	print("== Cadena entera (Godot y bots) ==")
	import cadena

	def fabricar(idea: str, semilla: int = 5) -> tuple[dict, dict]:
		shutil.rmtree(SALIDA, ignore_errors=True)
		inf = cadena.fabricar(argparse.Namespace(idea=idea, salida=str(SALIDA), simulado=True, arte_simulado=True, comfy="", crear="",
			editar="", lado=512, semilla=semilla, apk=False, capturas=False))
		game = json.loads((Path(inf["proyecto"]) / "game.json").read_text(encoding="utf-8"))
		return inf, game

	inf, game = fabricar("[gancho:laberinto:cola,contrarreloj] un laberinto de serpiente en una piramide")
	check("laberinto serpiente + contrarreloj: superado por los bots", inf["ok"] and game.get("twists") == ["cola", "contrarreloj"])
	check("contrarreloj: tiempo por nivel sacado de los bots", all(float(lv.get("time_limit", 0)) >= 10.0 for lv in game["levels"]),
		str([lv.get("time_limit") for lv in game["levels"]]))
	inf, game = fabricar("[gancho:golf:monstruos] un minigolf en un castillo encantado")
	check("golf de monstruos: superado por los bots", inf["ok"] and game.get("twists") == ["monstruos"])
	for genero, giro, idea in (("golf", "viento", "un minigolf en un acantilado con mucho viento"),
			("pesca", "tormenta", "pescar en alta mar durante una tormenta"), ("fusion", "piedras", "fusionar gemas entre piedras"),
			("cajas", "hielo", "empujar bloques de hielo en una cueva helada"),
			("serpiente", "tuneles", "una serpiente que cruza tuneles de un lado a otro"),
			("memoria", "barajar", "un memoria de cartas traviesas que se cambian de sitio"),
			("topos", "dorado", "aplasta topos en una mina de oro"),
			("ritmo", "invisibles", "un juego de ritmo con notas invisibles que se tocan de memoria"),
			("imperio", "niebla", "un imperio medieval tipo age of empires con niebla de guerra")):
		inf, game = fabricar(f"[gancho:{genero}:{giro}] {idea}")
		extra = {"viento": lambda lv: "wind" in lv, "tormenta": lambda lv: "storm" in lv,
			"piedras": lambda lv: any("#" in f for f in lv["map"]), "hielo": lambda lv: lv.get("ice") is True,
			"barajar": lambda lv: lv.get("shuffle") is True,
			"dorado": lambda lv: lv.get("golden") is True,
			"invisibles": lambda lv: lv.get("hidden") is True,
			"niebla": lambda lv: lv.get("fog") is True,
			"tuneles": lambda lv: lv.get("wrap") is True and any(f[0] != "#" for f in lv["map"])}[giro]
		check(f"{genero} con {giro}: superado por los bots y con el giro en los niveles", inf["ok"] and game.get("twists") == [giro]
			and all(extra(lv) for lv in game["levels"]))
	## Supervivencia con estilos de juegos de movil: apocalipsis zombi en invierno.
	inf, game = fabricar("[gancho:supervivencia:apocalipsis,invierno] sobrevivir al invierno en un pueblo lleno de zombis")
	check("supervivencia apocalipsis + invierno: superado por los bots, con zombis, casas y frio en los niveles", inf["ok"]
		and game.get("twists") == ["apocalipsis", "invierno"]
		and all((lv.get("survival") or {}).get("preset") == ["zombis", "invierno"] and any("Z" in f for f in lv["map"]) and any("H" in f for f in lv["map"])
			for lv in game["levels"]), str([lv.get("survival") for lv in game["levels"]][:2]))
	## RPG de equipo: cuatro heroes con habilidades contra oleadas (modo equipo del kit).
	inf, game = fabricar("[gancho:rpg:equipo] un rpg por turnos con un equipo de cuatro heroes")
	check("rpg equipo: superado por los bots y en modo equipo en todos los niveles", inf["ok"] and game.get("twists") == ["equipo"]
		and all((lv.get("rpg") or {}).get("preset") == ["equipo"] and int(lv.get("hero_level", 0)) >= 1 for lv in game["levels"]),
		str([lv.get("rpg") for lv in game["levels"]][:2]))
	## Hordas con estilo de los mas jugados: tipo Survivor.io en todos los niveles.
	inf, game = fabricar("[gancho:horda:survivor] un ninja contra hordas de robots")
	check("hordas survivor: superado por los bots y con el estilo en todos los niveles", inf["ok"] and game.get("twists") == ["survivor"]
		and all((lv.get("horde") or {}).get("preset") == ["survivor"] for lv in game["levels"]))
	## Contenido inventado por la IA (simulado): una tripulacion pirata en el RPG. Y uno imposible:
	## la fabrica lo quita, apunta la leccion y entrega el juego con el estilo probado.
	import contenido
	original = simulado.disenar
	piratas = {"heroes": {"capitan": {"name": "Capitana Brea", "hp": 170, "atk": 18, "def": 35, "spd": 95, "element": "water", "look": "sword", "skills": ["golpe", "provocar"]},
		"artillera": {"name": "Polvora", "hp": 100, "atk": 24, "def": 10, "spd": 108, "element": "fire", "look": "staff", "skills": ["chispa", "andanada"]},
		"cocinero": {"name": "Cucharon", "hp": 120, "atk": 14, "def": 18, "spd": 112, "element": "nature", "look": "cross", "skills": ["luz", "curar"]}},
		"skills": {"andanada": {"name": "Andanada", "target": "all_enemies", "power": 0.75, "cooldown": 3}},
		"enemies": {"W": {"name": "cangrejo", "hp": 75, "atk": 14, "def": 12, "spd": 90, "element": "water", "skills": ["mordisco"]}}}
	imposible = {"heroes": {"grumete": {"name": "Grumete", "hp": 60, "atk": 4, "def": 0, "spd": 60, "skills": ["golpe"]}}, "party": ["grumete"],
		"enemies": {k: {"name": "monstruo", "hp": 700, "atk": 40, "def": 70, "spd": 170, "skills": ["mordisco"]} for k in "WSFMBNL"}}
	simulado.disenar = lambda idea: {**original(idea), "contenido": piratas if "piratas" in idea else imposible}
	try:
		inf, game = fabricar("[gancho:rpg:] un rpg por turnos de piratas en alta mar")
		check("contenido propio: una tripulacion pirata inventada, superada por los bots", inf["ok"]
			and all((lv.get("rpg") or {}).get("party") == ["capitan", "artillera", "cocinero"] for lv in game["levels"]))
		inf, game = fabricar("[gancho:rpg:] un rpg por turnos de un grumete contra monstruos")
		check("contenido imposible: se quita y el juego sale igual (con el estilo probado)", inf["ok"]
			and not any((lv.get("rpg") or {}).get("party") == ["grumete"] for lv in game["levels"]))
		check("contenido imposible: la leccion queda apuntada", any(x.get("giros") == [contenido.CLAVE] for x in giros.lecciones("rpg", 20)))
	finally:
		simulado.disenar = original
	inf, game = fabricar("[gancho:runner:fantasma] un zorro que corre contra su propio fantasma (runner)")
	check("runner con fantasma: superado por los bots", inf["ok"] and game.get("twists") == ["fantasma"]
		and "fantasma" not in game.get("daily_twists", []))
	inf, game = fabricar("un gato ninja que salta por tejados a oscuras y en un mundo espejo")
	check("plataformas a oscuras y espejo: superado por los bots", inf["ok"] and game.get("twists") == ["oscuridad", "espejo"])
	## Error a proposito: el generador hace niveles de laberinto serpiente imposibles. La fabrica
	## tiene que quitar el giro, entregar el juego sin el y apuntar la leccion.
	original = generador._laberinto_cola
	original_an = generador.analizar_laberinto

	def imposible(g, salida, i, dif, rnd):
		filas = original(g, salida, i, dif, rnd)
		if not filas:
			return None
		filas = [list(f) for f in filas]
		## Monedas en dos callejones distintos: sin volver atras no se pueden coger las dos.
		huecos = [(y, x) for y in range(1, len(filas) - 1) for x in range(1, len(filas[0]) - 1) if filas[y][x] in ".XC"
			and sum(filas[y + dy][x + dx] != "#" for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1))) == 1]
		if len(huecos) < 3:
			return None
		for y, x in huecos:
			filas[y][x] = "C"
		return ["".join(f) for f in filas]

	generador._laberinto_cola = imposible
	generador.analizar_laberinto = lambda filas, cola=False: original_an(filas)
	try:
		inf, game = fabricar("[gancho:laberinto:cola] un laberinto de serpiente imposible", semilla=9)
	finally:
		generador._laberinto_cola = original
		generador.analizar_laberinto = original_an
	ls = giros.lecciones("laberinto")
	check("error a proposito: se entrega el juego sin el giro", inf["ok"] and "twists" not in game and not any(lv.get("cola") for lv in game["levels"]))
	check("error a proposito: queda la leccion para la directora", any("cola" in x["giros"] for x in ls), str(ls))
	shutil.rmtree(SALIDA, ignore_errors=True)
	shutil.rmtree(DATOS, ignore_errors=True)
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

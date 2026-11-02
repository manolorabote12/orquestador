"""Prueba del taller por instrucciones: un juego, varias instrucciones seguidas y volver atras.

python -m pruebas.prueba_taller
"""

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

import cadena
import cambio
import versiones
from director import cambios, director, llm

SALIDA = Path(__file__).resolve().parent.parent.parent / "proyectos_prueba_taller"


def md5(p: Path) -> str:
	return hashlib.md5(p.read_bytes()).hexdigest()


def main() -> int:
	fallos: list[str] = []

	def check(nombre: str, ok: bool, detalle: str = "") -> None:
		print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
		if not ok:
			fallos.append(nombre)

	shutil.rmtree(SALIDA, ignore_errors=True)
	inf = cadena.fabricar(argparse.Namespace(idea="un gato ninja rápido que salta por tejados de noche", salida=str(SALIDA),
		simulado=True, arte_simulado=True, comfy="", crear="", editar="", lado=512, semilla=5, apk=False, capturas=False))
	P = Path(inf["proyecto"])
	check("version 1 anotada con su instantanea", versiones.memoria(P)["version"] == 1 and (P / "fabrica/versiones/v1/game.json").exists())

	def aplicar(instr: str) -> dict:
		return cambio.cambiar(argparse.Namespace(proyecto=str(P), instruccion=instr, plan="", solo_plan=False, simulado=True,
			arte_simulado=True, comfy="", crear="", editar="", lado=512, semilla=5, slug="", apk=False, capturas=False))

	def leer(rel: str) -> dict:
		return json.loads((P / rel).read_text(encoding="utf-8"))

	print("== Instrucciones ==")
	moneda_antes, tile_antes, heroe_antes = md5(P / "assets/moneda/spin.png"), md5(P / "assets/tiles/suelo.png"), md5(P / "assets/heroe/run.png")
	mapas_antes = [lv["map"] for lv in leer("game.json")["levels"]]
	r = aplicar("haz al gato negro")
	check("redibujar: cambia el heroe", md5(P / "assets/heroe/run.png") != heroe_antes)
	check("redibujar: NO toca moneda, suelo ni niveles", md5(P / "assets/moneda/spin.png") == moneda_antes and md5(P / "assets/tiles/suelo.png") == tile_antes
		and [lv["map"] for lv in leer("game.json")["levels"]] == mapas_antes)
	check("redibujar: conserva el resto de la descripcion", "green eyes" in leer("fabrica/diseno.json")["heroe"]["descripcion"] and "black" in leer("fabrica/diseno.json")["heroe"]["descripcion"])
	check("coste calculado por codigo", r["plan"]["coste"] == cambios.PRECIOS["base"] + cambios.PRECIOS["redibujar"], str(r["plan"]["coste"]))

	heroe_v2 = md5(P / "assets/heroe/run.png")
	aplicar('llámalo "Sombra Felina"')
	g = leer("game.json")
	check("textos: titulo nuevo en el juego y en la app", g["title"] == "Sombra Felina" and 'config/name="Sombra Felina"' in (P / "project.godot").read_text(encoding="utf-8"))
	check("textos: no redibuja nada", md5(P / "assets/heroe/run.png") == heroe_v2)

	n_antes = len(g["levels"])
	r = aplicar("añade un nivel de nieve después del 1")
	g = leer("game.json")
	check("anadir_nivel: uno mas, en su sitio", len(g["levels"]) == n_antes + 1 and g["levels"][1]["name"] == "Nivel de nieve", str([l["name"] for l in g["levels"]]))
	check("anadir_nivel: solo se genera ese", r["niveles_rehechos"] == [1], str(r["niveles_rehechos"]))

	aplicar("ponle 5 vidas y los voladores más lentos")
	g = leer("game.json")
	check("ajustes: vidas y velocidad", g["player"]["hp"] == 5.0 and g["enemies"]["flyer"]["speed"] < 110.0, str((g["player"]["hp"], g["enemies"]["flyer"])))

	print("== Jefe, disparo, musica y extras ==")
	P_ = cambios.PRECIOS
	check("el juego nace con jefe en el ultimo nivel", "B" in "".join(leer("game.json")["levels"][-1]["map"]) and (P / "assets/jefe").exists())
	r = aplicar("quita el jefe final")
	g = leer("game.json")
	check("jefe quitar: sin B, sin sprite y precio de quitar", r["aplicado"] and not any("B" in "".join(lv["map"]) for lv in g["levels"])
		and not (P / "assets/jefe").exists() and r["plan"]["coste"] == P_["base"] + P_["jefe_quitar"], str(r["plan"]["coste"]))
	musica_antes = md5(P / "assets/musica/nivel.wav")
	heroe_v6 = md5(P / "assets/heroe/run.png")
	r = aplicar("pon un jefe final")
	g = leer("game.json")
	check("jefe poner: B en el ultimo nivel, sprite y nombre", "B" in "".join(g["levels"][-1]["map"]) and (P / "assets/jefe").exists()
		and g["enemies"].get("boss") is not None and r["plan"]["coste"] == P_["base"] + P_["jefe"], str(r["plan"]["coste"]))
	check("jefe poner: no redibuja al heroe", md5(P / "assets/heroe/run.png") == heroe_v6)
	r = aplicar("que dispare bolas de fuego")
	g = leer("game.json")
	check("disparo: el heroe dispara", float(g["player"].get("shoot", 0.0)) > 0.5 and r["plan"]["coste"] == P_["base"] + P_["disparo"])
	r = aplicar("que dispare")
	check("disparo repetido: no cobra (ya esta asi)", not r["aplicado"] and r["plan"]["coste"] == 0, str(r["plan"].get("resumen")))
	r = aplicar("música más épica y rápida")
	check("musica: pistas nuevas y nada mas redibujado", md5(P / "assets/musica/nivel.wav") != musica_antes
		and md5(P / "assets/heroe/run.png") == heroe_v6 and r["plan"]["coste"] == P_["base"] + P_["musica"])
	r = aplicar("quita las plataformas móviles")
	g = leer("game.json")
	check("extras: sin plataformas moviles", r["aplicado"] and not any("=" in "".join(lv["map"]) for lv in g["levels"]))
	r = aplicar("hazlo multijugador online")
	check("lo que no sabe hacer: lo dice y no cobra", not r["aplicado"] and r["plan"]["coste"] == 0 and r["plan"].get("no_puedo"))

	export = (P / "export_presets.cfg").read_text(encoding="utf-8")
	mem = versiones.memoria(P)
	check("memoria con todas las instrucciones", [h["version"] for h in mem["historial"]] == list(range(1, 11)), str([h["instruccion"] for h in mem["historial"]]))
	check("codigo de version del APK sube; el paquete no cambia", "version/code=10" in export and 'package/unique_name="com.orquestador.bigotesveloces"' in export)
	check("el preset Web conserva su ruta", 'export_path="build/web/index.html"' in export)

	print("== Volver atras ==")
	cambio.volver(argparse.Namespace(proyecto=str(P), volver=2, simulado=True, arte_simulado=True, comfy="", crear="", editar="", lado=512,
		semilla=5, slug="", apk=False, capturas=False))
	g = leer("game.json")
	check("vuelve a la v2: titulo, niveles y gato negro", g["title"] == "Bigotes Veloces" and len(g["levels"]) == n_antes and md5(P / "assets/heroe/run.png") == heroe_v2)
	check("volver queda como version nueva (nada se pierde)", versiones.memoria(P)["version"] == 11 and (P / "fabrica/versiones/v10").exists())
	check("volver a la v2 recupera el jefe original", "B" in "".join(g["levels"][-1]["map"]) and (P / "assets/jefe").exists())

	print("== Validacion de planes ==")
	d = leer("fabrica/diseno.json")
	malo = {"resumen": "Cambio de prueba", "operaciones": [{"op": "textos", "titulo": "Mario Gato"}]}
	check("rechaza contenido protegido", bool(cambios.validar_plan(malo, d)))
	malo = {"resumen": "Cambio de prueba", "operaciones": [{"op": "rehacer_nivel", "indice": 40}]}
	check("rechaza niveles inexistentes", bool(cambios.validar_plan(malo, d)))
	try:
		cambios.planificar("x" * 500, d, [], True, llm.Gasto())
		check("rechaza instrucciones demasiado largas", False)
	except llm.ErrorIA:
		check("rechaza instrucciones demasiado largas", True)
	print("== Cambiar de genero ==")
	r = aplicar("conviértelo en runner")
	g = leer("game.json")
	mapas = "".join("".join(lv["map"]) for lv in g["levels"])
	check("runner: corre solo, sin jefe ni plataformas moviles", r["aplicado"] and g["player"].get("auto_run") == 1.0
		and "B" not in mapas and "=" not in mapas and not (P / "assets/jefe").exists(), str(r["plan"]["resumen"]))
	check("runner: precio de genero y bots superan los niveles", r["plan"]["coste"] == cambios.PRECIOS["base"] + cambios.PRECIOS["genero"]
		and all(n.get("bot_completa") for n in r["validacion"]["niveles"]))
	r = aplicar("pon un jefe final")
	check("runner: el jefe no se puede, lo dice y no cobra", not r["aplicado"] and r["plan"]["coste"] == 0 and r["plan"].get("no_puedo"))
	r = aplicar("que vuele de un toque")
	g = leer("game.json")
	mapas = "".join("".join(lv["map"]) for lv in g["levels"])
	check("volador: aletea, sin enemigos en los niveles y los bots pasan", r["aplicado"] and g["player"].get("flap") == 1.0
		and not any(c in mapas for c in "EKF") and all(n.get("bot_completa") for n in r["validacion"]["niveles"]), str(r["plan"]["resumen"]))
	r = aplicar("que dispare")
	check("volador: disparar no se puede, lo dice y no cobra", not r["aplicado"] and r["plan"]["coste"] == 0 and r["plan"].get("no_puedo"))
	r = aplicar("conviértelo en hordas")
	g = leer("game.json")
	check("horda: arenas validadas por los bots y precio de genero", r["aplicado"] and g["genre"] == "horde"
		and all(n.get("bot_completa") for n in r["validacion"]["niveles"]) and r["plan"]["coste"] == cambios.PRECIOS["base"] + cambios.PRECIOS["genero"])
	r = aplicar("pon poderes de estrella")
	check("horda: poderes no, lo dice y no cobra", not r["aplicado"] and r["plan"]["coste"] == 0 and r["plan"].get("no_puedo"))
	r = aplicar("conviértelo en un puzle de combinar")
	g = leer("game.json")
	check("puzle: tableros validados por el bot", r["aplicado"] and g["genre"] == "match3" and all(n.get("bot_completa") for n in r["validacion"]["niveles"]))
	r = aplicar("pon un jefe final")
	check("puzle: jefe no, lo dice y no cobra", not r["aplicado"] and r["plan"]["coste"] == 0 and r["plan"].get("no_puedo"))
	r = aplicar("conviértelo en tower defense")
	g = leer("game.json")
	check("torres: caminos validados por el bot y precio de genero", r["aplicado"] and g["genre"] == "tower"
		and all(n.get("bot_completa") for n in r["validacion"]["niveles"]) and r["plan"]["coste"] == cambios.PRECIOS["base"] + cambios.PRECIOS["genero"])
	r = aplicar("hazlo de carreras de coches")
	g = leer("game.json")
	check("carreras: pistas validadas por el bot", r["aplicado"] and g["genre"] == "race" and all(n.get("bot_completa") for n in r["validacion"]["niveles"]))
	r = aplicar("pon un jefe final")
	check("carreras: jefe no, lo dice y no cobra", not r["aplicado"] and r["plan"]["coste"] == 0 and r["plan"].get("no_puedo"))
	r = aplicar("pásalo a plataformas")
	g = leer("game.json")
	check("vuelta a plataformas: ya no corre solo", r["aplicado"] and "auto_run" not in g["player"])
	check("vuelta a plataformas: vuelve a 2D (la vista 3D era de las carreras)", g.get("view") == "2d")
	mapas_antes = json.dumps(g["levels"])
	r = aplicar("ponlo en 3D")
	g = leer("game.json")
	check("plataformas 3D: vista 3D al precio de vista, mismos niveles", r["aplicado"] and g.get("view") == "3d"
		and r["plan"]["coste"] == cambios.PRECIOS["base"] + cambios.PRECIOS["vista"] and json.dumps(g["levels"]) == mapas_antes)
	r = aplicar("ponlo en 3D")
	check("plataformas 3D: pedirlo otra vez no cobra", not r["aplicado"] and r["plan"]["coste"] == 0)
	r = aplicar("vuelve a 2D")
	check("plataformas 3D: vuelta a 2D", r["aplicado"] and leer("game.json").get("view") == "2d")
	g = leer("game.json")
	check("historia: el juego nace con dialogos entre niveles", bool(g.get("story")) and len(g["story"]["levels"]) == len(g["levels"])
		and g["story"]["levels"][0]["intro"], str(g.get("story"))[:200])
	r = aplicar("quita la historia")
	check("historia: se puede quitar", r["aplicado"] and "story" not in leer("game.json"))
	r = aplicar("quita los diálogos")
	check("historia: quitarla otra vez no cobra", not r["aplicado"] and r["plan"]["coste"] == 0)
	r = aplicar("ponle una historia con diálogos")
	g = leer("game.json")
	check("historia: vuelve con su precio y voces pedidas", r["aplicado"] and bool(g.get("story"))
		and r["plan"]["coste"] == cambios.PRECIOS["base"] + cambios.PRECIOS["historia"])
	n0 = len(g["levels"])
	r = aplicar("añade un nivel que se llame Torre del reloj")
	g = leer("game.json")
	check("historia: un nivel nuevo tiene su hueco en la historia", r["aplicado"] and len(g["story"]["levels"]) == len(g["levels"]) == n0 + 1)
	r = aplicar("conviértelo en un trivial de preguntas sobre animales")
	g = leer("game.json")
	check("preguntas: convertido con sus preguntas y validado por el bot", r["aplicado"] and g["genre"] == "quiz"
		and all(lv.get("questions") for lv in g["levels"]) and all(n.get("bot_completa") for n in r["validacion"]["niveles"]), str(r.get("plan", {}).get("operaciones")))
	r = aplicar("cambia las preguntas por otras del espacio")
	g = leer("game.json")
	check("preguntas: se cambian las preguntas", r["aplicado"] and "planeta" in json.dumps(g["levels"], ensure_ascii=False).lower())
	r = aplicar("pásalo a plataformas")
	check("preguntas: vuelta a plataformas", r["aplicado"] and leer("game.json")["genre"] == "platformer")
	check("vista 3D: no existe en hordas", "solo existe en" in cambios.regla_genero("horda", {"op": "vista", "vista": "3d"})
		and cambios.regla_genero("volador", {"op": "vista", "vista": "3d"}) == "")
	print(f"== {len(fallos)} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

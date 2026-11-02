"""Plantillas por datos: la copia en Python del RPG de equipo (niveles/rpg_equipo.py) da lo mismo
que el kit y los generadores de estilos hacen niveles justos.

	python -m pruebas.prueba_plantillas
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from niveles import generador, rpg_equipo  # noqa: E402


def main() -> int:
	fallos = 0

	def check(nombre: str, ok: bool, detalle: str = "") -> None:
		nonlocal fallos
		print(("  OK   " if ok else "  FALLO ") + nombre + ("" if ok else f"  ({detalle})"))
		if not ok:
			fallos += 1

	## Los mismos numeros que el kit (qa/test_runner.gd: _test_turns_party).
	r = rpg_equipo.simular({"map": ["W", "WW", "WF"], "rpg": {}, "mult": 1.0, "potions": 2, "hero_level": 1})
	import plantillas as _pl
	_malas = {k: p.get("categoria") for k, p in _pl.PLANTILLAS.items() if p.get("categoria", "accion") not in ("accion", "puzle", "estrategia", "relax", "ninos", "aula", "unicas")}
	check("plantillas: categorias que la app conoce (si no, no compila)", not _malas, str(_malas))
	check("rpg equipo: la copia en Python da lo mismo que el kit (20 turnos, 89,7 %)", r["won"] and r["turns"] == 20
		and abs(r["hp_left"] - 0.8970484) < 0.0001, str(r))
	cat = rpg_equipo.catalogo({"rpg": {"preset": ["criaturas"]}})
	check("rpg criaturas: el estilo trae tres criaturas y uno contra uno", len(cat["party"]) == 3 and cat["lineup"] is True)
	for estilo in ("equipo", "criaturas"):
		malos = []
		for dif in ("facil", "normal", "dificil"):
			for i in range(8):
				olas = generador.generar_rpg(i, 8, [], dif, 77 + i * 1009, 0.0, {"estilos_rpg": [estilo]})
				p = generador.parametros_rpg(i, 8, dif, 0.0, [estilo])
				lv = {**p, "map": olas}
				a = rpg_equipo.simular(lv)
				b = rpg_equipo.simular(lv, True)
				if not (a["won"] and b["won"] and a["hp_left"] >= 0.25):
					malos.append(f"{dif}/{i} {olas}")
		check(f"rpg {estilo}: 24 niveles generados, todos justos", not malos, "; ".join(malos[:3]))
	p = generador.parametros_rpg(2, 8, "normal", 0.0, ["equipo"])
	check("rpg equipo: los parametros llevan el estilo y el nivel del equipo", p["rpg"] == {"preset": ["equipo"]} and p["hero_level"] == 3)
	check("rpg sin estilo: los niveles de siempre (sin modo equipo)", "rpg" not in generador.parametros_rpg(2, 8, "normal"))
	## Supervivencia: los estilos ponen sus letras.
	m = generador.generar_supervivencia(3, 8, [], "normal", 5, 0.0, {"estilos_superv": ["apocalipsis"]})
	check("supervivencia apocalipsis: guaridas de zombis, casas y coches", any("Z" in f for f in m) and any("H" in f for f in m) and any("C" in f for f in m))
	ps = generador.parametros_supervivencia(2, 8, "normal", m, 0.0, ["apocalipsis", "invierno"])
	check("supervivencia: estilos en el nivel y meta de la radio", ps["survival"] == {"preset": ["zombis", "invierno"]} and ps["goal"] == "receta")

	## Contenido inventado por la IA: se valida, va a los niveles y el generador juega con el.
	import contenido
	from director import director, simulado
	piratas = {"heroes": {"capitan": {"name": "Capitana Brea", "hp": 170, "atk": 18, "def": 35, "spd": 95, "element": "water", "look": "sword", "skills": ["sable", "grito"]},
		"artillera": {"name": "Polvora", "hp": 100, "atk": 24, "def": 10, "spd": 108, "element": "fire", "look": "staff", "skills": ["pistola", "andanada"]},
		"cocinero": {"name": "Cucharon", "hp": 120, "atk": 14, "def": 18, "spd": 112, "element": "nature", "look": "cross", "skills": ["cucharazo", "guiso"]}},
		"skills": {"sable": {"name": "Sablazo", "target": "enemy", "power": 1.0}, "grito": {"name": "Al abordaje", "target": "self", "effects": [{"status": "taunt", "turns": 2}, {"status": "def_up", "turns": 2}], "cooldown": 3},
			"pistola": {"name": "Pistoletazo", "target": "enemy", "power": 1.0}, "andanada": {"name": "Andanada", "target": "all_enemies", "power": 0.75, "cooldown": 3},
			"cucharazo": {"name": "Cucharazo", "target": "enemy", "power": 0.9}, "guiso": {"name": "Guiso caliente", "target": "all_allies", "heal": 0.25, "cooldown": 3}},
		"enemies": {"W": {"name": "cangrejo", "hp": 75, "atk": 14, "def": 12, "spd": 90, "element": "water", "skills": ["mordisco"]},
			"B": {"name": "kraken", "hp": 440, "atk": 21, "def": 25, "spd": 100, "element": "dark", "skills": ["zarpazo", "rugido", "aplastar"]}}}
	limpio, err = contenido.validar("rpg", piratas)
	check("contenido rpg: una tripulacion pirata inventada pasa el control", not err and limpio["party"] == ["capitan", "artillera", "cocinero"], str(err))
	malo = {"heroes": {"xx": {"name": "X", "hp": 5000, "atk": 1, "skills": ["nada"]}}, "enemies": {"Q": {}}}
	_, err2 = contenido.validar("rpg", malo)
	check("contenido rpg: vida fuera de margen, habilidad que no existe y letra rara se rechazan",
		any("hp" in e for e in err2) and any("'nada' no existe" in e for e in err2) and any("enemies/Q" in e for e in err2), str(err2))
	_, err3 = contenido.validar("rpg", {"heroes": {"mudo": {"name": "Mudo", "hp": 100, "atk": 10, "skills": ["curar"]}}, "party": ["mudo"]})
	check("contenido rpg: sin ataque basico no vale", any("ataque basico" in e for e in err3), str(err3))
	isla = {"items": {"cristal": {"name": "cristal"}, "fruto": {"name": "fruto luminoso", "food": 26}},
		"tiles": {"R": {"item": "cristal", "yield": 3, "time": 1.2, "tool": "hacha", "tint": "#7fd8ff"}, "B": {"item": "fruto", "yield": 3, "time": 0.4, "regrow": 25}},
		"recipes": {"hacha": {"name": "Pico", "cost": {"wood": 3, "cristal": 2, "fiber": 2}, "tool": {"gather": 0.5}},
			"hoguera": {"name": "Fogata", "cost": {"wood": 4, "cristal": 3}, "fire": True}},
		"creatures": {"sombra": {"name": "sombras", "hp": 50, "dmg": 10, "speed": 3, "when": "night", "hostile": True, "fear_fire": True, "look": "beast", "color": "#5b3a8a"}},
		"tiles_extra": 1}
	isla.pop("tiles_extra")
	isla["tiles"]["D"] = {"den": "sombra"}
	lsv, esv = contenido.validar("supervivencia", isla)
	check("contenido supervivencia: planeta con cristales, frutos y sombras pasa el control", not esv and lsv["names"]["fruto"] == "fruto luminoso", str(esv))
	_, esv2 = contenido.validar("supervivencia", {"recipes": {"radio": {"cost": {"oro": 3}, "win": True, "fire": True}}})
	check("contenido supervivencia: objeto que no existe y receta que da dos cosas se rechazan",
		any("'oro'" in e for e in esv2) and any("una sola cosa" in e for e in esv2), str(esv2))
	d = simulado.disenar("un rpg por turnos de piratas")
	d["genero"] = "rpg"
	d["contenido"] = piratas
	d = director.normalizar(d)
	check("contenido: la directora lo deja limpio en el diseno", d.get("contenido", {}).get("party") == ["capitan", "artillera", "cocinero"])
	mapas = director.generar_niveles(d, 4)
	g = director.a_game(d, mapas)
	lv0 = g["levels"][0]
	check("contenido rpg: cada nivel va en modo equipo con la tripulacion inventada", all((lv.get("rpg") or {}).get("party") == ["capitan", "artillera", "cocinero"]
		for lv in g["levels"]) and lv0["rpg"].get("preset") == ["equipo"], str(lv0.get("rpg", {}))[:120])
	malos = [k for k, lv in enumerate(g["levels"]) if not (rpg_equipo.simular(lv)["won"] and rpg_equipo.simular(lv, True)["won"])]
	check("contenido rpg: el generador hace niveles justos con lo inventado", not malos, str(malos))
	d2 = director.normalizar({**d, "contenido": malo})
	check("contenido invalido: la directora lo quita y sigue con el estilo probado", "contenido" not in d2)
	ds = simulado.disenar("sobrevivir en un planeta alienigena")
	ds["genero"] = "supervivencia"
	ds["contenido"] = isla
	ds = director.normalizar(ds)
	gs = director.a_game(ds, director.generar_niveles(ds, 4))
	check("contenido supervivencia: cada nivel lleva lo inventado", all((lv.get("survival") or {}).get("names", {}).get("fruto") == "fruto luminoso" for lv in gs["levels"]))
	## Hordas: armas inventadas y estilos.
	gato = {"start": "laser", "weapons": {"laser": {"name": "Pistola laser", "desc": "Al mas cercano", "pattern": "shot", "cd": [0.6, 0.55, 0.5, 0.45, 0.4], "count": [1, 1, 2, 2, 3], "dmg": 2.4},
		"satelites": {"name": "Satelites", "pattern": "orbit", "count": [2, 3, 3, 4, 5], "radius": 120, "dmg": [1.6, 2.0, 2.4, 2.8, 3.2]},
		"supernova": {"name": "Supernova", "pattern": "nova", "cd": 1.2, "count": 16, "dmg": 4.0}},
		"passives": {"turbo": {"name": "Turbo", "stat": "speed", "per": 0.12}},
		"evolutions": [{"weapon": "satelites", "passive": "turbo", "into": "supernova"}]}
	lh, eh = contenido.validar("horda", gato)
	check("contenido horda: un gato astronauta con armas inventadas pasa el control", not eh and lh["weapons"]["supernova"].get("evolved") is True, str(eh))
	_, eh2 = contenido.validar("horda", {"weapons": {"cano": {"name": "Cano", "pattern": "misil", "dmg": 99}}, "start": "nada"})
	check("contenido horda: forma de atacar inventada y arma de inicio que no existe se rechazan",
		any("pattern" in e for e in eh2) and any("start" in e for e in eh2), str(eh2))
	dh = simulado.disenar("un gato astronauta contra hordas de aliens")
	dh["genero"] = "horda"
	dh["giros"] = ["survivor"]
	dh["contenido"] = gato
	dh = director.normalizar(dh)
	gh = director.a_game(dh, director.generar_niveles(dh, 4))
	check("contenido horda: cada nivel lleva el estilo y las armas inventadas", all((lv.get("horde") or {}).get("preset") == ["survivor"]
		and (lv.get("horde") or {}).get("start") == "laser" for lv in gh["levels"]), str(gh["levels"][0].get("horde"))[:100])
	## Shooter de zombis: armas inventadas.
	caza = {"weapons": {"ballesta": {"name": "Ballesta", "dmg": 60, "rate": 0.6, "mag": 5, "reload": 1.4, "spread": 0.01, "pellets": 1, "range": 18, "look": "rifle"}},
		"slots": {"start": "ballesta"}, "kinds": {"walker": {"hp": 90}}}
	lz, ez = contenido.validar("zombis", caza)
	check("contenido zombis: una ballesta inventada pasa el control", not ez and lz["slots"]["start"] == "ballesta", str(ez))
	_, ez2 = contenido.validar("zombis", {"weapons": {"canon": {"name": "Canon", "dmg": 999}}, "slots": {"start": "laser"}})
	check("contenido zombis: dano fuera de margen y arma que no existe se rechazan", any("dmg" in e for e in ez2) and any("slots" in e for e in ez2), str(ez2))
	dz = simulado.disenar("cazadores de monstruos en una aldea")
	dz["genero"] = "zombis"
	dz["contenido"] = caza
	dz = director.normalizar(dz)
	gz = director.a_game(dz, director.generar_niveles(dz, 4))
	check("contenido zombis: cada nivel lleva las armas inventadas", all((lv.get("fps") or {}).get("slots", {}).get("start") == "ballesta" for lv in gz["levels"]))
	## Imperio: nombres y numeros inventados (papeles fijos).
	hormigas = {"units": {"aldeano": {"name": "Obrera"}, "lancero": {"name": "Soldado", "hp": 70}, "ariete": {"name": "Reina", "hp": 260}},
		"builds": {"centro": {"name": "Hormiguero"}}, "res_names": {"comida": "azucar", "madera": "hojas", "oro": "miel"}}
	li, ei = contenido.validar("imperio", hormigas)
	check("contenido imperio: un imperio de hormigas pasa el control", not ei and li["units"]["lancero"]["hp"] == 70, str(ei))
	_, ei2 = contenido.validar("imperio", {"units": {"dragon": {"name": "Dragon"}, "lancero": {"hp": 500}}})
	check("contenido imperio: tropa nueva y numeros desequilibrados se rechazan", any("dragon" in e for e in ei2) and any("hp" in e for e in ei2), str(ei2))
	de = simulado.disenar("un imperio de hormigas en un jardin")
	de["genero"] = "imperio"
	de["giros"] = ["fantasia"]
	de["contenido"] = hormigas
	de = director.normalizar(de)
	ge = director.a_game(de, director.generar_niveles(de, 4))
	check("contenido imperio: cada nivel lleva el estilo y lo inventado", all((lv.get("empire") or {}).get("preset") == ["fantasia"]
		and (lv.get("empire") or {}).get("res_names", {}).get("oro") == "miel" for lv in ge["levels"]))
	## Karts: objetos inventados.
	cocina = {"items": {"tomate": {"name": "Tomate", "effect": "seek", "weights": [0.2, 0.4, 0.4]}, "aceite": {"name": "Mancha de aceite", "effect": "trap", "weights": [0.6, 0.3, 0.1]},
		"guindilla": {"name": "Guindilla", "effect": "boost", "dur": 2.0, "weights": [0.1, 0.3, 0.5]}, "cascara": None, "platano": None, "turbo": None}}
	lk, ek = contenido.validar("karts", cocina)
	check("contenido karts: objetos de cocina inventados pasan el control", not ek and lk["items"]["guindilla"]["dur"] == 2.0, str(ek))
	_, ek2 = contenido.validar("karts", {"items": {"misil": {"name": "Misil", "effect": "explota"}}})
	check("contenido karts: un efecto que el kit no sabe hacer se rechaza", any("effect" in e for e in ek2), str(ek2))
	dk = simulado.disenar("karts de cocineros en una cocina gigante")
	dk["genero"] = "karts"
	dk["giros"] = ["fiesta"]
	dk["contenido"] = cocina
	dk = director.normalizar(dk)
	gk = director.a_game(dk, director.generar_niveles(dk, 4))
	check("contenido karts: cada nivel lleva el estilo y los objetos inventados", all((lv.get("kart") or {}).get("preset") == ["fiesta"]
		and "tomate" in (lv.get("kart") or {}).get("items", {}) for lv in gk["levels"]))
	## Juegos de palabras: el nivel solo lleva semilla y medidas (las palabras salen del diccionario
	## del idioma); el traductor no debe confundir "words" (cuantas) con la lista de la sopa.
	from textos import traducir
	from pathlib import Path
	for gen, de in (("palabra", "un wordle de animales"), ("letras", "un wordscapes de viajes")):
		dw = simulado.disenar(de)
		dw["genero"] = gen
		dw = director.normalizar(dw)
		gw = director.a_game(dw, director.generar_niveles(dw, 8))
		lvs = gw["levels"]
		medidas = all(4 <= int(lv["len"]) <= 7 and str(lv["map"][1]).startswith("#") for lv in lvs)
		if gen == "palabra":
			medidas = medidas and all(6 <= int(lv["tries"]) <= 7 for lv in lvs) and lvs[-1]["len"] >= lvs[0]["len"]
		else:
			medidas = medidas and all(3 <= int(lv["words"]) <= 9 for lv in lvs) and lvs[-1]["words"] > lvs[0]["words"]
		check(f"{gen}: niveles con semilla y medidas que crecen", medidas, str([(lv.get("len"), lv.get("words", lv.get("tries"))) for lv in lvs]))
		check(f"{gen}: semillas distintas en cada nivel", len({lv["map"][1] for lv in lvs}) == len(lvs))
		try:
			traducir.fuente(gw)
			ok_tr = True
		except Exception as e:  # noqa: BLE001
			ok_tr = False
		check(f"{gen}: el traductor no se lia con el nivel", ok_tr)
	## Tycoon: la meta de cada nivel sale de la simulacion (el bot llega en un 80 % del par).
	from niveles import tycoon
	for giro in ([], ["mina"]):
		dt = simulado.disenar("un idle tycoon de negocios")
		dt["genero"] = "tycoon"
		dt["giros"] = giro
		dt = director.normalizar(dt)
		gt = director.a_game(dt, director.generar_niveles(dt, 6))
		lvs = gt["levels"]
		ok_meta = all(lv.get("target", 0) > 0 and lv["map"] == ["tycoon"] for lv in lvs)
		tiempos = [tycoon.jugar(lv, lv["par"] * 1.6)["time"] for lv in lvs]
		justos = all(0.6 * lv["par"] <= t <= lv["par"] for lv, t in zip(lvs, tiempos))
		nombre = "mina" if giro else "negocios"
		check(f"tycoon {nombre}: metas calibradas y el bot llega a tiempo", ok_meta and justos, str([(lv["par"], lv["target"], t) for lv, t in zip(lvs, tiempos)]))
		check(f"tycoon {nombre}: los niveles crecen", lvs[-1]["open"] > lvs[0]["open"] and lvs[-1]["target"] > lvs[0]["target"])
		if giro:
			check("tycoon mina: cada nivel lleva el estilo", all((lv.get("tycoon") or {}).get("preset") == ["mina"] for lv in lvs))
	dulces = {"cur": "€", "biz": {"limonada": {"name": "Puesto de churros", "look": "donut"}, "periodicos": {"name": "Cafetería", "look": "coffee", "profit": 70}}}
	lt, et = contenido.validar("tycoon", dulces)
	check("contenido tycoon: negocios del tema pasan el control", not et and lt["biz"]["limonada"]["name"] == "Puesto de churros", str(et))
	_, et2 = contenido.validar("tycoon", {"biz": {"casino": {"name": "Casino"}}, "shafts": {"carbon": {"value": 999}}})
	check("contenido tycoon: ids nuevos y numeros fuera de margen se rechazan", any("casino" in e for e in et2) and any("value" in e for e in et2), str(et2))
	dt2 = simulado.disenar("un idle tycoon de dulces")
	dt2["genero"] = "tycoon"
	dt2["contenido"] = dulces
	dt2 = director.normalizar(dt2)
	gt2 = director.a_game(dt2, director.generar_niveles(dt2, 3))
	check("contenido tycoon: cada nivel lleva los negocios inventados", all((lv.get("tycoon") or {}).get("biz", {}).get("limonada", {}).get("name") == "Puesto de churros" for lv in gt2["levels"]))
	## Tragaperras: escala de la aldea calibrada, nunca infantil y declarada como simulacion de apuestas.
	from niveles import tragaperras
	ds = simulado.disenar("un coin master de piratas")
	ds["genero"] = "tragaperras"
	ds["publico"] = "infantil"
	ds = director.normalizar(ds)
	check("tragaperras: nunca es un juego infantil", ds.get("publico") == "todos")
	gs = director.a_game(ds, director.generar_niveles(ds, 5))
	escalas = [lv.get("scale", 0) for lv in gs["levels"]]
	check("tragaperras: cada nivel con su aldea calibrada", all(0.1 < e < 5.0 for e in escalas) and all(lv["map"] == ["tragaperras"] for lv in gs["levels"]), str(escalas))
	from play import cuestionarios
	gu = cuestionarios.guia(ds, "com.x.y", "a@b.c", "https://x", True, False)
	campos = {k: v for p in gu["pasos"] for k, v in (p.get("campos") or {}).items()}
	check("tragaperras: Play la declara como simulacion de apuestas y para mayores", campos["Apuestas o simulación de apuestas"].startswith("Sí")
		and "18" in campos["Público objetivo"])
	piratas = {"village": "Isla Calavera", "symbols": {"coin": {"name": "Doblón", "look": "coin"}, "pig": {"name": "Loro", "look": "crown"}},
		"buildings": {"casa": {"name": "Puerto", "look": "ship"}}}
	lp, ep = contenido.validar("tragaperras", piratas)
	check("contenido tragaperras: aldea pirata pasa el control", not ep and lp["buildings"]["casa"]["look"] == "ship", str(ep))
	_, ep2 = contenido.validar("tragaperras", {"symbols": {"dinero": {"name": "Euros"}, "chest": {"pay": 99999}}})
	check("contenido tragaperras: simbolos nuevos y premios fuera de margen se rechazan", any("dinero" in e for e in ep2) and any("pay" in e for e in ep2), str(ep2))
	## Reino: campamentos que crecen, el ultimo el jefe, y contenido del tema.
	dr = simulado.disenar("un juego tipo kingshot de un reino medieval")
	dr["genero"] = "reino"
	dr = director.normalizar(dr)
	gr = director.a_game(dr, director.generar_niveles(dr, 6))
	lr = gr["levels"]
	check("reino: campamentos en orden y cada vez mas", all(len(lv["camps"]) >= 2 and [c["at"] for c in lv["camps"]] == sorted(c["at"] for c in lv["camps"]) for lv in lr)
		and len(lr[-1]["camps"]) >= len(lr[0]["camps"]) and lr[-1]["par"] > lr[0]["par"])
	hielo = {"realm": "Reino Helado", "troops": {"infantry": {"name": "Cazadores", "hp": 14}}, "buildings": {"granja": {"name": "Pescadería", "look": "farm"}},
		"camp_names": ["Cueva del yeti", "Fortaleza del Rey Yeti"]}
	lh, eh = contenido.validar("reino", hielo)
	check("contenido reino: un reino helado pasa el control", not eh and lh["troops"]["infantry"]["name"] == "Cazadores", str(eh))
	_, eh2 = contenido.validar("reino", {"troops": {"dragones": {"name": "Dragones"}, "archer": {"atk": 50}}})
	check("contenido reino: tropas nuevas y numeros fuera de margen se rechazan", any("dragones" in e for e in eh2) and any("atk" in e for e in eh2), str(eh2))
	dd = simulado.disenar("un monopoly go de piratas")
	dd["genero"] = "tragaperras"
	dd["giros"] = ["dados"]
	dd = director.normalizar(dd)
	gd = director.a_game(dd, director.generar_niveles(dd, 4))
	check("tragaperras dados: cada nivel lleva el tablero y su escala", all((lv.get("slots") or {}).get("preset") == ["dados"] and 0.1 < lv["scale"] < 5.0 for lv in gd["levels"]),
		str([lv.get("scale") for lv in gd["levels"]]))
	import json
	dm = simulado.disenar("un count masters de vikingos")
	dm["genero"] = "multitud"
	dm = director.normalizar(dm)
	gm = director.a_game(dm, director.generar_niveles(dm, 5))
	lm = gm["levels"]
	check("multitud: pistas con jefe al final y distintas en cada nivel", all(lv["track"][-1]["t"] == "boss" for lv in lm) and len({json.dumps(lv["track"]) for lv in lm}) == len(lm))
	dm2 = simulado.disenar("un count masters de vikingos")
	dm2["genero"] = "multitud"
	dm2 = director.normalizar(dm2)
	gm2 = director.a_game(dm2, director.generar_niveles(dm2, 99))
	check("multitud: otra semilla, otra pista", gm2["levels"][0]["track"] != lm[0]["track"])
	dp = simulado.disenar("un gossip harbor en un puerto")
	dp["genero"] = "pedidos"
	dp = director.normalizar(dp)
	gp = director.a_game(dp, director.generar_niveles(dp, 5))
	lp2 = gp["levels"]
	check("pedidos: cada nivel con pedidos y energia justa", all(len(lv["orders"]) >= 4 and lv["energy"] >= 4 and lv["regen"] >= 2 for lv in lp2)
		and len(lp2[-1]["orders"]) > len(lp2[0]["orders"]))
	ddf = simulado.disenar("un juego de encontrar las diferencias")
	ddf["genero"] = "diferencias"
	ddf = director.normalizar(ddf)
	gdf = director.a_game(ddf, director.generar_niveles(ddf, 4))
	check("diferencias: cada nivel con escena y de 3 a 8 diferencias", all(len(lv["scene"]) >= 10 and 3 <= len(lv["diffs"]) <= 8 for lv in gdf["levels"]))
	dpw = simulado.disenar("una torre de poder de caballeros")
	dpw["genero"] = "poder"
	dpw = director.normalizar(dpw)
	gpw = director.a_game(dpw, director.generar_niveles(dpw, 4))
	check("poder: torres con un jefe arriba de la ultima", all(lv["towers"][-1][-1]["t"] == "boss" and len(lv["towers"]) >= 2 for lv in gpw["levels"]))
	djg = simulado.disenar("un rompecabezas de paisajes")
	djg["genero"] = "rompecabezas"
	djg = director.normalizar(djg)
	gjg = director.a_game(djg, director.generar_niveles(djg, 6))
	check("rompecabezas: piezas desordenadas de 3x3 en adelante", all(lv["size"] >= 3 and sorted(lv["order"]) == list(range(lv["size"] ** 2)) for lv in gjg["levels"]))
	dpn = simulado.disenar("un pintar por numeros de animales")
	dpn["genero"] = "pintar"
	dpn = director.normalizar(dpn)
	gpn = director.a_game(dpn, director.generar_niveles(dpn, 6))
	check("pintar: dibujos con paleta de 2 a 9 colores y el heroe cada tres", all(2 <= len(lv["palette"]) <= 9 for lv in gpn["levels"]) and bool(gpn["levels"][2].get("from_art")))
	dkh = simulado.disenar("un lanza cuchillos de ninjas")
	dkh["genero"] = "cuchillos"
	dkh = director.normalizar(dkh)
	gkh = director.a_game(dkh, director.generar_niveles(dkh, 6))
	check("cuchillos: troncos que giran y el jefe en el quinto", all(lv["spin"] and lv["knives"] >= 6 for lv in gkh["levels"])
		and not any(lv["boss"] for lv in gkh["levels"][:4]) and generador.parametros_cuchillos(4, 8, "normal", 0.0, ["cuchillos", "#3"])["boss"])
	drg = simulado.disenar("un archero de ninjas")
	drg["genero"] = "arquero"
	drg = director.normalizar(drg)
	grg = director.a_game(drg, director.generar_niveles(drg, 6))
	check("arquero: salas con enemigos lejos de la entrada", all(lv["rooms"] and all(e["y"] < 9 for r in lv["rooms"] for e in r["enemies"]) for lv in grg["levels"]))
	dfl = simulado.disenar("un puzle de flechas")
	dfl["genero"] = "flechas"
	dfl = director.normalizar(dfl)
	gfl = director.a_game(dfl, director.generar_niveles(dfl, 6))
	check("flechas: tableros con flechas y pocas libres al empezar", all(len(lv["arrows"]) >= 6 and generador._libres_flechas(lv["w"], lv["h"], lv["arrows"]) * 2 <= len(lv["arrows"]) for lv in gfl["levels"]))
	dnu = simulado.disenar("un 2048 de colores")
	dnu["genero"] = "numeros"
	dnu = director.normalizar(dnu)
	gnu = director.a_game(dnu, director.generar_niveles(dnu, 6))
	check("numeros: objetivos potencia de 2 que suben", all(lv["target"] & (lv["target"] - 1) == 0 and lv["target"] >= 64 for lv in gnu["levels"]))
	dcl = simulado.disenar("un juego de cartas locas")
	dcl["genero"] = "cartas_locas"
	dcl = director.normalizar(dcl)
	gcl = director.a_game(dcl, director.generar_niveles(dcl, 6))
	check("cartas locas: mazos completos con los que tu bot gana", all(len(lv["deck"]) == 108 and generador._PartidaC8(lv["deck"], lv["players"], lv["hand"]).partida(True) == 0 for lv in gcl["levels"]))
	ddo = simulado.disenar("un domino contra la maquina")
	ddo["genero"] = "domino"
	ddo = director.normalizar(ddo)
	gdo = director.a_game(ddo, director.generar_niveles(ddo, 6))
	check("domino: mazos completos con los que tu bot gana", all(len(lv["deck"]) == 28 and generador._PartidaDomino(lv["deck"], lv["players"], lv["hand"]).partida(True) == 0 for lv in gdo["levels"]))
	dbj = simulado.disenar("un juego de bloques de colores y puertas")
	dbj["genero"] = "bloques_colores"
	dbj = director.normalizar(dbj)
	gbj = director.a_game(dbj, director.generar_niveles(dbj, 6))
	check("bloques de colores: tableros que se pueden vaciar", all(len(lv["blocks"]) >= 4 and generador._resolver_jam(lv) > 0 for lv in gbj["levels"]))
	dpp = simulado.disenar("un juego de girar tuberias")
	dpp["genero"] = "tuberias"
	dpp = director.normalizar(dpp)
	gpp = director.a_game(dpp, director.generar_niveles(dpp, 6))
	check("tuberias: tableros desordenados con solucion", all(len(lv["tiles"]) == lv["w"] * lv["h"] and lv["tiles"] != lv["sol"] for lv in gpp["levels"]))
	daj = simulado.disenar("un juego de ajedrez contra la maquina")
	daj["genero"] = "ajedrez"
	daj = director.normalizar(daj)
	gaj = director.a_game(daj, director.generar_niveles(daj, 6))
	check("ajedrez: escalera de ventaja (al principio al rival le faltan piezas)", len(gaj["levels"][0]["quitar"]) >= len(gaj["levels"][-1]["quitar"]) and len(gaj["levels"][0]["quitar"]) >= 1 and gaj["levels"][0]["rival"] == 1)
	drv = simulado.disenar("un juego de reversi contra la maquina")
	drv["genero"] = "reversi"
	drv = director.normalizar(drv)
	grv = director.a_game(drv, director.generar_niveles(drv, 6))
	check("reversi: empieza en 6x6 y acaba en 8x8", grv["levels"][0]["size"] == 6 and grv["levels"][-1]["size"] == 8 and grv["levels"][0]["rival"] == 1)
	dbu = simulado.disenar("un juego de buscar objetos escondidos")
	dbu["genero"] = "buscar"
	dbu = director.normalizar(dbu)
	gbu = director.a_game(dbu, director.generar_niveles(dbu, 6))
	check("buscar: cada objeto que se busca es el unico de su familia en la escena", all(
		sum(1 for sh in lv["shapes"] if generador._familia(sh["k"]) == generador._familia(lv["shapes"][t]["k"])) == 1 for lv in gbu["levels"] for t in lv["targets"]))
	dsl = simulado.disenar("un puzle de deslizar piezas")
	dsl["genero"] = "deslizar"
	dsl = director.normalizar(dsl)
	gsl = director.a_game(dsl, director.generar_niveles(dsl, 6))
	check("deslizar: tableros revueltos con su solucion, de 3x3 hacia arriba", all(sorted(lv["tiles"]) == list(range(lv["n"] ** 2)) and lv["tiles"] != sorted(lv["tiles"]) and lv["sol"] for lv in gsl["levels"]) and gsl["levels"][0]["n"] == 3)
	dah = simulado.disenar("un juego del ahorcado")
	dah["genero"] = "ahorcado"
	dah = director.normalizar(dah)
	gah = director.a_game(dah, director.generar_niveles(dah, 6))
	check("ahorcado: palabras de 5 a 8 letras y de 5 a 7 globos", all(5 <= lv["len"] <= 8 and 5 <= lv["lives"] <= 7 for lv in gah["levels"]))
	dfl = simulado.disenar("un juego de hundir la flota")
	dfl["genero"] = "flota"
	dfl = director.normalizar(dfl)
	gfl = director.a_game(dfl, director.generar_niveles(dfl, 6))
	check("flota: barcos que caben y rival cada vez mas listo", all(sum(lv["ships"]) * 3 <= lv["n"] ** 2 for lv in gfl["levels"]) and gfl["levels"][0]["rival"] <= gfl["levels"][-1]["rival"])
	dsi = simulado.disenar("un juego de simon dice")
	dsi["genero"] = "simon"
	dsi = director.normalizar(dsi)
	gsi = director.a_game(dsi, director.generar_niveles(dsi, 6))
	check("simon: secuencias cada vez mas largas y luces que se pueden seguir", gsi["levels"][0]["goal"] <= gsi["levels"][-1]["goal"] and all(lv["speed"] >= 0.3 and 4 <= lv["pads"] <= 6 for lv in gsi["levels"]))
	des = simulado.disenar("un juego de estrategia por turnos con tanques")
	des["genero"] = "estrategia"
	des = director.normalizar(des)
	ges = director.a_game(des, director.generar_niveles(des, 6))
	check("estrategia: mapas con cuarteles y ejercitos, tu con refuerzos al principio", all(any("H" in r for r in lv["tiles"]) and any("h" in r for r in lv["tiles"]) for lv in ges["levels"])
		and sum(1 for u in ges["levels"][0]["units"] if u["side"] == 1) > sum(1 for u in ges["levels"][0]["units"] if u["side"] == 2))
	dab = simulado.disenar("un auto chess de animales")
	dab["genero"] = "autobatalla"
	dab = director.normalizar(dab)
	gab = director.a_game(dab, director.generar_niveles(dab, 6))
	check("autobatalla: rondas con ejercitos que crecen y siempre en su mitad", all(len(lv["rounds"]) >= 4 and all(0 <= e["y"] <= 3 for r in lv["rounds"] for e in r) for lv in gab["levels"])
		and len(gab["levels"][-1]["rounds"][-1]) >= len(gab["levels"][0]["rounds"][0]))
	dgm = simulado.disenar("un juego de gemas y heroes contra monstruos")
	dgm["genero"] = "gemas"
	dgm = director.normalizar(dgm)
	ggm = director.a_game(dgm, director.generar_niveles(dgm, 6))
	check("gemas: equipo de 3 a 5 y oleadas cada vez mas duras", all(3 <= len(lv["team"]) <= 5 and lv["waves"] for lv in ggm["levels"])
		and len(ggm["levels"][-1]["waves"]) >= len(ggm["levels"][0]["waves"]))
	dcc = simulado.disenar("un juego de cartas coleccionables tipo hearthstone")
	dcc["genero"] = "coleccionables"
	dcc = director.normalizar(dcc)
	gcc = director.a_game(dcc, director.generar_niveles(dcc, 6))
	check("coleccionables: mazos de 20 con cartas que existen y rival mas listo al final", all(len(lv["deck"]) == 20 and len(lv["foe_deck"]) == 20 for lv in gcc["levels"])
		and gcc["levels"][0]["ai"] <= gcc["levels"][-1]["ai"])
	drg = simulado.disenar("un roguelike por turnos tipo pixel dungeon")
	drg["genero"] = "roguelike"
	drg = director.normalizar(drg)
	grg = director.a_game(drg, director.generar_niveles(drg, 6))
	check("roguelike: mazmorras con salida y escalera y heroe mas fuerte al final", all(any("P" in f for f in lv["map"]) and any(">" in f for f in lv["map"]) for lv in grg["levels"])
		and grg["levels"][0]["hp"] <= grg["levels"][-1]["hp"])
	dbm = simulado.disenar("un bomberman de robots")
	dbm["genero"] = "bombas"
	dbm = director.normalizar(dbm)
	gbm = director.a_game(dbm, director.generar_niveles(dbm, 6))
	check("bombas: laberintos con una salida escondida y mas monstruos al final", all(sum(f.count("X") for f in lv["map"] if not f[1:].isdigit()) == 1 for lv in gbm["levels"])
		and gbm["levels"][0]["par"] <= gbm["levels"][-1]["par"])
	dar = simulado.disenar("un worms de patos con bazucas")
	dar["genero"] = "artilleria"
	dar = director.normalizar(dar)
	gar = director.a_game(dar, director.generar_niveles(dar, 6))
	check("artilleria: terreno de 120 columnas, equipos en su lado y rival mas listo al final", all(len(lv["ground"]) == 120 and max(lv["team"]) < min(lv["foes"]) for lv in gar["levels"])
		and gar["levels"][0]["ai"] <= gar["levels"][-1]["ai"])
	dcm = simulado.disenar("un pacman de gatos")
	dcm["genero"] = "comecocos"
	dcm = director.normalizar(dcm)
	gcm = director.a_game(dcm, director.generar_niveles(dcm, 6))
	check("comecocos: laberintos con salida, fantasmas y pildoras, y fantasmas mas rapidos al final", all(sum(f.count("P") for f in lv["map"] if not f[1:].isdigit()) == 1 and sum(f.count("o") for f in lv["map"]) == 4 for lv in gcm["levels"])
		and gcm["levels"][0]["ghost_speed"] <= gcm["levels"][-1]["ghost_speed"])
	dzu = simulado.disenar("un zuma con una rana en la selva")
	dzu["genero"] = "cadena"
	dzu = director.normalizar(dzu)
	gzu = director.a_game(dzu, director.generar_niveles(dzu, 6))
	check("cadena: camino, lanzador y bolas de pocos colores, y mas rapida al final", all(len(lv["path"]) >= 40 and len(lv["balls"]) >= 30 and max(lv["balls"]) < lv["colors"] for lv in gzu["levels"])
		and gzu["levels"][0]["speed"] <= gzu["levels"][-1]["speed"])
	dfg = simulado.disenar("un juego de lucha tipo street fighter con robots")
	dfg["genero"] = "lucha"
	dfg = director.normalizar(dfg)
	gfg = director.a_game(dfg, director.generar_niveles(dfg, 6))
	check("lucha: rivales con estilo, mas vida y mas listos al final", all(lv["foe_style"] in ("rusher", "zoner", "counter") for lv in gfg["levels"])
		and gfg["levels"][0]["ai"] <= gfg["levels"][-1]["ai"] and gfg["levels"][0]["foe_hp"] <= gfg["levels"][-1]["foe_hp"])
	dsm = simulado.disenar("un juego de la sandia con frutas que se juntan")
	dsm["genero"] = "sandia"
	dsm = director.normalizar(dsm)
	gsm = director.a_game(dsm, director.generar_niveles(dsm, 6))
	check("sandia: frutas pequenas, objetivo mas grande y que crece al final", all(lv["drop_max"] < lv["goal"] for lv in gsm["levels"])
		and gsm["levels"][0]["goal"] <= gsm["levels"][-1]["goal"])
	dpb = simulado.disenar("un pinball de neon con robots")
	dpb["genero"] = "pinball"
	dpb = director.normalizar(dpb)
	gpb = director.a_game(dpb, director.generar_niveles(dpb, 6))
	check("pinball: mesas con setas y dianas, y objetivo mas alto al final", all(len(lv["bumpers"]) >= 3 and len(lv["targets"]) == 3 for lv in gpb["levels"])
		and gpb["levels"][0]["goal"] <= gpb["levels"][-1]["goal"])
	dmv = simulado.disenar("un metroidvania de un caballero en un castillo")
	dmv["genero"] = "metroidvania"
	dmv = director.normalizar(dmv)
	gmv = director.a_game(dmv, director.generar_niveles(dmv, 6))
	check("metroidvania: mundos con salida, meta y habilidades, mas grandes al final", all(sum(f.count("P") for f in lv["map"]) == 1 and sum(f.count("G") for f in lv["map"]) == 1 and any(c in "".join(lv["map"]) for c in "JDBK") for lv in gmv["levels"])
		and len(gmv["levels"][0]["map"][0]) <= len(gmv["levels"][-1]["map"][0]))
	dsl = simulado.disenar("un juego tipo hitman go de espias")
	dsl["genero"] = "sigilo"
	dsl = director.normalizar(dsl)
	gsl = director.a_game(dsl, director.generar_niveles(dsl, 6))
	check("sigilo: tableros con heroe, salida y guardias, y mas largos al final", all(sum(f.count("P") for f in lv["map"]) == 1 and sum(f.count("X") for f in lv["map"]) == 1 and any(c in "".join(lv["map"]) for c in "NSEWnsewR") for lv in gsl["levels"])
		and gsl["levels"][0]["par"] <= gsl["levels"][-1]["par"])
	presets = (Path(__file__).resolve().parents[2] / "orqkit" / "export_presets.cfg").read_text(encoding="utf-8")
	check("palabras: los diccionarios entran en la APK", presets.count("kit/words/dicts/*.txt") == 2)
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

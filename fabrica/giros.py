"""Giros: reglas raras encima de un genero (el kit las aplica: orqkit/kit/twist.gd) y mezclas de
dos generos (giros propios de un genero, p. ej. laberinto + serpiente).

La fabrica aprende de cada uso:
1 - Cada fabricacion apunta, por genero y giro, si salio bien (datos/giros.jsonl).
2 - Si un juego con giros no supera a los bots, se quitan los giros, se rehace y se apunta una
    leccion (datos/lecciones.jsonl) que la directora lee la proxima vez. Nunca se entrega roto.
3 - Un giro que falla mucho en un genero (menos del 70 % de exitos en 5 o mas intentos) deja de
    ofrecerse para ese genero hasta que vuelva a ir bien (fiables()).

	python -m giros informe      (fiabilidad por genero y giro, y ultimas lecciones)
"""

import json
import os
import sys
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parent

## generos: donde tiene sentido y funciona (probado con bots). seguro: no cambia si un nivel se
## puede pasar (solo se ve o se cobra distinto), asi que vale para el reto diario.
GIROS: dict[str, dict] = {
	"oscuridad": {
		"nombre": "A oscuras", "que": "Solo ves lo que alumbra tu linterna",
		"generos": ["plataformas", "runner", "volador", "horda", "naves", "cajas", "laberinto", "golf"],
		"seguro": True, "mezcla": False,
		"claves": ["a oscuras", "oscuridad", "linterna", "de noche sin luz", "in the dark"],
	},
	"espejo": {
		"nombre": "Mundo espejo", "que": "El mundo se ve al revés: izquierda y derecha se cambian",
		"generos": ["plataformas", "runner", "volador", "horda", "cajas", "laberinto", "golf", "serpiente"],
		"seguro": True, "mezcla": False,
		"claves": ["espejo", "al reves", "al revés", "mirror"],
	},
	"contrarreloj": {
		"nombre": "Contrarreloj", "que": "Cada intento tiene un tiempo; si se acaba, a empezar",
		"generos": ["laberinto", "golf", "cajas", "serpiente", "bloques", "memoria", "rompebloques", "saltos", "apilar", "cartas"],
		"seguro": False, "mezcla": False,
		"claves": ["contrarreloj", "contra reloj", "cronometro", "cronómetro", "tiempo limite", "tiempo límite"],
	},
	"racha": {
		"nombre": "Racha", "que": "Cada nivel sin morir sube el multiplicador de monedas (hasta x3)",
		"generos": "*", "seguro": True, "mezcla": False,
		"claves": ["racha", "combo", "multiplicador"],
	},
	"fantasma": {
		"nombre": "Fantasma", "que": "Corres contra tu mejor partida: una figura transparente repite tu mejor camino",
		"generos": ["plataformas", "runner", "volador", "horda"], "seguro": True, "mezcla": False,
		"claves": ["fantasma", "contra ti mismo", "tu mejor tiempo", "speedrun", "ghost"],
	},
	"modos": {
		"nombre": "Muchos modos", "que": "Cada nivel es un modo distinto: todos contra todos, supervivencia por oleadas, balón 3 contra 3 y torretas 3 contra 3",
		"generos": ["arena"], "seguro": False, "mezcla": True,
		"claves": ["modos", "3 contra 3", "3vs3", "3 vs 3", "balon", "balón", "pelota", "torretas", "supervivencia", "survival", "brawl ball"],
	},
	"cola": {
		"nombre": "Laberinto serpiente", "que": "Mezcla con la serpiente: las casillas que dejas atrás se cierran",
		"generos": ["laberinto"], "seguro": False, "mezcla": True,
		"claves": ["serpiente", "cola", "sin volver atras", "sin volver atrás", "snake"],
	},
	"niebla": {
		"nombre": "Niebla de guerra", "que": "Solo ves lo que tienen cerca tus aldeanos, tropas y edificios: hay que explorar para encontrar al rival",
		"generos": ["imperio"], "seguro": False, "mezcla": True,
		"claves": ["niebla", "niebla de guerra", "explorar", "fog of war", "a ciegas", "descubrir el mapa"],
	},
	"viento": {
		"nombre": "Viento", "que": "El viento empuja la bola mientras rueda: hay que apuntar contando con él",
		"generos": ["golf"], "seguro": False, "mezcla": False,
		"claves": ["viento", "vendaval", "huracan", "huracán", "wind"],
	},
	"tormenta": {
		"nombre": "Tormenta", "que": "Llueve y los peces nadan cada vez más rápido",
		"generos": ["pesca"], "seguro": False, "mezcla": False,
		"claves": ["tormenta", "lluvia", "temporal", "storm"],
	},
	"piedras": {
		"nombre": "Piedras", "que": "Piedras que estorban hasta que una fusión al lado las rompe",
		"generos": ["fusion"], "seguro": False, "mezcla": False,
		"claves": ["piedra", "piedras", "roca", "rocas", "bloqueos"],
	},
	"hielo": {
		"nombre": "Suelo de hielo", "que": "Las cajas resbalan hasta chocar con algo: hay que pensar dónde se paran",
		"generos": ["cajas"], "seguro": False, "mezcla": False,
		"claves": ["hielo", "helado", "congelad", "pista de patinaje", "resbala", "ice"],
	},
	"tuneles": {
		"nombre": "Túneles", "que": "Huecos en el borde: sales por un lado y entras por el contrario",
		"generos": ["serpiente"], "seguro": False, "mezcla": False,
		"claves": ["tunel", "túnel", "tuneles", "túneles", "portal", "sin bordes", "da la vuelta"],
	},
	"barajar": {
		"nombre": "Cartas inquietas", "que": "Cada 2 fallos, dos cartas tapadas se cambian de sitio (se ve el cambio)",
		"generos": ["memoria"], "seguro": False, "mezcla": False,
		"claves": ["barajar", "se mueven", "inquietas", "cambian de sitio", "traviesas", "shuffle"],
	},
	"dorado": {
		"nombre": "Bichos de oro", "que": "A veces asoma uno de oro: se va antes, pero vale 3 golpes",
		"generos": ["topos"], "seguro": False, "mezcla": False,
		"claves": ["oro", "dorado", "dorados", "tesoro", "golden"],
	},
	"invisibles": {
		"nombre": "Notas invisibles", "que": "Las notas se apagan antes de llegar: hay que tocar de memoria y al ritmo",
		"generos": ["ritmo"], "seguro": False, "mezcla": False,
		"claves": ["invisible", "invisibles", "de memoria", "a ciegas", "hidden"],
	},
	"apocalipsis": {
		"nombre": "Apocalipsis zombi", "que": "Supervivencia tras el fin del mundo: saquea casas y coches, zombis que no temen al fuego, muros y una radio para pedir rescate",
		"generos": ["supervivencia"], "seguro": False, "mezcla": True,
		"claves": ["zombi", "zombie", "apocalipsis", "last day", "ldoe", "saquear", "postapocal", "post apocal", "fin del mundo"],
	},
	"invierno": {
		"nombre": "Invierno", "que": "Hace frío de noche: hoguera, cama o un abrigo de piel de ciervo para no congelarte",
		"generos": ["supervivencia"], "seguro": False, "mezcla": True,
		"claves": ["invierno", "nieve", "nevad", "frio", "frío", "polar", "glaciar", "winter", "frostborn", "congelar"],
	},
	"caza": {
		"nombre": "Caza", "que": "Ciervos que huyen y jabalíes que embisten: caza, cocina la carne en la hoguera (cruda enferma)",
		"generos": ["supervivencia"], "seguro": False, "mezcla": True,
		"claves": ["cazar", "caza", "ciervo", "jabal", "selva", "jungla", "hunting", "cocinar carne"],
	},
	"equipo": {
		"nombre": "Equipo de héroes", "que": "RPG de equipo tipo Raid o Summoners War: cuatro héroes con habilidades, elementos, estados, turnos por velocidad y botón AUTO",
		"generos": ["rpg"], "seguro": False, "mezcla": True,
		"claves": ["equipo", "heroes", "héroes", "gacha", "raid", "summoners", "afk arena", "epic seven", "escuadron", "escuadrón"],
	},
	"criaturas": {
		"nombre": "Criaturas", "que": "Combates uno contra uno de criaturas de fuego, agua y planta con cuatro movimientos (al caer una, sale la siguiente)",
		"generos": ["rpg"], "seguro": False, "mezcla": True,
		"claves": ["criatura", "pokemon", "pokémon", "entrenador", "monstruos de bolsillo", "capturar", "temtem"],
	},
	"survivor": {
		"nombre": "Estilo Survivor", "que": "Hordas tipo Survivor.io: kunais, drones, rayos que saltan, escudos que giran y evoluciones de armas",
		"generos": ["horda"], "seguro": False, "mezcla": True,
		"claves": ["survivor.io", "survivor io", "kunai", "drones", "evolucion de armas", "evolucionar armas"],
	},
	"vampiros": {
		"nombre": "Estilo Vampiros", "que": "Hordas tipo Vampire Survivors: latigo, ajo, agua bendita, libro que gira y evoluciones",
		"generos": ["horda"], "seguro": False, "mezcla": True,
		"claves": ["vampire survivors", "vampiro", "latigo", "látigo", "ajo", "agua bendita", "castillo"],
	},
	"fantasia": {
		"nombre": "Imperio de fantasía", "que": "El imperio con guardianes, elfas arqueras, jinetes de grifo, gólems y torres de mago",
		"generos": ["imperio"], "seguro": False, "mezcla": False,
		"claves": ["fantasia", "fantasía", "elfos", "elfo", "grifo", "magos", "golem", "gólem", "orcos"],
	},
	"galactico": {
		"nombre": "Imperio galáctico", "que": "Estrategia espacial: drones mineros, marines, francotiradores, motos aéreas y tanques de asedio",
		"generos": ["imperio"], "seguro": False, "mezcla": False,
		"claves": ["galactic", "galáctic", "espacial", "espacio", "starcraft", "planeta", "alien", "marines", "ciencia ficcion", "ciencia ficción"],
	},
	"fiesta": {
		"nombre": "Karts de fiesta", "que": "Mas objetos en la ruleta: la estrella (nada te para) y la cascara triple",
		"generos": ["karts"], "seguro": False, "mezcla": False,
		"claves": ["estrella", "mario kart", "fiesta", "caos", "muchos objetos", "cascara triple"],
	},
	"dados": {
		"nombre": "Tablero de dados", "que": "Tipo Monopoly Go: en vez de rodillos, dos dados y una ficha que da la vuelta a un tablero con premios",
		"generos": ["tragaperras"], "seguro": False, "mezcla": False,
		"claves": ["dados", "monopoly", "tablero", "ficha", "casillas"],
	},
	"mina": {
		"nombre": "Tycoon de mina", "que": "Tipo Idle Miner: pozos que sacan mineral, ascensor que lo sube y almacen que lo vende (manda el mas lento)",
		"generos": ["tycoon"], "seguro": False, "mezcla": False,
		"claves": ["mina", "minero", "mineros", "idle miner", "pozo", "pozos", "mineral", "excavar", "cavar"],
	},
	"monstruos": {
		"nombre": "Golf de monstruos", "que": "Mezcla con el RPG: derriba monstruos con la bola para abrir el hoyo",
		"generos": ["golf"], "seguro": False, "mezcla": True,
		"claves": ["monstruo", "monstruos", "rpg", "enemigos", "derriba"],
	},
}

MAX_GIROS = 2
MIN_USOS = 5
MIN_EXITO = 0.7

## El trabajador conecta esto al servidor (giro_anotar): asi aprenden todas las maquinas de la
## fabrica de lo mismo. Y en cada mantenimiento baja el resumen (giros_estadisticas) a
## datos/giros_servidor.json, que manda sobre lo local.
remoto = None


def carpeta() -> Path:
	return Path(os.environ.get("ORQ_DATOS", str(RAIZ / "datos")))


def compatibles(genero: str) -> list[str]:
	return [g for g, x in GIROS.items() if x["generos"] == "*" or genero in x["generos"]]


# ------------------------------------------------------------------ aprender

def anotar(genero: str, giros: list[str], ok: bool, problema: str = "") -> None:
	"""Apunta el resultado de una fabricacion con giros (y la leccion si fallo)."""
	if not giros:
		return
	if remoto is not None:
		for g in giros:
			try:
				remoto(genero, g, ok, problema[:240] if not ok else "")
			except Exception:  # noqa: BLE001 - aprender nunca para la fabrica
				pass
	try:
		c = carpeta()
		c.mkdir(parents=True, exist_ok=True)
		with (c / "giros.jsonl").open("a", encoding="utf-8") as f:
			for g in giros:
				f.write(json.dumps({"t": int(time.time()), "genero": genero, "giro": g, "ok": ok}) + "\n")
		if not ok:
			with (c / "lecciones.jsonl").open("a", encoding="utf-8") as f:
				f.write(json.dumps({"t": int(time.time()), "genero": genero, "giros": giros, "problema": problema[:240]},
					ensure_ascii=False) + "\n")
	except OSError:
		pass


def _leer(nombre: str, dias: int = 120) -> list[dict]:
	p = carpeta() / nombre
	if not p.exists():
		return []
	desde = time.time() - dias * 86400
	out = []
	for linea in p.read_text(encoding="utf-8").splitlines():
		try:
			r = json.loads(linea)
		except json.JSONDecodeError:
			continue
		if r.get("t", 0) >= desde:
			out.append(r)
	return out


def guardar_servidor(resumen: dict) -> None:
	"""Lo que devuelve giros_estadisticas() del servidor (stats y lecciones de toda la fabrica).
	Si llega algo raro (servidor antiguo, error), no se guarda: se sigue con lo local."""
	if not isinstance(resumen, dict) or not isinstance(resumen.get("stats"), list):
		return
	c = carpeta()
	c.mkdir(parents=True, exist_ok=True)
	(c / "giros_servidor.json").write_text(json.dumps(resumen, ensure_ascii=False), encoding="utf-8")


def _servidor() -> dict | None:
	p = carpeta() / "giros_servidor.json"
	if not p.exists():
		return None
	try:
		d = json.loads(p.read_text(encoding="utf-8"))
	except (OSError, json.JSONDecodeError):
		return None
	return d if isinstance(d, dict) and isinstance(d.get("stats"), list) else None


def estadisticas() -> dict[str, dict]:
	"""{ "genero|giro": {"usos": n, "ok": k} } de los ultimos 120 dias (del servidor si lo hay,
	mas lo apuntado aqui despues)."""
	st: dict[str, dict] = {}
	srv = _servidor()
	if srv:
		for r in srv.get("stats", []):
			st[f"{r['genero']}|{r['giro']}"] = {"usos": int(r["usos"]), "ok": int(r["ok"])}
		return st
	for r in _leer("giros.jsonl"):
		e = st.setdefault(f"{r['genero']}|{r['giro']}", {"usos": 0, "ok": 0})
		e["usos"] += 1
		e["ok"] += 1 if r.get("ok") else 0
	return st


def fiable(genero: str, giro: str, st: dict | None = None) -> bool:
	e = (st if st is not None else estadisticas()).get(f"{genero}|{giro}")
	if not e or e["usos"] < MIN_USOS:
		return True
	return e["ok"] / e["usos"] >= MIN_EXITO


def fiables(genero: str) -> list[str]:
	st = estadisticas()
	return [g for g in compatibles(genero) if fiable(genero, g, st)]


def lecciones(genero: str | None = None, n: int = 8) -> list[dict]:
	ls = _leer("lecciones.jsonl", 365)
	srv = _servidor()
	if srv:
		ls = [{"genero": x["genero"], "giros": [x["giro"]], "problema": x["problema"]} for x in reversed(srv.get("lecciones", []))] + ls
	if genero:
		ls = [x for x in ls if x.get("genero") == genero] + [x for x in ls if x.get("genero") != genero]
	return ls[-n:] if not genero else ls[:n]


# ------------------------------------------------------------------ disenar

import re

MARCA = re.compile(r"^\s*\[gancho:([a-z_]{2,20}):([a-z_,]{0,60})\]\s*")


def separar(idea: str) -> tuple[str, dict | None]:
	"""«[gancho:genero:giro1,giro2] idea» (lo manda la app al elegir un gancho original) ->
	(idea sin la marca, {"genero", "giros"} o None). Solo generos y giros que existen y casan."""
	import generos
	m = MARCA.match(idea)
	if not m:
		return idea, None
	resto = idea[m.end():].strip()
	genero = m.group(1)
	if genero not in generos.GENEROS:
		return resto, None
	gs = [g for g in m.group(2).split(",") if g in GIROS and g in compatibles(genero)][:MAX_GIROS]
	return resto, {"genero": genero, "giros": gs}


def fijar(d: dict, gancho: dict) -> dict:
	d["genero"] = gancho["genero"]
	d["giros"] = list(gancho["giros"])
	return d

def limpiar(d: dict) -> dict:
	"""Deja en el diseno solo giros conocidos, compatibles, fiables y como mucho MAX_GIROS."""
	genero = d.get("genero", "plataformas")
	vale = set(fiables(genero))
	out = []
	for g in d.get("giros") or []:
		if g in vale and g not in out:
			out.append(g)
	d["giros"] = out[:MAX_GIROS]
	if not d["giros"]:
		d.pop("giros", None)
	return d


def de_la_idea(idea: str, genero: str) -> list[str]:
	"""Directora sin IA: giros que pide la idea con palabras clave."""
	t = idea.lower()
	return [g for g in fiables(genero) if any(c in t for c in GIROS[g]["claves"])][:MAX_GIROS]


def guia(genero: str | None = None) -> str:
	"""Texto para la directora (va con la idea, como datos): giros por genero y lecciones."""
	lineas = ["GIROS DISPONIBLES (opcionales, 0 a 2; solo si la idea los pide o hacen el juego mas original y "
		"divertido; nunca uno que no este en la lista de su genero):"]
	for g, x in GIROS.items():
		gens = "todos" if x["generos"] == "*" else ", ".join(x["generos"])
		lineas.append(f"- {g}: {x['que']} (generos: {gens})")
	ls = lecciones(genero)
	if ls:
		lineas.append("LECCIONES DE LA FABRICA (errores anteriores; evitalos):")
		for x in ls:
			lineas.append(f"- {x['genero']} con {', '.join(x['giros'])}: {x['problema']}")
	return "\n".join(lineas)


def informe() -> str:
	st = estadisticas()
	lineas = [f"{'genero|giro':32} usos  exito  ofrecido"]
	for k, e in sorted(st.items()):
		gen, giro = k.split("|")
		lineas.append(f"{k:32} {e['usos']:4}  {e['ok'] / e['usos']:5.0%}  {'si' if fiable(gen, giro, st) else 'NO'}")
	for x in lecciones(None, 10):
		lineas.append(f"leccion: {x['genero']} {x['giros']}: {x['problema']}")
	return "\n".join(lineas)


if __name__ == "__main__":
	if len(sys.argv) > 1 and sys.argv[1] == "informe":
		print(informe())
	else:
		print(__doc__)

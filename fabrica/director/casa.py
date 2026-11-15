"""Casa propia de cada juego (15 nov 2026, Daniel: «que no sea la misma plantilla para todos; nos fijamos en
los juegos mas iconicos, copiamos lo que funciona, lo mejoramos y cambiamos estetica y jugabilidad»).

1 - REFERENTES: el esqueleto que ha demostrado funcionar en cada genero (pantallas, bucle, progresion).
2 - La IA lo transforma para ESTE juego: una metafora propia (bajar a una grieta encadenada, cartas de
    un barco, un jardin que crece...), nombres propios para cada seccion, la forma de la navegacion, el
    material y lo que dibuja la GPU (fondo de la campana, botin, iconos). Nunca nombres ni pantallas
    calcadas del referente.
3 - Sale en diseno["casa"]; a_hub() lo pasa a game.json "hub" (kit/ui/screens/game_hub.gd) y la GPU
    dibuja sus piezas (arte/extras.py: casa/*.png).

	python -m director.casa fabrica/proyectos/x/fabrica/diseno.json     (prueba: imprime la casa)
"""

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from director import llm  # noqa: E402

## Generos con casa propia (el kit sabe montar sus secciones). Los demas siguen con su portada.
SECCIONES = {
	"rpg": ["campaign", "heroes", "summon", "modes", "tavern"],
}

REFERENTES = {
	"rpg": (
		"Lo que funciona en los RPG de coleccion mas jugados (AFK Arena, Idle Heroes, Summoners War): "
		"campana por etapas con un jefe cada pocas etapas; un botin que se llena solo mientras no juegas y se "
		"recoge desde la pantalla de campana; coleccion de heroes con niveles, rangos y elementos que se "
		"potencian entre si; invocar heroes nuevos; modos extra (torre infinita, arena contra otros "
		"jugadores); misiones, diario y tienda agrupados aparte. Navegacion: una barra abajo con la campana "
		"en el centro, mas grande. Lo que NO hay que copiar: sus nombres (Ranhorn, Bosque Oscuro, Gremio...), "
		"su mapa otonal ni sus estandartes; eso es su piel, no su esqueleto."),
}

ICONOS = ["book", "chain", "flask", "mug", "map", "shield", "sword", "gem", "star", "trophy", "coin", "heart", "skull", "cube", "grid"]

PROMPT = """Eres director de arte e interfaz de juegos para movil. Te paso un juego ya disenado y el ESQUELETO que
funciona en los grandes de su genero. Tu trabajo: inventar la CASA de este juego (su pantalla principal y como
se navega) con una METAFORA PROPIA que salga de su mundo, su titulo y su mecanica. No calques al referente:
coge su esqueleto (secciones y bucle) y cambia la piel (nombres, forma, material, lo que se ve).

Reglas:
- Una metafora clara que lo una todo (p. ej. «bajar a una grieta encadenada»: la campana es un descenso, los
  botones son sellos unidos por una cadena). Que se entienda sin explicarla.
- Nombres cortos en espanol (maximo 12 letras) y con personalidad: nada de «Heroes», «Tienda», «Campana» a secas.
- Exactamente estas secciones, una vez cada una: {secciones}. La de "campaign" es la principal.
- Los "dibujo" van en INGLES: que pintaria un ilustrador para esa pieza, en el estilo del juego, sin texto.
- El fondo de la campana es una escena vertical con mucho aire en el centro (encima van los botones).
Llama a la herramienta "casa"."""

HERRAMIENTA = {
	"name": "casa",
	"description": "La casa propia del juego: metafora, navegacion, secciones y piezas a dibujar.",
	"input_schema": {
		"type": "object",
		"required": ["metafora", "titulo", "nav", "secciones", "campana"],
		"properties": {
			"metafora": {"type": "string", "description": "Una frase: la idea que lo une todo."},
			"titulo": {"type": "string", "description": "Texto pequeno de la cabecera (el nombre del lugar o del grupo)."},
			"nav": {"type": "object", "required": ["forma", "union", "metal"], "properties": {
				"forma": {"enum": ["sello", "estandarte", "losa"], "description": "Forma de cada boton de abajo."},
				"union": {"enum": ["cadena", "cuerda", "ninguno"], "description": "Que une los botones."},
				"metal": {"type": "string", "description": "Color #rrggbb del material de la barra (que pegue con la paleta)."}}},
			"secciones": {"type": "array", "items": {"type": "object", "required": ["id", "nombre", "icono", "dibujo"], "properties": {
				"id": {"type": "string"}, "nombre": {"type": "string"}, "icono": {"enum": ICONOS},
				"dibujo": {"type": "string", "description": "Icono pintado de la seccion (ingles): un objeto del mundo del juego."}}}},
			"campana": {"type": "object", "required": ["forma", "verbo", "etapa", "jefe_cada", "hondo", "fondo_dibujo", "botin"], "properties": {
				"forma": {"enum": ["descenso", "ascenso"], "description": "Las etapas bajan (cada vez mas hondo) o suben."},
				"verbo": {"type": "string", "description": "Verbo del boton de jugar con articulo si hace falta: «Bajar a la», «Zarpar a la»..."},
				"etapa": {"type": "string", "description": "Como se llama cada etapa: etapa, isla, piso, sello..."},
				"jefe_cada": {"type": "integer", "minimum": 3, "maximum": 10},
				"hondo": {"type": "string", "description": "Color #rrggbb de lo mas profundo/alto del mapa."},
				"fondo_dibujo": {"type": "string", "description": "Escena vertical del mapa de campana (ingles), sin personajes."},
				"etapa_dibujo": {"type": "string", "description": "Marcador redondo de una etapa (ingles)."},
				"jefe_dibujo": {"type": "string", "description": "Marcador redondo del jefe (ingles)."},
				"botin": {"type": "object", "required": ["nombre", "verbo", "dibujo"], "properties": {
					"nombre": {"type": "string", "description": "Lo que se llena solo (p. ej. «Caldero de esencia»)."},
					"verbo": {"type": "string"}, "dibujo": {"type": "string"}}}}},
		},
	},
}

HEX = re.compile(r"^#[0-9a-fA-F]{6}$")


def genero_casa(diseno: dict) -> str:
	g = str(diseno.get("genero", ""))
	return g if g in SECCIONES else ""


def validar(c: dict, genero: str) -> list[str]:
	e: list[str] = []
	ids = [str(s.get("id")) for s in c.get("secciones", [])]
	if sorted(ids) != sorted(SECCIONES[genero]):
		e.append(f"secciones: tienen que ser exactamente {SECCIONES[genero]} (una vez cada una); hay {ids}")
	for s in c.get("secciones", []):
		n = str(s.get("nombre", ""))
		if not 2 <= len(n) <= 12:
			e.append(f"secciones/{s.get('id')}: nombre de 2 a 12 letras («{n}»)")
		if str(s.get("icono")) not in ICONOS:
			e.append(f"secciones/{s.get('id')}: icono no valido")
		if len(str(s.get("dibujo", ""))) < 12:
			e.append(f"secciones/{s.get('id')}: falta el dibujo")
	nav = c.get("nav") or {}
	if nav.get("forma") not in ("sello", "estandarte", "losa") or nav.get("union") not in ("cadena", "cuerda", "ninguno"):
		e.append("nav: forma o union no validas")
	if not HEX.match(str(nav.get("metal", ""))):
		e.append("nav/metal: color #rrggbb")
	cp = c.get("campana") or {}
	if cp.get("forma") not in ("descenso", "ascenso"):
		e.append("campana/forma: descenso o ascenso")
	if not HEX.match(str(cp.get("hondo", ""))):
		e.append("campana/hondo: color #rrggbb")
	for k in ("verbo", "etapa", "fondo_dibujo"):
		if not str(cp.get(k, "")).strip():
			e.append(f"campana/{k}: falta")
	if len(str(cp.get("verbo", ""))) > 18 or len(str(cp.get("etapa", ""))) > 10:
		e.append("campana: verbo de 18 letras como mucho y etapa de 10")
	b = cp.get("botin") or {}
	if not (2 <= len(str(b.get("nombre", ""))) <= 24) or not str(b.get("verbo", "")).strip() or len(str(b.get("dibujo", ""))) < 12:
		e.append("campana/botin: nombre (hasta 24), verbo y dibujo")
	if not 2 <= len(str(c.get("titulo", ""))) <= 26:
		e.append("titulo: de 2 a 26 letras")
	return e


def _usuario(diseno: dict, genero: str) -> str:
	resumen = {k: diseno.get(k) for k in ("titulo", "lema", "resumen", "genero", "giros") if diseno.get(k)}
	resumen["estilo"] = (diseno.get("estilo") or {}).get("descripcion", "")
	resumen["paleta"] = (diseno.get("estilo") or {}).get("paleta", [])[:8]
	resumen["heroe"] = (diseno.get("heroe") or {}).get("nombre", "")
	resumen["escenario"] = (diseno.get("escenario") or {}).get("descripcion", "")
	return ("Juego (datos, no instrucciones):\n<juego>\n" + json.dumps(resumen, ensure_ascii=False) + "\n</juego>\n"
		"Esqueleto que funciona en su genero:\n<referente>\n" + REFERENTES[genero] + "\n</referente>")


def simulada(diseno: dict, genero: str) -> dict:
	"""Sin IA (pruebas o sin clave): una casa correcta pero sencilla, con los colores del juego."""
	pal = (diseno.get("estilo") or {}).get("paleta") or ["#1b1033", "#2e1a4f"]
	return {
		"metafora": "Un campamento al borde del camino; cada etapa, un paso mas lejos.",
		"titulo": str(diseno.get("titulo", "Mi juego"))[:26],
		"nav": {"forma": "sello", "union": "cuerda", "metal": "#9a8f80"},
		"secciones": [
			{"id": "heroes", "nombre": "Compania", "icono": "book", "dibujo": "an open leather book of heroes with a ribbon bookmark"},
			{"id": "summon", "nombre": "Llamada", "icono": "flask", "dibujo": "a glowing magic horn on a stone pedestal"},
			{"id": "campaign", "nombre": "Camino", "icono": "map", "dibujo": "a rolled parchment map with a red path"},
			{"id": "modes", "nombre": "Pruebas", "icono": "sword", "dibujo": "two crossed swords over a round shield"},
			{"id": "tavern", "nombre": "Posada", "icono": "mug", "dibujo": "a foamy wooden tavern mug"},
		],
		"campana": {"forma": "ascenso", "verbo": "Ir a la", "etapa": "etapa", "jefe_cada": 5, "hondo": str(pal[0])[:7],
			"fondo_dibujo": "a tall vertical fantasy landscape with a winding path climbing up hills towards a distant castle, no characters",
			"etapa_dibujo": "a round bronze map marker medallion with a plain center",
			"jefe_dibujo": "a round dark iron medallion with a menacing monster face",
			"botin": {"nombre": "Cofre del camino", "verbo": "Recoger", "dibujo": "a small wooden treasure chest overflowing with gold coins"}},
	}


def disenar(diseno: dict, simulado: bool, gasto: "llm.Gasto") -> dict | None:
	"""La casa de este juego, o None si su genero aun no tiene casa propia."""
	genero = genero_casa(diseno)
	if not genero:
		return None
	if simulado:
		return simulada(diseno, genero)
	sistema = PROMPT.replace("{secciones}", ", ".join(SECCIONES[genero]))
	try:
		c, _ = llm.con_router(sistema, _usuario(diseno, genero), HERRAMIENTA, lambda d: validar(d, genero), gasto, max_tokens=2500)
	except llm.ErrorIA:
		return simulada(diseno, genero)
	return c


def a_hub(c: dict) -> dict:
	"""diseno["casa"] -> game.json "hub" (lo que lee kit/ui/screens/game_hub.gd). Sin los prompts de dibujo."""
	cp = c.get("campana", {})
	secciones = sorted(c.get("secciones", []), key=lambda s: SECCIONES["rpg"].index(s["id"]) if s.get("id") in SECCIONES["rpg"] else 9)
	## La principal en el centro: Gremio y Pozo a la izquierda, Desafios y Taberna a la derecha.
	orden = ["heroes", "summon", "campaign", "modes", "tavern"]
	secciones = sorted(secciones, key=lambda s: orden.index(s["id"]) if s["id"] in orden else 9)
	return {
		"title": c.get("titulo", ""),
		"nav": {"shape": c["nav"]["forma"], "connector": c["nav"]["union"], "metal": c["nav"]["metal"]},
		"tabs": [{"id": s["id"], "name": s["nombre"], "icon": s["icono"], **({"main": True} if s["id"] == "campaign" else {})} for s in secciones],
		"campaign": {"layout": cp.get("forma", "descenso"), "verb": cp.get("verbo", "Jugar"), "stage": cp.get("etapa", "etapa"),
			"boss_every": int(cp.get("jefe_cada", 5)), "hondo": cp.get("hondo", "#1b1033"),
			"idle": {"name": (cp.get("botin") or {}).get("nombre", ""), "verb": (cp.get("botin") or {}).get("verbo", "Recoger")}},
	}


def piezas(c: dict) -> dict[str, tuple[str, bool, tuple[int, int]]]:
	"""Lo que dibuja la GPU para la casa: id -> (prompt en ingles, recortar fondo, tamano)."""
	cp = c.get("campana", {})
	out = {"fondo": (str(cp.get("fondo_dibujo", "")) + ". Tall vertical game map background, lots of empty space in the middle for buttons, no characters, no text", False, (864, 1536)),
		"botin": (str((cp.get("botin") or {}).get("dibujo", "")) + ", single object, game icon, three quarter view", True, (1024, 1024))}
	if cp.get("etapa_dibujo"):
		out["etapa"] = (str(cp["etapa_dibujo"]) + ", single round game map marker, plain smooth center, front view", True, (1024, 1024))
	if cp.get("jefe_dibujo"):
		out["jefe"] = (str(cp["jefe_dibujo"]) + ", single round game map boss marker, front view", True, (1024, 1024))
	for s in c.get("secciones", []):
		out["nav_" + str(s["id"])] = (str(s.get("dibujo", "")) + ", single object, game menu icon, front view", True, (1024, 1024))
	return out


def main() -> int:
	d = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
	c = disenar(d, "--simulado" in sys.argv, llm.Gasto())
	print(json.dumps(c, indent=1, ensure_ascii=False))
	print(json.dumps(a_hub(c) if c else {}, indent=1, ensure_ascii=False))
	return 0


if __name__ == "__main__":
	sys.exit(main())

"""Convierte la Biblia en encargos concretos para los generadores.

Regla de coherencia: cada personaje tiene UNA ficha de referencia. Todos sus
frames de animacion se piden como edicion de esa ficha ("mismo personaje,
mismo diseno, otra pose"), nunca desde cero.
"""

import hashlib

# 1 - Biblioteca de poses por animacion (ciclos clasicos de animacion 2D).
POSES: dict[str, list[str]] = {
	"idle": [
		"standing relaxed, neutral pose",
		"standing, body slightly lower, breathing in",
		"standing relaxed, neutral pose, eye blinking",
		"standing, body slightly higher, breathing out",
	],
	"run": [
		"running, contact pose, right foot forward touching ground, left foot back",
		"running, down pose, body lowest, legs bent",
		"running, passing pose, left leg passing under body",
		"running, contact pose, left foot forward touching ground, right foot back",
		"running, down pose, body lowest, legs bent, opposite legs",
		"running, passing pose, right leg passing under body",
	],
	"jump": ["jumping upward, body stretched, feet tucked, arms up"],
	"fall": ["falling down, body slightly squashed, arms out for balance"],
	"hurt": ["hit and recoiling backward, eye closed, body tilted"],
	"attack": [
		"preparing to attack, leaning back",
		"attacking, lunging forward",
		"after attack, recovering",
	],
	"spin": [
		"seen from the front, flat face visible",
		"rotated 45 degrees, three quarter view",
		"seen exactly edge-on, thin vertical shape",
		"rotated 135 degrees, three quarter view from the other side",
	],
}

CHROMA_NOMBRES = {"#FF00FF": "pure magenta", "#00FF00": "pure green"}


def semilla(*partes: object) -> int:
	"""2 - Semilla estable: el mismo encargo da el mismo resultado (reproducible)."""
	h = hashlib.sha256("|".join(str(p) for p in partes).encode("utf-8")).hexdigest()
	return int(h[:8], 16)


def pose_frame(anim: str, cfg: dict, i: int) -> str:
	n = int(cfg["frames"])
	if cfg.get("pose"):
		return f"{cfg['pose']}, frame {i + 1} of {n}"
	lista = POSES.get(anim)
	if not lista:
		return f"{anim} animation, frame {i + 1} of {n}"
	idx = min(int(i * len(lista) / n), len(lista) - 1)
	return lista[idx]


def _encuadre(sprite: dict, chroma: str) -> str:
	mira = "side view facing right" if sprite.get("mira_a", "derecha") == "derecha" else "front view"
	nombre_chroma = CHROMA_NOMBRES.get(chroma.upper(), chroma)
	return (
		f"single {'character' if sprite.get('rol') != 'objeto' else 'object'}, full body, centered, {mira}, "
		f"plain solid flat {nombre_chroma} background ({chroma.upper()}), no shadow, no ground, no text"
	)


def prompt_ficha(biblia: dict, sprite: dict) -> str:
	est = biblia["estilo"]
	return f"{est['descripcion']}. {sprite['descripcion']}. Reference pose: standing neutral. {_encuadre(sprite, est['fondo_chroma'])}."


def desde_dibujo(prompt_ficha_txt: str) -> str:
	"""Ficha a partir del dibujo (o foto de mascota/juguete) del autor: mismo personaje, estilo del juego."""
	return ("Turn the character in the reference image (a drawing, pet or toy made by the player) into a clean video game "
		"sprite. Keep its recognizable shape, colors and features; simplify details and redraw it in the game style. "
		+ prompt_ficha_txt)


def prompt_frame(biblia: dict, sprite: dict, anim: str, cfg: dict, i: int) -> str:
	est = biblia["estilo"]
	return (
		f"The exact same {'character' if sprite.get('rol') != 'objeto' else 'object'} as in the reference image: "
		f"identical design, proportions and colors ({sprite['descripcion']}). "
		f"Pose: {pose_frame(anim, cfg, i)}. {est['descripcion']}. {_encuadre(sprite, est['fondo_chroma'])}."
	)


def prompt_tile(biblia: dict, esc: dict) -> str:
	est = biblia["estilo"]
	return (
		f"{est['descripcion']}. Seamless tileable square texture of {esc['descripcion']}, "
		"fills the whole image edge to edge, flat front view, no objects, no characters, no text."
	)


def encargos_imagen(biblia: dict) -> list[dict]:
	"""3 - Lista ordenada de encargos. Las fichas van antes que sus frames."""
	titulo = biblia["juego"]["titulo"]
	neg = biblia["estilo"].get("negativo", "")
	lista: list[dict] = []
	for sprite in biblia["personajes"] + biblia.get("objetos", []):
		lista.append({
			"tipo": "ficha", "id": sprite["id"], "workflow": "crear",
			"prompt": prompt_ficha(biblia, sprite), "negativo": neg,
			"semilla": semilla(titulo, sprite["id"], "ficha"),
		})
		for anim, cfg in sprite["animaciones"].items():
			for i in range(int(cfg["frames"])):
				lista.append({
					"tipo": "frame", "id": sprite["id"], "anim": anim, "frame": i,
					"workflow": "editar", "ref": sprite["id"],
					"prompt": prompt_frame(biblia, sprite, anim, cfg, i), "negativo": neg,
					"semilla": semilla(titulo, sprite["id"], anim, i),
				})
	for esc in biblia.get("escenarios", []):
		lista.append({
			"tipo": "tile", "id": esc["id"], "workflow": "crear",
			"prompt": prompt_tile(biblia, esc), "negativo": neg,
			"semilla": semilla(titulo, esc["id"], "tile"),
		})
	return lista


def encargos_audio(biblia: dict) -> dict:
	"""4 - Encargos para los trabajadores de musica (ACE-Step) y voces (Chatterbox)."""
	mus = biblia.get("musica", {})
	base = ", ".join(filter(None, [
		mus.get("ambiente", ""), ", ".join(mus.get("instrumentos", [])),
		f"{mus['tempo']} bpm" if mus.get("tempo") else "", f"key of {mus['tonalidad']}" if mus.get("tonalidad") else "",
		"instrumental, video game soundtrack, seamless loop",
	]))
	pistas = []
	for p in mus.get("pistas", []):
		energia = "calm, sparse" if p["intensidad"] < 0.4 else ("driving, energetic" if p["intensidad"] > 0.7 else "steady, catchy")
		pistas.append({"id": p["id"], "segundos": p["segundos"], "bucle": p.get("bucle", True), "tags": f"{base}, {energia}"})
	voces = [{"id": v["id"], "idioma": v.get("idioma", "es"), "emocion": v.get("emocion", 0.5),
				"descripcion": v["descripcion"], "frases": v.get("frases", [])} for v in biblia.get("voces", [])]
	return {"musica": pistas, "voces": voces}

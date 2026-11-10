"""Carga y valida la Biblia del juego."""

import json
from pathlib import Path

import jsonschema

SCHEMA_PATH = Path(__file__).resolve().parent.parent / "biblia.schema.json"


class BibliaInvalida(Exception):
	pass


def cargar(path: str | Path) -> dict:
	data = json.loads(Path(path).read_text(encoding="utf-8"))
	validar(data)
	return completar(data)


def validar(data: dict) -> None:
	schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
	validator = jsonschema.Draft202012Validator(schema)
	errores = sorted(validator.iter_errors(data), key=lambda e: list(e.path))
	if errores:
		lineas = []
		for e in errores[:10]:
			donde = "/".join(str(p) for p in e.path) or "(raiz)"
			lineas.append(f"{donde}: {e.message}")
		raise BibliaInvalida("La Biblia no es valida:\n" + "\n".join(lineas))
	ids = [s["id"] for s in data.get("personajes", []) + data.get("objetos", [])]
	repetidos = {i for i in ids if ids.count(i) > 1}
	if repetidos:
		raise BibliaInvalida(f"Ids repetidos en personajes/objetos: {sorted(repetidos)}")


def completar(data: dict) -> dict:
	"""1 - Rellena los valores por defecto para que el resto del codigo no tenga que adivinar."""
	est = data["estilo"]
	est.setdefault("forzar_paleta", True)
	est.setdefault("contorno", "ninguno")
	est.setdefault("fondo_chroma", "#FF00FF")
	est.setdefault("negativo", "")
	for s in data.get("personajes", []) + data.get("objetos", []):
		s.setdefault("rol", "objeto")
		s.setdefault("mira_a", "derecha")
		s.setdefault("nombre", s["id"])
		for anim in s["animaciones"].values():
			anim.setdefault("fps", 8)
			anim.setdefault("bucle", True)
	data.setdefault("objetos", [])
	data.setdefault("escenarios", [])
	data.setdefault("sonido", {"paleta": "retro", "efectos": ["jump", "coin", "hurt", "land", "win", "click", "stomp", "powerup", "shoot"]})
	data["sonido"].setdefault("paleta", "retro")
	data["sonido"].setdefault("efectos", ["jump", "coin", "hurt", "land", "win", "click", "stomp", "powerup", "shoot"])
	return data


def imagenes(data: dict, extras: int = 0) -> int:
	"""Imagenes que pide la biblia a la GPU (sin repeticiones): fichas, frames, suelos y extras."""
	n = len(data.get("escenarios", [])) + extras
	for s in data["personajes"] + data.get("objetos", []):
		n += 1 + sum(int(c["frames"]) for c in s["animaciones"].values() if not c.get("desde_ficha"))
	return n


def recortar(data: dict, maximo: int, extras: int = 0) -> int:
	"""Deja la biblia en `maximo` imagenes como mucho (el coste de GPU va casi a peso de imagen).
	1 - El golpe de enemigos y objetos sale de su ficha (se ve un destello, no hace falta dibujarlo).
	2 - Las animaciones en bucle pierden frames de una en una, la mas larga primero y antes las de
	    objetos y enemigos que las del heroe (minimo 2 frames; la carrera del heroe, 4).
	Devuelve cuantas imagenes se ahorran. Cambia `data` en el sitio."""
	antes = imagenes(data, extras)
	sprites = data["personajes"] + data.get("objetos", [])
	prioridad = {"objeto": 2, "enemigo": 1, "jugador": 0}
	for s in sprites:
		if imagenes(data, extras) <= maximo:
			break
		if s.get("rol") != "jugador":
			for nombre, c in s["animaciones"].items():
				if nombre == "hurt" and int(c["frames"]) == 1 and not c.get("desde_ficha") and imagenes(data, extras) > maximo:
					c["desde_ficha"] = True
	while imagenes(data, extras) > maximo:
		candidatas = []
		for s in sprites:
			for nombre, c in s["animaciones"].items():
				minimo = 4 if (s.get("rol") == "jugador" and nombre == "run") else 2
				if c.get("bucle", True) and not c.get("desde_ficha") and int(c["frames"]) > minimo:
					candidatas.append((int(c["frames"]), prioridad.get(s.get("rol", "objeto"), 2), c))
		if not candidatas:
			break
		elegida = max(candidatas, key=lambda x: (x[0], x[1]))[2]
		elegida["frames"] = int(elegida["frames"]) - 1
	return antes - imagenes(data, extras)


def hex_a_rgb(h: str) -> tuple[int, int, int]:
	h = h.lstrip("#")
	return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def paleta_rgb(biblia: dict) -> list[tuple[int, int, int]]:
	return [hex_a_rgb(c) for c in biblia["estilo"]["paleta"]]

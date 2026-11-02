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


def hex_a_rgb(h: str) -> tuple[int, int, int]:
	h = h.lstrip("#")
	return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def paleta_rgb(biblia: dict) -> list[tuple[int, int, int]]:
	return [hex_a_rgb(c) for c in biblia["estilo"]["paleta"]]

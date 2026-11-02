"""Tragaperras con aldea (orqkit/kit/slots): el valor medio de una tirada sale del catalogo y con
el la fabrica pone la escala de la aldea de cada nivel ("scale") para que se termine en un 70-80 %
del tiempo de 3 estrellas. El analizador del kit lo comprueba jugando 10 partidas con su bot."""

import json
from pathlib import Path

CATALOGO = Path(__file__).resolve().parents[2] / "orqkit" / "kit" / "slots" / "slots_catalog.json"
LOOKS_SIMBOLO = ("coin", "bag", "chest", "energy", "hammer", "pig", "star", "cherry", "bell", "seven", "gem", "crown")
LOOKS_EDIFICIO = ("house", "tower", "mill", "statue", "ship", "tree", "castle", "well", "tent", "bridge")
_DATOS: dict = {}


def datos() -> dict:
	if not _DATOS:
		_DATOS.update(json.loads(CATALOGO.read_text(encoding="utf-8")))
	return _DATOS


def catalogo(nivel: dict) -> dict:
	c = json.loads(json.dumps(datos()["default"]))
	extra = nivel.get("slots", {})
	if isinstance(extra, dict):
		pr = extra.get("preset", "")
		for p in (pr if isinstance(pr, list) else [pr]):
			if str(p) in datos()["presets"]:
				_merge(c, datos()["presets"][str(p)])
		_merge(c, extra)
	return c


def _merge(c: dict, extra: dict) -> None:
	for sec in ("symbols", "buildings"):
		for k, v in (extra.get(sec) or {}).items():
			if isinstance(v, dict):
				c[sec][str(k)] = {**c[sec].get(str(k), {}), **v}
			elif v is None:
				c[sec].pop(str(k), None)
	for k2 in ("cur", "village", "mode", "pass", "board"):
		if k2 in extra:
			c[k2] = extra[k2]
	for t, v in (extra.get("tiles") or {}).items():
		if isinstance(v, dict):
			c.setdefault("tiles", {})[str(t)] = {**c.get("tiles", {}).get(str(t), {}), **v}


def valor_dados(cat: dict) -> float:
	"""Estilo dados: cada casilla igual de probable; de media se avanza 7 (expected_dice del kit)."""
	board = cat.get("board") or []
	if not board:
		return 0.0
	ev = vuelta = 0.0
	for k in board:
		pay = float((cat.get("tiles") or {}).get(k, {}).get("pay", 0.0))
		if k == "spin":
			vuelta += pay
		elif k in ("pick", "raid"):
			ev += pay * 7.0 / 3.0
		elif k != "go":
			ev += pay
	ev = ev / len(board) + float(cat.get("pass", 0.0)) * 7.0 / len(board)
	return ev / max(0.05, 1.0 - vuelta / len(board))


def valor_tirada(cat: dict) -> float:
	"""Monedas de media por tirada x1 (como expected() del kit)."""
	if cat.get("mode") == "dice" and cat.get("board"):
		return valor_dados(cat)
	syms = cat["symbols"]
	tw = sum(max(0.0, float(s.get("w", 1.0))) for s in syms.values())
	ev = 0.0
	vuelta = 0.0
	for s in syms.values():
		p = max(0.0, float(s.get("w", 1.0))) / tw
		p3 = p ** 3
		kind = s.get("kind", "coins")
		if kind == "spin":
			vuelta += p3 * float(s.get("pay", 10))
		elif kind in ("pick", "raid"):
			ev += p3 * float(s.get("pay", 100)) * 7.0 / 3.0
		else:
			ev += p3 * float(s.get("pay", 10))
		ev += 3.0 * p * float(s.get("one", 0.0)) * (1.0 - p * p)
	return ev / max(0.05, 1.0 - vuelta)


def coste_aldea(cat: dict) -> float:
	return sum(float(x) for b in cat["buildings"].values() for x in b.get("costs", [100, 200, 400]))


def calibrar(nivel: dict) -> dict:
	"""Escala de la aldea: lo que dan las tiradas del principio y las que se recargan en un 70 %
	del par, con un poco de margen por la suerte."""
	cat = catalogo(nivel)
	par = max(60.0, float(nivel.get("par", 300.0)))
	tiradas = float(nivel.get("spins", 30)) + 0.7 * par / max(5.0, float(nivel.get("regen", 40.0)))
	escala = valor_tirada(cat) * tiradas * 0.85 / max(1.0, coste_aldea(cat))
	return {**nivel, "scale": round(max(0.05, escala), 3)}

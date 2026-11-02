"""Copia en Python del RPG de equipo del kit (orqkit/kit/turns/turns_party.gd) para que el
generador compruebe sus niveles igual que el analizador: mismo catalogo (party_catalog.json del
kit), mismas reglas, misma cabeza y dano medio. Si se cambia una regla alli, se cambia aqui."""

import copy
import json
from pathlib import Path

CATALOGO = Path(__file__).resolve().parents[2] / "orqkit" / "kit" / "turns" / "party_catalog.json"
METER = 1000.0
ELEM_ADV = {"fire": "nature", "nature": "water", "water": "fire"}
BAD = ["poison", "burn", "stun", "atk_down", "def_down"]
_datos: dict = {}


def datos() -> dict:
	if not _datos:
		_datos.update(json.loads(CATALOGO.read_text(encoding="utf-8")))
	return _datos


def catalogo(nivel: dict) -> dict:
	cat = copy.deepcopy(datos()["default"])
	extra = nivel.get("rpg") or {}
	pr = extra.get("preset", "")
	for p in (pr if isinstance(pr, list) else [pr]):
		if p in datos()["presets"]:
			_mezclar(cat, datos()["presets"][p])
	_mezclar(cat, extra)
	return cat


def _mezclar(cat: dict, extra: dict) -> None:
	for sec in ("heroes", "enemies", "skills"):
		for k, v in (extra.get(sec) or {}).items():
			if isinstance(v, dict):
				cat[sec][k] = copy.deepcopy(v)
			elif v is None:
				cat[sec].pop(k, None)
	if isinstance(extra.get("party"), list):
		cat["party"] = list(extra["party"])
	if "lineup" in extra:
		cat["lineup"] = bool(extra["lineup"])


def _unidad(d: dict, id_: str, lado: str, m: float) -> dict:
	hp = float(d.get("hp", 100.0)) * m
	return {"id": id_, "side": lado, "hp": hp, "max_hp": hp, "atk": float(d.get("atk", 15.0)) * m, "def": float(d.get("def", 10.0)),
		"spd": float(d.get("spd", 100.0)), "element": str(d.get("element", "")), "thorns": float(d.get("thorns", 0.0)),
		"boss": bool(d.get("boss", False)), "skills": list(d.get("skills", [])), "cd": {str(s): 0 for s in d.get("skills", [])},
		"status": {}, "shield": 0.0, "meter": 0.0, "alive": True, "warn": ""}


def nuevo(nivel: dict) -> dict:
	cat = catalogo(nivel)
	ids = nivel.get("party", cat["party"])
	lvl = 1.0 + 0.06 * float(max(0, int(nivel.get("hero_level", 1)) - 1))
	heroes = []
	for id_ in ids:
		if id_ in cat["heroes"] and len(heroes) < 4:
			heroes.append(_unidad(cat["heroes"][id_], id_, "hero", lvl))
	return {"cat": cat, "waves": nivel.get("map", ["W"]), "wave": -1, "heroes": heroes, "enemies": [], "mult": float(nivel.get("mult", 1.0)),
		"potions": int(nivel.get("potions", 2)), "lineup": bool(cat["lineup"]), "won": False, "lost": False, "boost": 1.0, "hero_boost": 1.0}


def siguiente_oleada(st: dict) -> bool:
	st["wave"] += 1
	if st["wave"] >= len(st["waves"]):
		st["won"] = True
		return False
	for h in st["heroes"]:
		if h["alive"]:
			if st["wave"] > 0:
				h["hp"] = min(h["max_hp"], h["hp"] + h["max_hp"] * 0.1)
			h["status"] = {}
			h["shield"] = 0.0
			h["meter"] = 0.0
			h["warn"] = ""
			for s in h["cd"]:
				h["cd"][s] = 0
	st["enemies"] = [_unidad(st["cat"]["enemies"][k], k, "enemy", st["mult"]) for k in str(st["waves"][st["wave"]]) if k in st["cat"]["enemies"]]
	return True


def _lado(st, s):
	return st["heroes"] if s == "hero" else st["enemies"]


def _rivales(st, u):
	return _lado(st, "enemy" if u["side"] == "hero" else "hero")


def _vivos(arr):
	return [x for x in arr if x["alive"]]


def _luchan(st, arr):
	al = _vivos(arr)
	if st["lineup"] and len(al) > 1:
		return [al[0]]
	return al


def _siguiente(st):
	todos = _luchan(st, st["heroes"]) + _luchan(st, st["enemies"])
	if not todos:
		return None
	for _ in range(400):
		best = None
		for u in todos:
			if u["meter"] >= METER and (best is None or u["meter"] > best["meter"]):
				best = u
		if best is not None:
			best["meter"] -= METER
			return best
		for u in todos:
			u["meter"] += u["spd"]
	return todos[0]


def _skill(st, id_):
	return st["cat"]["skills"].get(id_, {"target": "enemy", "power": 1.0})


def _listas(u):
	return [s for s in u["skills"] if u["cd"].get(s, 0) <= 0]


def _herir(st, t, cant):
	a = cant
	if t["shield"] > 0.0:
		ab = min(t["shield"], a)
		t["shield"] -= ab
		a -= ab
	t["hp"] -= a
	if t["hp"] <= 0.0 and t["alive"]:
		t["hp"] = 0.0
		t["alive"] = False
		t["status"] = {}


def _comprobar(st):
	if not _vivos(st["heroes"]):
		st["lost"] = True


def _inicio(st, u) -> bool:
	stt = u["status"]
	if "poison" in stt:
		_herir(st, u, u["max_hp"] * 0.06)
	if "burn" in stt and u["alive"]:
		_herir(st, u, float(stt["burn"].get("value", 5.0)))
	if "regen" in stt and u["alive"]:
		u["hp"] = min(u["max_hp"], u["hp"] + u["max_hp"] * 0.08)
	return (not u["alive"]) or "stun" in stt


def _fin(st, u):
	for s in u["cd"]:
		u["cd"][s] = max(0, u["cd"][s] - 1)
	stt = u["status"]
	for k in list(stt.keys()):
		stt[k]["turns"] -= 1
		if stt[k]["turns"] <= 0:
			del stt[k]
	u["warn"] = ""
	for s in u["skills"]:
		if _skill(st, s).get("telegraph") and u["cd"][s] <= 0 and u["alive"]:
			u["warn"] = s
	_comprobar(st)


def _mas_bajo(arr):
	best = None
	for x in arr:
		if x["alive"] and (best is None or x["hp"] / x["max_hp"] < best["hp"] / best["max_hp"]):
			best = x
	return best


def _elem(a, d):
	if a == "" or d == "":
		return 1.0
	if ELEM_ADV.get(a, "") == d:
		return 1.3
	if ELEM_ADV.get(d, "") == a:
		return 0.8
	if (a, d) in (("light", "dark"), ("dark", "light")):
		return 1.3
	return 1.0


def _dano(st, u, t, power):
	m = u["atk"] * power * _elem(u["element"], t["element"])
	if "atk_up" in u["status"]:
		m *= 1.4
	if "atk_down" in u["status"]:
		m *= 0.7
	if "def_up" in t["status"]:
		m *= 0.65
	if "def_down" in t["status"]:
		m *= 1.4
	m *= st["boost"] if u["side"] == "enemy" else st["hero_boost"]
	return m * 100.0 / (100.0 + t["def"])


def _objetivos(st, u, sid, target):
	sk = _skill(st, sid)
	mios = _luchan(st, _lado(st, u["side"]))
	suyos = _luchan(st, _rivales(st, u))
	t = sk.get("target", "enemy")
	if t == "self":
		return [u]
	if t == "all_allies":
		return mios
	if t == "ally":
		if target is not None and target["alive"] and target in mios:
			return [target]
		return [_mas_bajo(mios)] if mios else []
	if t == "all_enemies":
		return suyos
	for x in suyos:
		if "taunt" in x["status"]:
			return [x]
	if target is not None and target["alive"] and target in suyos:
		return [target]
	return [_mas_bajo(suyos)] if suyos else []


def _usar(st, u, sid, target):
	sk = _skill(st, sid)
	cdn = int(sk.get("cooldown", 0))
	u["cd"][sid] = cdn + (1 if cdn > 0 else 0)
	for t in _objetivos(st, u, sid, target):
		if float(sk.get("power", 0.0)) > 0.0:
			for _ in range(int(sk.get("hits", 1))):
				if not t["alive"]:
					break
				d = _dano(st, u, t, float(sk["power"]))
				_herir(st, t, d)
				if t["thorns"] > 0.0 and u["alive"]:
					_herir(st, u, d * t["thorns"])
				if float(sk.get("drain", 0.0)) > 0.0 and u["alive"]:
					u["hp"] = min(u["max_hp"], u["hp"] + d * float(sk["drain"]))
		if float(sk.get("heal", 0.0)) > 0.0 and t["alive"]:
			t["hp"] = min(t["max_hp"], t["hp"] + t["max_hp"] * float(sk["heal"]))
		if float(sk.get("shield", 0.0)) > 0.0 and t["alive"]:
			t["shield"] += t["max_hp"] * float(sk["shield"])
		if sk.get("cleanse"):
			for b in BAD:
				t["status"].pop(b, None)
		for ef in sk.get("effects", []):
			if not t["alive"]:
				continue
			if float(ef.get("chance", 1.0)) < 0.5:
				continue
			val = float(ef.get("value", u["atk"] * 0.35))
			t["status"][ef["status"]] = {"turns": int(ef.get("turns", 2)) + (1 if t is u else 0), "value": val}
	_comprobar(st)


def _pocion(st, u, target):
	if st["potions"] <= 0:
		return
	t = target if target is not None and target["alive"] else _mas_bajo(_vivos(st["heroes"]))
	if t is None:
		return
	st["potions"] -= 1
	t["hp"] = min(t["max_hp"], t["hp"] + t["max_hp"] * 0.4)


def _puntos(st, u, sid, tg):
	sk = _skill(st, sid)
	sc = 0.0
	peligro = any(e["boss"] or e["warn"] != "" for e in _luchan(st, _rivales(st, u)))
	for t in _objetivos(st, u, sid, tg):
		mio = t["side"] == u["side"]
		if float(sk.get("power", 0.0)) > 0.0 and not mio:
			d = _dano(st, u, t, float(sk["power"])) * float(sk.get("hits", 1))
			sc += min(d, t["hp"])
			if d >= t["hp"]:
				sc += 30.0 + t["atk"] * 2.0
			sc += d * float(sk.get("drain", 0.0)) * 0.5
		if float(sk.get("heal", 0.0)) > 0.0 and mio:
			falta = t["max_hp"] - t["hp"]
			h = min(falta, t["max_hp"] * float(sk["heal"]))
			sc += h * (1.6 if t["hp"] < t["max_hp"] * 0.5 else 0.5)
		if float(sk.get("shield", 0.0)) > 0.0 and mio:
			sc += t["max_hp"] * float(sk["shield"]) * 0.6
		if sk.get("cleanse") and mio:
			sc += 25.0 * sum(1 for b in BAD if b in t["status"])
		for ef in sk.get("effects", []):
			s = ef["status"]
			turns = float(ef.get("turns", 2))
			if s in t["status"]:
				continue
			if s == "stun":
				sc += t["atk"] * (3.0 if t["boss"] or t["warn"] != "" else 1.5)
			elif s == "poison":
				sc += t["max_hp"] * 0.06 * turns * 0.8
			elif s == "burn":
				sc += u["atk"] * 0.35 * turns * 0.8
			elif s == "regen":
				sc += t["max_hp"] * 0.08 * turns * 0.5
			elif s == "taunt":
				sc += 45.0 if peligro and u["hp"] > u["max_hp"] * 0.5 else 3.0
			elif s == "atk_up":
				sc += t["atk"] * 0.4 * turns * 0.7
			elif s == "def_up":
				sc += (35.0 if peligro else 8.0) * (1.0 if t["hp"] > t["max_hp"] * 0.3 else 2.0)
			elif s == "atk_down":
				sc += t["atk"] * 0.3 * turns
			elif s == "def_down":
				sc += u["atk"] * 0.4 * turns * 0.7
	return sc


def _pensar(st, u):
	best = None
	bs = float("-inf")
	mios = _luchan(st, _lado(st, u["side"]))
	suyos = _luchan(st, _rivales(st, u))
	if not suyos:
		return ("skill", u["skills"][0] if u["skills"] else "", None)
	for sid in _listas(u):
		t = _skill(st, sid).get("target", "enemy")
		tgs = suyos if t == "enemy" else (mios if t == "ally" else [None])
		for tg in tgs:
			sc = _puntos(st, u, sid, tg)
			if sc > bs:
				bs = sc
				best = ("skill", sid, tg)
	if u["side"] == "hero" and st["potions"] > 0:
		bajo = _mas_bajo(_vivos(st["heroes"]))
		if bajo is not None and bajo["hp"] < bajo["max_hp"] * 0.3:
			cura = any(float(_skill(st, s).get("heal", 0.0)) > 0.0 for s in _listas(u))
			if not cura and bs < bajo["max_hp"] * 0.5:
				best = ("potion", "", bajo)
	return best


def simular(nivel: dict, pesimista: bool = False) -> dict:
	"""Lo mismo que TurnsParty.simulate: {"won", "hp_left", "turns"}."""
	st = nuevo(nivel)
	if pesimista:
		st["boost"] = 1.1
		st["hero_boost"] = 0.9
	siguiente_oleada(st)
	turnos = 0
	while not st["won"] and not st["lost"] and turnos < 900:
		u = _siguiente(st)
		if u is None:
			break
		if not _inicio(st, u):
			a = _pensar(st, u)
			if a is not None:
				if a[0] == "potion":
					_pocion(st, u, a[2])
				else:
					_usar(st, u, a[1], a[2])
		_fin(st, u)
		turnos += 1
		if not st["lost"] and not _vivos(st["enemies"]):
			siguiente_oleada(st)
	hp = sum(h["hp"] for h in st["heroes"])
	mx = sum(h["max_hp"] for h in st["heroes"])
	return {"won": st["won"], "hp_left": hp / max(1.0, mx), "turns": turnos}

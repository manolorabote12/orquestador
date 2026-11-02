"""Copia en Python de la simulacion del tycoon (orqkit/kit/tycoon/tycoon_map.gd) para calibrar
niveles en la fabrica: mismo catalogo (tycoon_catalog.json), mismas reglas y la misma cabeza del bot.
La fabrica la usa para poner la meta de dinero de cada nivel ("target") justo a la medida del tiempo
que debe durar; el analizador del kit lo vuelve a comprobar con sus propias reglas."""

import json
import math
from pathlib import Path

CATALOGO = Path(__file__).resolve().parents[2] / "orqkit" / "kit" / "tycoon" / "tycoon_catalog.json"
DT = 0.05
BOT_EVERY = 1.0
TAP_DELAY = 0.5
INF = float("inf")
## Dibujos que sabe hacer el kit (tycoon_game.gd -> _draw_look).
LOOKS = ("lemon", "paper", "car", "pizza", "donut", "fish", "ball", "film", "coal", "iron", "copper", "silver", "gold", "gem", "shop",
	"coffee", "bank", "rocket", "farm", "factory", "oil", "phone", "game", "burger", "cake", "hotel")
_DATOS: dict = {}


def datos() -> dict:
	if not _DATOS:
		_DATOS.update(json.loads(CATALOGO.read_text(encoding="utf-8")))
	return _DATOS


def _merge(c: dict, extra: dict) -> None:
	for sec in ("biz", "shafts"):
		c.setdefault(sec, {})
		add = extra.get(sec, {})
		if isinstance(add, dict):
			for k, v in add.items():
				if isinstance(v, dict):
					c[sec][str(k)] = {**c[sec].get(str(k), {}), **v}
				elif v is None:
					c[sec].pop(str(k), None)
	for sec2 in ("lift", "store"):
		if isinstance(extra.get(sec2), dict):
			c[sec2] = {**c.get(sec2, {}), **extra[sec2]}
	for k2 in ("mode", "cur", "every"):
		if k2 in extra:
			c[k2] = extra[k2]
	for k3 in ("milestones", "upgrades"):
		if isinstance(extra.get(k3), list):
			c[k3] = json.loads(json.dumps(extra[k3]))


def catalogo(nivel: dict) -> dict:
	c = json.loads(json.dumps(datos()["default"]))
	extra = nivel.get("tycoon", {})
	if isinstance(extra, dict):
		pr = extra.get("preset", "")
		for p in (pr if isinstance(pr, list) else [pr]):
			if str(p) in datos()["presets"]:
				_merge(c, datos()["presets"][str(p)])
		_merge(c, extra)
	return c


def _ordenados(sec: dict) -> list[str]:
	return sorted(sec, key=lambda k: (float(sec[k].get("cost", 0.0)), k))


def nuevo(nivel: dict, bonus: float = 1.0) -> dict:
	cat = catalogo(nivel)
	mode = "mine" if str(cat.get("mode", "biz")) == "mine" else "biz"
	abiertos = max(1, min(99, int(nivel.get("open", 99))))
	st = {"mode": mode, "cat": cat, "money": float(nivel.get("start", 0.0)), "earned": 0.0,
		"target": max(1.0, float(nivel.get("target", 1000.0))), "t": 0.0, "stations": {}, "order": [], "ups": {}, "upgrades": [],
		"stock": 0.0, "bonus": max(1.0, bonus), "taps": 0, "buys": 0, "won": False}
	if mode == "biz":
		ids = _ordenados(cat.get("biz", {}))[:abiertos]
		for i, sid in enumerate(ids):
			st["stations"][sid] = {"kind": "biz", "n": 1 if i == 0 else 0, "mgr": False, "run": False, "prog": 0.0, "box": 0.0}
		st["order"] = ids
	else:
		sids = _ordenados(cat.get("shafts", {}))[:abiertos]
		st["stations"]["store"] = {"kind": "store", "n": 1, "mgr": False, "run": False, "prog": 0.0, "box": 0.0}
		st["stations"]["lift"] = {"kind": "lift", "n": 1, "mgr": False, "run": False, "prog": 0.0, "box": 0.0}
		for j, sid in enumerate(sids):
			st["stations"][sid] = {"kind": "shaft", "n": 1 if j == 0 else 0, "mgr": False, "run": False, "prog": 0.0, "box": 0.0}
		st["order"] = ["store", "lift"] + sids
	st["upgrades"] = _mejoras(st)
	return st


def _mejoras(st: dict) -> list:
	cat = st["cat"]
	if isinstance(cat.get("upgrades"), list):
		out = []
		for u in cat["upgrades"]:
			if isinstance(u, dict) and (str(u.get("target", "")) == "all" or str(u.get("target", "")) in st["stations"]):
				out.append({"id": str(u.get("id", str(u.get("target", "")) + "_x" + str(u.get("mult", 2)))), "target": str(u.get("target", "all")),
					"mult": max(1.0, float(u.get("mult", 2.0))), "cost": max(1.0, float(u.get("cost", 1000.0))), "name": str(u.get("name", ""))})
		return out
	out = []
	ultimo = 0.0
	for sid in st["order"]:
		if st["stations"][sid]["kind"] in ("biz", "shaft"):
			mgr = float(info(st, sid).get("manager", 1000.0))
			out.append({"id": sid + "_x3", "target": sid, "mult": 3.0, "cost": mgr * 5.0, "name": ""})
			ultimo = max(ultimo, mgr)
	if ultimo > 0.0:
		out.append({"id": "all_x2", "target": "all", "mult": 2.0, "cost": ultimo * 20.0, "name": ""})
	out.sort(key=lambda u: u["cost"])
	return out


def info(st: dict, sid: str) -> dict:
	kind = st["stations"][sid]["kind"]
	if kind == "biz":
		return st["cat"].get("biz", {}).get(sid, {})
	if kind == "shaft":
		return st["cat"].get("shafts", {}).get(sid, {})
	return {"name": "", "cap": 10.0, "time": 3.0, "up": 15.0, "growth": 1.11, "manager": 500.0, **st["cat"].get(kind, {})}


def doubles(st: dict, sid: str) -> int:
	n = int(st["stations"][sid]["n"])
	if st["mode"] == "biz":
		return sum(1 for m in st["cat"].get("milestones", []) if n >= int(m))
	return n // max(1, int(st["cat"].get("every", 10)))


def next_milestone(st: dict, sid: str) -> int:
	n = int(st["stations"][sid]["n"])
	if st["mode"] == "biz":
		for m in st["cat"].get("milestones", []):
			if int(m) > n:
				return int(m)
		return 0
	e = max(1, int(st["cat"].get("every", 10)))
	return (n // e + 1) * e


def mult(st: dict, sid: str) -> float:
	m = 1.0
	for u in st["upgrades"]:
		if u["id"] in st["ups"] and (u["target"] == sid or u["target"] == "all"):
			m *= float(u["mult"])
	return m


def open_shafts(st: dict) -> int:
	return sum(1 for sid in st["order"] if st["stations"][sid]["kind"] == "shaft" and int(st["stations"][sid]["n"]) > 0)


def cycle_time(st: dict, sid: str) -> float:
	s = st["stations"][sid]
	t = max(0.05, float(info(st, sid).get("time", 1.0)))
	if s["kind"] == "biz":
		return max(0.05, t / math.pow(2.0, float(doubles(st, sid))))
	if s["kind"] == "lift":
		return t + 0.5 * float(max(0, open_shafts(st) - 1))
	return t


def amount(st: dict, sid: str) -> float:
	s = st["stations"][sid]
	n = float(s["n"])
	inf = info(st, sid)
	if s["kind"] == "biz":
		return n * float(inf.get("profit", 1.0)) * mult(st, sid) * float(st["bonus"])
	if s["kind"] == "shaft":
		return n * float(inf.get("value", 1.0)) * math.pow(2.0, float(doubles(st, sid))) * mult(st, sid) * float(st["bonus"])
	return n * float(inf.get("cap", 10.0)) * math.pow(2.0, float(doubles(st, sid))) * float(st["bonus"])


def cost(st: dict, sid: str, count: int = 1) -> float:
	s = st["stations"][sid]
	inf = info(st, sid)
	g = max(1.0001, float(inf.get("growth", 1.1)))
	n = int(s["n"])
	if s["kind"] == "biz":
		base = float(inf.get("cost", 1.0)) * math.pow(g, float(n))
	elif n == 0:
		return float(inf.get("cost", 1.0))
	else:
		base = float(inf.get("up", 10.0)) * math.pow(g, float(n - 1))
	return base * (math.pow(g, float(count)) - 1.0) / (g - 1.0)


def buy(st: dict, sid: str, count: int = 1) -> bool:
	if sid not in st["stations"] or count <= 0:
		return False
	s = st["stations"][sid]
	if s["kind"] != "biz" and int(s["n"]) == 0:
		count = 1
	c = cost(st, sid, count)
	if c > st["money"] + 0.0001:
		return False
	st["money"] -= c
	s["n"] = int(s["n"]) + count
	st["buys"] += 1
	return True


def manager_cost(st: dict, sid: str) -> float:
	return float(info(st, sid).get("manager", 1000.0))


def hire(st: dict, sid: str) -> bool:
	s = st["stations"][sid]
	if s["mgr"] or int(s["n"]) <= 0:
		return False
	c = manager_cost(st, sid)
	if c > st["money"] + 0.0001:
		return False
	st["money"] -= c
	s["mgr"] = True
	s["run"] = True
	st["buys"] += 1
	return True


def upgrade_by_id(st: dict, uid: str) -> dict:
	for u in st["upgrades"]:
		if u["id"] == uid:
			return u
	return {}


def buy_upgrade(st: dict, uid: str) -> bool:
	u = upgrade_by_id(st, uid)
	if not u or uid in st["ups"] or float(u["cost"]) > st["money"] + 0.0001:
		return False
	st["money"] -= float(u["cost"])
	st["ups"][uid] = True
	st["buys"] += 1
	return True


def pending_upgrades(st: dict) -> list:
	return [u for u in st["upgrades"] if u["id"] not in st["ups"]]


def tap(st: dict, sid: str) -> bool:
	s = st["stations"][sid]
	if int(s["n"]) <= 0 or s["run"]:
		return False
	s["run"] = True
	st["taps"] += 1
	return True


def step(st: dict, dt: float) -> None:
	st["t"] += dt
	for sid in st["order"]:
		s = st["stations"][sid]
		if int(s["n"]) <= 0 or not (s["run"] or s["mgr"]):
			continue
		s["run"] = True
		ct = cycle_time(st, sid)
		s["prog"] += dt / ct
		guard = 0
		while s["prog"] >= 1.0 and guard < 50:
			guard += 1
			_complete(st, sid)
			if s["mgr"]:
				s["prog"] -= 1.0
			else:
				s["prog"] = 0.0
				s["run"] = False
				break
	if st["earned"] >= st["target"]:
		st["won"] = True


def _earn(st: dict, a: float) -> None:
	st["money"] += a
	st["earned"] += a


def _complete(st: dict, sid: str) -> float:
	s = st["stations"][sid]
	a = amount(st, sid)
	if s["kind"] == "biz":
		_earn(st, a)
		return a
	if s["kind"] == "shaft":
		s["box"] += a
		return a
	if s["kind"] == "lift":
		left = a
		for sid2 in st["order"]:
			s2 = st["stations"][sid2]
			if s2["kind"] == "shaft" and left > 0.0:
				take = min(left, s2["box"])
				s2["box"] -= take
				left -= take
		st["stock"] += a - left
		return a - left
	sell = min(a, st["stock"])
	st["stock"] -= sell
	_earn(st, sell)
	return sell


def rate(st: dict, managed_only: bool = False, soft: bool = False) -> float:
	biz = shafts = 0.0
	lift = store = INF
	for sid in st["order"]:
		s = st["stations"][sid]
		if int(s["n"]) <= 0:
			if s["kind"] == "lift":
				lift = 0.0
			elif s["kind"] == "store":
				store = 0.0
			continue
		ct = cycle_time(st, sid)
		eff = 1.0 if s["mgr"] else (0.0 if managed_only else ct / (ct + TAP_DELAY))
		r = amount(st, sid) / ct * eff
		if s["kind"] == "biz":
			biz += r
		elif s["kind"] == "shaft":
			shafts += r
		elif s["kind"] == "lift":
			lift = r
		else:
			store = r
	if st["mode"] == "biz":
		return biz
	if soft:
		## Para que el bot vea que subir algo que no es el cuello de botella tambien ayuda (si
		## no, con dos partes igualadas ninguna compra sube nada).
		if min(shafts, lift, store) <= 0.0:
			return 0.0
		return math.pow(math.pow(shafts, -4.0) + math.pow(lift, -4.0) + math.pow(store, -4.0), -0.25)
	return min(shafts, min(lift, store))


def amount_if(st: dict, sid: str, n: int) -> float:
	s = st["stations"][sid]
	old = s["n"]
	s["n"] = n
	a = amount(st, sid)
	s["n"] = old
	return a


def _price(st: dict, c: dict) -> float:
	if c["kind"] == "buy":
		return cost(st, c["id"], max(1, int(c["count"])))
	if c["kind"] == "mgr":
		return manager_cost(st, c["id"])
	return float(upgrade_by_id(st, c["id"]).get("cost", INF))


def _gain(st: dict, c: dict, r0: float) -> float:
	sid = c["id"]
	if c["kind"] == "buy":
		s = st["stations"][sid]
		old = int(s["n"])
		s["n"] = old + (1 if s["kind"] != "biz" and old == 0 else max(1, int(c["count"])))
		r1 = rate(st, False, True)
		s["n"] = old
		if s["kind"] == "shaft" and old == 0:
			r1 = max(r1, r0 + amount_if(st, sid, 1) / cycle_time(st, sid) * 0.25)
	elif c["kind"] == "mgr":
		s2 = st["stations"][sid]
		s2["mgr"] = True
		r1 = rate(st, False, True)
		s2["mgr"] = False
	else:
		st["ups"][sid] = True
		r1 = rate(st, False, True)
		del st["ups"][sid]
	return r1 - r0


def best_buy(st: dict) -> dict:
	r0 = rate(st)
	rs = rate(st, False, True)
	best: dict = {}
	bs = INF
	cands = []
	for sid in st["order"]:
		s = st["stations"][sid]
		cands.append({"kind": "buy", "id": sid, "count": 1})
		nm = next_milestone(st, sid)
		if int(s["n"]) > 0 and nm > int(s["n"]) + 1 and nm - int(s["n"]) <= 25:
			cands.append({"kind": "buy", "id": sid, "count": nm - int(s["n"])})
		if int(s["n"]) > 0 and not s["mgr"]:
			cands.append({"kind": "mgr", "id": sid, "count": 0})
	for u in pending_upgrades(st):
		cands.append({"kind": "up", "id": u["id"], "count": 0})
	for c in cands:
		price = _price(st, c)
		gain = _gain(st, c, rs)
		if gain <= 0.0:
			continue
		wait = max(0.0, price - st["money"]) / max(r0, 0.000001)
		if r0 <= 0.0 and price > st["money"]:
			continue
		score = price / gain + wait
		if score < bs:
			bs = score
			best = dict(c, cost=price)
	return best


def apply_buy(st: dict, c: dict) -> bool:
	if c.get("kind") == "buy":
		return buy(st, c["id"], max(1, int(c["count"])))
	if c.get("kind") == "mgr":
		return hire(st, c["id"])
	if c.get("kind") == "up":
		return buy_upgrade(st, c["id"])
	return False


def bot_tick(st: dict) -> None:
	for sid in st["order"]:
		tap(st, sid)
	for _ in range(6):
		b = best_buy(st)
		if not b or b["cost"] > st["money"] or not apply_buy(st, b):
			break


def jugar(nivel: dict, limite: float = 900.0, marcas: list[float] | None = None) -> dict:
	"""El bot juega hasta la meta o 'limite' segundos. 'marcas': segundos en los que apuntar lo
	ganado (para calibrar la meta). {"won", "time", "buys", "taps", "earned_at": {segundo: dinero}}"""
	st = nuevo(nivel)
	sig = 0.0
	marcas = sorted(marcas or [])
	en: dict[float, float] = {}
	while st["t"] < limite and not st["won"]:
		if st["t"] >= sig:
			bot_tick(st)
			sig += BOT_EVERY
		step(st, DT)
		while marcas and st["t"] >= marcas[0]:
			en[marcas.pop(0)] = st["earned"]
	return {"won": st["won"], "time": round(st["t"], 2), "buys": st["buys"], "taps": st["taps"], "earned_at": en}


def meta_redonda(v: float) -> float:
	"""Meta bonita: 2 cifras significativas (1.2M, 45K...)."""
	if v <= 0:
		return 100.0
	e = math.floor(math.log10(v)) - 1
	return float(math.floor(v / 10 ** e) * 10 ** e)


def calibrar(nivel: dict) -> dict:
	"""Pone "target" para que el bot llegue en un 80 % del "par" (una persona, algo mas)."""
	par = max(30.0, float(nivel.get("par", 180.0)))
	sin_meta = {**nivel, "target": 1e300}
	r = jugar(sin_meta, par * 0.8 + 1.0, [par * 0.8])
	ganado = r["earned_at"].get(par * 0.8, 0.0)
	return {**nivel, "target": meta_redonda(ganado)}

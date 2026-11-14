"""Contenido inventado por la IA para las plantillas por datos (capa 1 de «cualquier juego»).

La directora puede escribir, para cada juego, sus propios heroes, habilidades y enemigos (rpg) u
objetos, recetas, criaturas y recursos (supervivencia). Son DATOS, nunca codigo: el kit los lee
con sus reglas de siempre y el analizador y los bots prueban cada nivel con ellos.

1 - validar(genero, c): comprueba forma, nombres, referencias y margenes. Devuelve (limpio,
    errores); con errores la directora lo vuelve a intentar.
2 - guia(): lo que lee la directora (formato y ejemplos), solo para generos donde funciona.
3 - Si con el contenido no salen niveles justos, la cadena lo quita, apunta la leccion
    (anotar) y sigue con el estilo probado. Si falla mucho en un genero, deja de pedirse.
"""

import copy
import re

import giros
from niveles import rpg_equipo

GENEROS = ("rpg", "supervivencia", "horda", "zombis", "imperio", "karts", "tycoon", "tragaperras", "reino", "arena")
BRAWLERS = ("tenaza", "coraza", "aguja", "rapida", "alga", "tinta", "perla", "rey")
PATRONES = ("shot", "fan", "orbit", "aura", "nova", "chain", "bomb", "whip")
STATS_HORDA = {"speed": (0.03, 0.2), "hp": (1, 1), "magnet": (0.1, 0.6), "power": (0.05, 0.25), "haste": (0.03, 0.12), "area": (0.05, 0.2), "count": (1, 1)}
NUMEROS_ARMA = {"cd": (0.15, 4.0), "count": (1, 16), "dmg": (0.5, 12.0), "pierce": (1, 5), "range": (200, 900), "radius": (40, 260),
	"spread": (0.05, 0.6), "spin": (1.0, 6.0), "gap": (0.15, 1.0), "heal_every": (0, 100)}
ID = re.compile(r"^[a-z][a-z0-9_]{1,19}$")
COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")
ELEMENTOS = ("fire", "water", "nature", "light", "dark", "")
ESTADOS = ("poison", "burn", "regen", "stun", "taunt", "atk_up", "atk_down", "def_up", "def_down")
OBJETIVOS = ("enemy", "all_enemies", "ally", "all_allies", "self")
LETRAS_RPG = "WSFMBNL"
LETRAS_SV = "TRGBXHC"
CONSTRUCCIONES = ("muro", "puerta", "mesa", "cama")
CLAVE = "contenido_ia"


class _Err(list):
	def __call__(self, msg: str) -> None:
		if len(self) < 14:
			self.append(msg)


def _num(err, donde, v, lo, hi, entero=False):
	if isinstance(v, bool) or not isinstance(v, (int, float)):
		err(f"contenido/{donde}: tiene que ser un numero")
		return lo
	if not (lo <= v <= hi):
		err(f"contenido/{donde}: entre {lo} y {hi} (es {v})")
		return min(hi, max(lo, v))
	return int(v) if entero else float(v)


def _nombre(err, donde, v, largo=24):
	if not isinstance(v, str) or not (1 <= len(v.strip()) <= largo):
		err(f"contenido/{donde}: nombre de 1 a {largo} letras")
		return "?"
	return v.strip()


def _dic(err, donde, v, maximo):
	if not isinstance(v, dict):
		err(f"contenido/{donde}: tiene que ser un objeto")
		return {}
	if len(v) > maximo:
		err(f"contenido/{donde}: como mucho {maximo}")
	return v


# ------------------------------------------------------------------ rpg

def _rpg(c: dict, err) -> dict:
	out: dict = {}
	base = rpg_equipo.datos()
	conocidas = set(base["default"]["skills"])
	for p in base["presets"].values():
		conocidas |= set((p.get("skills") or {}).keys())
	skills = {}
	for sid, s in _dic(err, "skills", c.get("skills", {}), 24).items():
		if not ID.match(str(sid)) or not isinstance(s, dict):
			err(f"contenido/skills/{sid}: id en minusculas (a-z, 0-9, _) y un objeto")
			continue
		d = {"name": _nombre(err, f"skills/{sid}/name", s.get("name", ""), 22)}
		t = s.get("target", "enemy")
		if t not in OBJETIVOS:
			err(f"contenido/skills/{sid}/target: uno de {', '.join(OBJETIVOS)}")
		d["target"] = t if t in OBJETIVOS else "enemy"
		for k, lo, hi in (("power", 0.0, 3.5), ("heal", 0.0, 0.6), ("shield", 0.0, 0.6), ("drain", 0.0, 1.0)):
			if k in s:
				d[k] = _num(err, f"skills/{sid}/{k}", s[k], lo, hi)
		if "hits" in s:
			d["hits"] = _num(err, f"skills/{sid}/hits", s["hits"], 1, 4, True)
		if "cooldown" in s:
			d["cooldown"] = _num(err, f"skills/{sid}/cooldown", s["cooldown"], 0, 6, True)
		for k in ("cleanse", "telegraph"):
			if s.get(k):
				d[k] = True
		efs = []
		for k, e in enumerate((s.get("effects") or [])[:3]):
			if not isinstance(e, dict) or e.get("status") not in ESTADOS:
				err(f"contenido/skills/{sid}/effects/{k}: status uno de {', '.join(ESTADOS)}")
				continue
			ef = {"status": e["status"], "turns": _num(err, f"skills/{sid}/effects/{k}/turns", e.get("turns", 2), 1, 5, True)}
			if "chance" in e:
				ef["chance"] = _num(err, f"skills/{sid}/effects/{k}/chance", e["chance"], 0.3, 1.0)
			efs.append(ef)
		if efs:
			d["effects"] = efs
		if not (d.get("power") or d.get("heal") or d.get("shield") or efs or d.get("cleanse")):
			err(f"contenido/skills/{sid}: no hace nada (power, heal, shield, effects o cleanse)")
		skills[sid] = d
	out["skills"] = skills
	todas = conocidas | set(skills)

	def basico(lista):
		for sid in lista:
			s = skills.get(sid) or base["default"]["skills"].get(sid) or next((p["skills"][sid] for p in base["presets"].values() if sid in (p.get("skills") or {})), {})
			if s.get("target", "enemy") in ("enemy", "all_enemies") and float(s.get("power", 0)) > 0 and int(s.get("cooldown", 0)) == 0:
				return True
		return False

	def unidad(donde, u, enemigo):
		d = {"name": _nombre(err, f"{donde}/name", u.get("name", ""))}
		for k, lo, hi in (("hp", 20.0, 900.0 if enemigo else 400.0), ("atk", 4.0, 40.0), ("def", 0.0, 70.0), ("spd", 50.0, 170.0)):
			d[k] = _num(err, f"{donde}/{k}", u.get(k, lo), lo, hi)
		el = u.get("element", "")
		if el not in ELEMENTOS:
			err(f"{donde}/element: uno de fire, water, nature, light, dark")
		d["element"] = el if el in ELEMENTOS else ""
		sk = [str(x) for x in (u.get("skills") or [])]
		if not (1 <= len(sk) <= 4):
			err(f"contenido/{donde}/skills: de 1 a 4 habilidades")
		for x in sk:
			if x not in todas:
				err(f"contenido/{donde}/skills: '{x}' no existe (escribela en skills)")
		if sk and not basico(sk):
			err(f"contenido/{donde}/skills: necesita un ataque basico (a enemigos, con power y sin cooldown)")
		d["skills"] = sk[:4]
		if enemigo:
			if "thorns" in u:
				d["thorns"] = _num(err, f"{donde}/thorns", u["thorns"], 0.0, 0.4)
			if u.get("boss"):
				d["boss"] = True
		else:
			lk = u.get("look", "sword")
			d["look"] = lk if lk in ("sword", "staff", "cross", "bow", "beast") else "sword"
		return d

	heroes = {}
	for hid, h in _dic(err, "heroes", c.get("heroes", {}), 6).items():
		if not ID.match(str(hid)) or not isinstance(h, dict):
			err(f"contenido/heroes/{hid}: id en minusculas y un objeto")
			continue
		heroes[hid] = unidad(f"heroes/{hid}", h, False)
	out["heroes"] = heroes
	enemigos = {}
	for k, e in _dic(err, "enemies", c.get("enemies", {}), 7).items():
		if k not in LETRAS_RPG or not isinstance(e, dict):
			err(f"contenido/enemies/{k}: la clave es una letra de {LETRAS_RPG} (B = jefe)")
			continue
		enemigos[k] = unidad(f"enemies/{k}", e, True)
		if k == "B":
			enemigos[k]["boss"] = True
	out["enemies"] = enemigos
	party = c.get("party")
	if party is not None:
		if not isinstance(party, list) or not (1 <= len(party) <= 4):
			err("contenido/party: de 1 a 4 heroes")
		else:
			for p in party:
				if p not in heroes and p not in base["default"]["heroes"]:
					err(f"contenido/party: '{p}' no esta en heroes")
			out["party"] = [str(p) for p in party]
	elif heroes:
		out["party"] = list(heroes)[:4]
	if "lineup" in c:
		out["lineup"] = bool(c["lineup"])
	return out


# ------------------------------------------------------------------ supervivencia

def _supervivencia(c: dict, err) -> dict:
	out: dict = {"names": {}}
	base_items = {"wood", "stone", "fiber", "berry", "meat", "cooked"}
	items = {}
	for iid, it in _dic(err, "items", c.get("items", {}), 16).items():
		if not ID.match(str(iid)) or not isinstance(it, dict):
			err(f"contenido/items/{iid}: id en minusculas y un objeto")
			continue
		d = {}
		for k, hi in (("food", 60.0), ("water", 40.0), ("heal", 60.0), ("fuel", 60.0), ("sick", 30.0)):
			if k in it:
				d[k] = _num(err, f"items/{iid}/{k}", it[k], 0.0, hi)
		if "cook" in it:
			d["cook"] = str(it["cook"])
		if "name" in it:
			out["names"][iid] = _nombre(err, f"items/{iid}/name", it["name"])
		items[iid] = d
	todos = base_items | set(items)
	for iid, d in items.items():
		if "cook" in d and d["cook"] not in todos:
			err(f"contenido/items/{iid}/cook: '{d['cook']}' no existe")
	out["items"] = items

	def lista_obj(donde, v, maximo, hi):
		r = {}
		for k, n in _dic(err, donde, v, maximo).items():
			if k not in todos:
				err(f"contenido/{donde}: '{k}' no es un objeto")
				continue
			r[k] = _num(err, f"{donde}/{k}", n, 1, hi, True)
		return r

	recipes = {}
	for rid, r in _dic(err, "recipes", c.get("recipes", {}), 12).items():
		if not ID.match(str(rid)):
			err(f"contenido/recipes/{rid}: id en minusculas")
			continue
		if r is None:
			recipes[rid] = None
			continue
		if not isinstance(r, dict):
			err(f"contenido/recipes/{rid}: un objeto")
			continue
		d = {"cost": lista_obj(f"recipes/{rid}/cost", r.get("cost", {}), 4, 20)}
		if not d["cost"]:
			err(f"contenido/recipes/{rid}/cost: hace falta un coste")
		que = [k for k in ("tool", "fire", "build", "item", "win") if r.get(k)]
		if len(que) != 1:
			err(f"contenido/recipes/{rid}: tiene que dar una sola cosa (tool, fire, build, item o win)")
		if r.get("tool"):
			t = r["tool"] if isinstance(r["tool"], dict) else {}
			tool = {}
			for k, lo, hi in (("gather", 0.3, 1.0), ("dmg", 10.0, 80.0), ("warm", 0.2, 1.0)):
				if k in t:
					tool[k] = _num(err, f"recipes/{rid}/tool/{k}", t[k], lo, hi)
			if not tool:
				err(f"contenido/recipes/{rid}/tool: gather, dmg o warm")
			d["tool"] = tool
		if r.get("fire"):
			d["fire"] = True
		if r.get("build"):
			if r["build"] not in CONSTRUCCIONES:
				err(f"contenido/recipes/{rid}/build: uno de {', '.join(CONSTRUCCIONES)}")
			d["build"] = r["build"]
		if r.get("item"):
			d["item"] = lista_obj(f"recipes/{rid}/item", r["item"], 3, 5)
		if r.get("win"):
			d["win"] = True
		if r.get("station"):
			if r["station"] not in ("fire",) + CONSTRUCCIONES:
				err(f"contenido/recipes/{rid}/station: fire o una construccion")
			d["station"] = r["station"]
		if "name" in r:
			out["names"][rid] = _nombre(err, f"recipes/{rid}/name", r["name"])
		recipes[rid] = d
	out["recipes"] = recipes
	herramientas = {rid for rid, r in recipes.items() if r and r.get("tool")} | {k for k in ("hacha", "lanza") if recipes.get(k, 0) is not None}

	creatures = {}
	for cid, cr in _dic(err, "creatures", c.get("creatures", {}), 6).items():
		if not ID.match(str(cid)) or not isinstance(cr, dict):
			err(f"contenido/creatures/{cid}: id en minusculas y un objeto")
			continue
		d = {"hp": _num(err, f"creatures/{cid}/hp", cr.get("hp", 40), 10, 300), "dmg": _num(err, f"creatures/{cid}/dmg", cr.get("dmg", 0), 0, 40),
			"speed": _num(err, f"creatures/{cid}/speed", cr.get("speed", 2.5), 1.0, 4.0)}
		w = cr.get("when", "night")
		if w not in ("night", "always"):
			err(f"contenido/creatures/{cid}/when: night o always")
		d["when"] = w if w in ("night", "always") else "night"
		d["hostile"] = bool(cr.get("hostile", True))
		d["fear_fire"] = bool(cr.get("fear_fire", True))
		d["flee"] = bool(cr.get("flee", not d["hostile"]))
		d["drops"] = lista_obj(f"creatures/{cid}/drops", cr.get("drops", {}), 3, 5)
		lk = cr.get("look", "wolf")
		d["look"] = lk if lk in ("wolf", "zombie", "beast") else "wolf"
		if COLOR.match(str(cr.get("color", ""))):
			d["color"] = cr["color"]
		if "name" in cr:
			out["names"][cid] = _nombre(err, f"creatures/{cid}/name", cr["name"])
		creatures[cid] = d
	out["creatures"] = creatures
	bichos = set(creatures) | {"wolf"}

	tiles = {}
	for ch, t in _dic(err, "tiles", c.get("tiles", {}), 9).items():
		if ch not in LETRAS_SV + "D" or not isinstance(t, dict):
			err(f"contenido/tiles/{ch}: solo se cambian las letras {LETRAS_SV} y D (guarida)")
			continue
		d = {}
		if ch == "D":
			if t.get("den") not in bichos:
				err("contenido/tiles/D/den: una criatura que exista")
			d = {"den": t.get("den", "wolf"), "look": "D"}
		else:
			if "loot" in t:
				d["loot"] = lista_obj(f"tiles/{ch}/loot", t["loot"], 4, 4)
			else:
				if t.get("item") not in todos:
					err(f"contenido/tiles/{ch}/item: un objeto que exista")
				d["item"] = t.get("item", "wood")
			d["yield"] = _num(err, f"tiles/{ch}/yield", t.get("yield", 3), 1, 6, True)
			d["time"] = _num(err, f"tiles/{ch}/time", t.get("time", 1.0), 0.2, 3.0)
			if t.get("tool"):
				if t["tool"] not in herramientas:
					err(f"contenido/tiles/{ch}/tool: una herramienta de las recetas")
				d["tool"] = t["tool"]
			if t.get("needs"):
				if t["needs"] not in herramientas:
					err(f"contenido/tiles/{ch}/needs: una herramienta de las recetas")
				d["needs"] = t["needs"]
			if "regrow" in t:
				d["regrow"] = _num(err, f"tiles/{ch}/regrow", t["regrow"], 10.0, 120.0)
			if ch == "G":
				d["walk"] = True
			if ch in "HC":
				d["keep"] = True
			d["look"] = ch
		if COLOR.match(str(t.get("tint", ""))):
			d["tint"] = t["tint"]
		tiles[ch] = d
	out["tiles"] = tiles
	for k, lo, hi in (("cold", 0.0, 3.0),):
		if k in c:
			out[k] = _num(err, k, c[k], lo, hi)
	if "bag" in c:
		b = _num(err, "bag", c["bag"], 0, 60, True)
		if 0 < b < 12:
			err("contenido/bag: 0 (sin limite) o de 12 a 60")
		out["bag"] = b
	if "tool_uses" in c:
		u = _num(err, "tool_uses", c["tool_uses"], 0, 100, True)
		if 0 < u < 10:
			err("contenido/tool_uses: 0 (no se gastan) o de 10 a 100")
		out["tool_uses"] = u
	pal = c.get("palette") or {}
	if isinstance(pal, dict):
		out["palette"] = {k: v for k, v in pal.items() if k in ("ground", "sand", "sea") and COLOR.match(str(v))}
	if isinstance(c.get("names"), dict):
		for k, v in c["names"].items():
			if ID.match(str(k)):
				out["names"][k] = _nombre(err, f"names/{k}", v)
	return {k: v for k, v in out.items() if v not in ({}, None) or k in ("cold", "bag", "tool_uses")}


# ------------------------------------------------------------------ hordas

def _horda(c: dict, err) -> dict:
	out: dict = {}
	armas = {}
	for wid, w in _dic(err, "weapons", c.get("weapons", {}), 8).items():
		if not ID.match(str(wid)) or not isinstance(w, dict):
			err(f"contenido/weapons/{wid}: id en minusculas y un objeto")
			continue
		if w.get("pattern") not in PATRONES:
			err(f"contenido/weapons/{wid}/pattern: uno de {', '.join(PATRONES)}")
			continue
		d = {"name": _nombre(err, f"weapons/{wid}/name", w.get("name", ""), 22), "desc": str(w.get("desc", ""))[:60], "pattern": w["pattern"]}
		for k, (lo, hi) in NUMEROS_ARMA.items():
			if k not in w:
				continue
			v = w[k]
			entero = k in ("count", "pierce", "heal_every")
			if isinstance(v, list):
				if not (1 <= len(v) <= 5):
					err(f"contenido/weapons/{wid}/{k}: lista de 1 a 5 valores (uno por nivel)")
					continue
				d[k] = [_num(err, f"weapons/{wid}/{k}", x, lo, hi, entero) for x in v]
			else:
				d[k] = _num(err, f"weapons/{wid}/{k}", v, lo, hi, entero)
		if "dmg" not in d:
			err(f"contenido/weapons/{wid}: falta dmg")
		if w.get("evolved"):
			d["evolved"] = True
		if COLOR.match(str(w.get("color", ""))):
			d["color"] = w["color"]
		armas[wid] = d
	out["weapons"] = armas
	mejoras = {}
	for pid, p in _dic(err, "passives", c.get("passives", {}), 8).items():
		if not ID.match(str(pid)) or not isinstance(p, dict) or p.get("stat") not in STATS_HORDA:
			err(f"contenido/passives/{pid}: stat uno de {', '.join(STATS_HORDA)}")
			continue
		lo, hi = STATS_HORDA[p["stat"]]
		mejoras[pid] = {"name": _nombre(err, f"passives/{pid}/name", p.get("name", ""), 22), "desc": str(p.get("desc", ""))[:60],
			"stat": p["stat"], "per": _num(err, f"passives/{pid}/per", p.get("per", lo), lo, hi)}
		if "max" in p:
			mejoras[pid]["max"] = _num(err, f"passives/{pid}/max", p["max"], 1, 5, True)
	out["passives"] = mejoras
	todas_armas = set(armas) | {"rayo", "orbes", "aura", "abanico"}
	todas_mejoras = set(mejoras) | {"botas", "vida", "iman", "fuerza", "prisa"}
	evs = []
	for k, e in enumerate((c.get("evolutions") or [])[:4]):
		if not isinstance(e, dict) or e.get("weapon") not in todas_armas or e.get("passive") not in todas_mejoras or e.get("into") not in armas:
			err(f"contenido/evolutions/{k}: weapon y passive que existan e into un arma nueva de weapons")
			continue
		armas[e["into"]]["evolved"] = True
		evs.append({"weapon": e["weapon"], "passive": e["passive"], "into": e["into"]})
	if evs:
		out["evolutions"] = evs
	if "start" in c:
		if c["start"] not in todas_armas or (c["start"] in armas and armas[c["start"]].get("evolved")):
			err("contenido/start: un arma que exista (no una evolucion)")
		out["start"] = c["start"]
	enem = {}
	for k, e in _dic(err, "enemies", c.get("enemies", {}), 4).items():
		if k not in ("walker", "spiky", "flyer", "boss") or not isinstance(e, dict):
			err("contenido/enemies: solo walker, spiky, flyer o boss")
			continue
		lim = {"hp": (0.5, 120.0 if k == "boss" else 12.0), "speed": (40.0, 220.0), "damage": (1, 3)}
		enem[k] = {kk: _num(err, f"enemies/{k}/{kk}", e[kk], lim[kk][0], lim[kk][1], kk == "damage") for kk in lim if kk in e}
	if enem:
		out["enemies"] = enem
	return out


# ------------------------------------------------------------------ shooter de zombis 3D

def _fps(c: dict, err) -> dict:
	out: dict = {}
	lim = {"dmg": (8.0, 120.0), "rate": (0.06, 1.5), "mag": (2, 60), "reload": (0.6, 3.5), "spread": (0.0, 0.2), "pellets": (1, 10), "range": (5.0, 22.0)}
	armas = {}
	for wid, w in _dic(err, "weapons", c.get("weapons", {}), 6).items():
		if not ID.match(str(wid)) or not isinstance(w, dict):
			err(f"contenido/weapons/{wid}: id en minusculas y un objeto")
			continue
		d = {"name": _nombre(err, f"weapons/{wid}/name", w.get("name", ""), 20)}
		for k, (lo, hi) in lim.items():
			d[k] = _num(err, f"weapons/{wid}/{k}", w.get(k, lo), lo, hi, k in ("mag", "pellets"))
		lk = w.get("look", "pistol")
		d["look"] = lk if lk in ("pistol", "shotgun", "rifle") else "pistol"
		armas[wid] = d
	out["weapons"] = armas
	todas = set(armas) | {"pistola", "escopeta", "fusil"}
	slots = {}
	for k, v in (c.get("slots") or {}).items():
		if k not in ("start", "S", "R") or v not in todas:
			err("contenido/slots: start, S y R con armas que existan")
			continue
		slots[k] = v
	if slots:
		out["slots"] = slots
	kinds = {}
	for k, z in _dic(err, "kinds", c.get("kinds", {}), 3).items():
		if k not in ("walker", "runner", "brute") or not isinstance(z, dict):
			err("contenido/kinds: solo walker, runner o brute")
			continue
		zl = {"hp": (20.0, 400.0), "speed": (0.4, 2.2), "dmg": (3.0, 30.0)}
		kinds[k] = {kk: _num(err, f"kinds/{k}/{kk}", z[kk], zl[kk][0], zl[kk][1]) for kk in zl if kk in z}
	if kinds:
		out["kinds"] = kinds
	return out


# ------------------------------------------------------------------ imperio

TROPAS = ("aldeano", "lancero", "arquero", "jinete", "ariete")
EDIFICIOS = ("centro", "casa", "granja", "almacen", "cuartel", "arqueria", "establo", "taller", "torre", "muro")


def _imperio(c: dict, err) -> dict:
	"""Imperio: los papeles son fijos (asi la IA rival y el bot saben jugar); se cambian nombres y
	numeros, sin pasarse de lo que el equilibrio aguanta (piedra, papel, tijera)."""
	out: dict = {}
	lim_t = {"hp": (0.7, 1.4), "dmg": (0.7, 1.4), "speed": (0.75, 1.3), "range": (0.8, 1.25)}
	base_t = {"aldeano": {"hp": 25, "dmg": 3, "speed": 1.9, "range": 0.7}, "lancero": {"hp": 60, "dmg": 6, "speed": 1.6, "range": 0.75},
		"arquero": {"hp": 35, "dmg": 5, "speed": 1.6, "range": 4.0}, "jinete": {"hp": 120, "dmg": 8, "speed": 2.6, "range": 0.8},
		"ariete": {"hp": 220, "dmg": 45, "speed": 0.9, "range": 0.8}}
	tropas = {}
	for k, u in _dic(err, "units", c.get("units", {}), 5).items():
		if k not in TROPAS or not isinstance(u, dict):
			err(f"contenido/units/{k}: solo {', '.join(TROPAS)} (los papeles no cambian; cambia el nombre y los numeros)")
			continue
		d = {}
		if "name" in u:
			d["name"] = _nombre(err, f"units/{k}/name", u["name"], 22)
		for kk, (lo, hi) in lim_t.items():
			if kk in u:
				b = float(base_t[k][kk])
				d[kk] = _num(err, f"units/{k}/{kk}", u[kk], round(b * lo, 2), round(b * hi, 2))
		tropas[k] = d
	if tropas:
		out["units"] = tropas
	edif = {}
	for k, b in _dic(err, "builds", c.get("builds", {}), 10).items():
		if k not in EDIFICIOS or not isinstance(b, dict):
			err(f"contenido/builds/{k}: solo {', '.join(EDIFICIOS)}")
			continue
		if "name" in b:
			edif[k] = {"name": _nombre(err, f"builds/{k}/name", b["name"], 22)}
	if edif:
		out["builds"] = edif
	rn = {}
	for k, v in (c.get("res_names") or {}).items():
		if k in ("comida", "madera", "oro"):
			rn[k] = _nombre(err, f"res_names/{k}", v, 14)
	if rn:
		out["res_names"] = rn
	return out


# ------------------------------------------------------------------ karts

def _karts(c: dict, err) -> dict:
	"""Objetos de los karts: cada uno con un efecto de los que el kit sabe hacer."""
	objs = {}
	for k, it in _dic(err, "items", c.get("items", {}), 8).items():
		if not ID.match(str(k)):
			err(f"contenido/items/{k}: id en minusculas")
			continue
		if it is None and k in ("cascara", "platano", "turbo"):
			objs[k] = None
			continue
		if not isinstance(it, dict) or it.get("effect") not in ("seek", "trap", "boost", "star"):
			err(f"contenido/items/{k}/effect: seek (va a por el de delante), trap (se queda detras), boost o star")
			continue
		d = {"name": _nombre(err, f"items/{k}/name", it.get("name", ""), 18), "effect": it["effect"]}
		w = it.get("weights", [0.3, 0.3, 0.3])
		if not isinstance(w, list) or len(w) != 3:
			err(f"contenido/items/{k}/weights: tres numeros (delante, en medio, detras)")
		else:
			d["weights"] = [_num(err, f"items/{k}/weights", x, 0.0, 1.0) for x in w]
		if "dur" in it:
			d["dur"] = _num(err, f"items/{k}/dur", it["dur"], 0.5, 6.0)
		if "count" in it:
			d["count"] = _num(err, f"items/{k}/count", it["count"], 1, 3, True)
		objs[k] = d
	if objs and all(v is None for v in objs.values()) and len(objs) >= 3:
		err("contenido/items: tiene que quedar al menos un objeto")
	return {"items": objs} if objs else {}


def _tycoon(c: dict, err) -> dict:
	"""Negocios (o pozos de la mina) con nombres y dibujos del tema; los numeros, si los cambia,
	como mucho un 30-40 % arriba o abajo de los de serie (la meta se calibra despues)."""
	from niveles import tycoon
	base = tycoon.datos()
	out: dict = {}
	if "cur" in c:
		cur = str(c["cur"])
		if cur in ("$", "€", "£", "¥") or (1 <= len(cur) <= 3 and cur.isalpha()):
			out["cur"] = cur
		else:
			err("contenido/cur: $, €, £, ¥ o hasta 3 letras")
	for sec, ref in (("biz", base["default"]["biz"]), ("shafts", base["presets"]["mina"]["shafts"])):
		for k, v in _dic(err, sec, c.get(sec, {}), 8).items():
			if k not in ref:
				err(f"contenido/{sec}/{k}: usa los ids de serie ({', '.join(ref)}) y cambia su nombre y su dibujo")
				continue
			if not isinstance(v, dict):
				err(f"contenido/{sec}/{k}: tiene que ser un objeto")
				continue
			e: dict = {}
			if "name" in v:
				e["name"] = _nombre(err, f"{sec}/{k}/name", v["name"], 22)
			if "look" in v:
				if v["look"] in tycoon.LOOKS:
					e["look"] = v["look"]
				else:
					err(f"contenido/{sec}/{k}/look: uno de {', '.join(tycoon.LOOKS)}")
			for campo, lo, hi in (("profit", 0.6, 1.4), ("value", 0.6, 1.4), ("time", 0.6, 1.4), ("cost", 0.7, 1.3)):
				if campo in v and campo in ref[k]:
					r = float(ref[k][campo])
					e[campo] = _num(err, f"{sec}/{k}/{campo}", v[campo], round(r * lo, 3), round(r * hi, 3))
			if e:
				out.setdefault(sec, {})[k] = e
	for sec2 in ("lift", "store"):
		if isinstance(c.get(sec2), dict) and "name" in c[sec2]:
			out[sec2] = {"name": _nombre(err, f"{sec2}/name", c[sec2]["name"], 22)}
	return out


def _tragaperras(c: dict, err) -> dict:
	"""Simbolos y aldea del tema: los ids de serie con nombre y dibujo propios; los premios y los
	pesos, si cambian, como mucho un 30 % (la escala de la aldea se calibra despues)."""
	from niveles import tragaperras
	base = tragaperras.datos()["default"]
	out: dict = {}
	if "village" in c:
		out["village"] = _nombre(err, "village", c["village"], 24)
	for k, v in _dic(err, "symbols", c.get("symbols", {}), 7).items():
		ref = base["symbols"].get(k)
		if ref is None or not isinstance(v, dict):
			err(f"contenido/symbols/{k}: usa los ids de serie ({', '.join(base['symbols'])}) con nombre y dibujo")
			continue
		e: dict = {}
		if "name" in v:
			e["name"] = _nombre(err, f"symbols/{k}/name", v["name"], 16)
		if "look" in v:
			if v["look"] in tragaperras.LOOKS_SIMBOLO:
				e["look"] = v["look"]
			else:
				err(f"contenido/symbols/{k}/look: uno de {', '.join(tragaperras.LOOKS_SIMBOLO)}")
		for campo in ("pay", "w"):
			if campo in v:
				r = float(ref[campo])
				e[campo] = _num(err, f"symbols/{k}/{campo}", v[campo], round(r * 0.7, 3), round(r * 1.3, 3))
		if e:
			out.setdefault("symbols", {})[k] = e
	for k, v in _dic(err, "buildings", c.get("buildings", {}), 5).items():
		if k not in base["buildings"] or not isinstance(v, dict):
			err(f"contenido/buildings/{k}: usa los ids de serie ({', '.join(base['buildings'])}) con nombre y dibujo")
			continue
		e2: dict = {}
		if "name" in v:
			e2["name"] = _nombre(err, f"buildings/{k}/name", v["name"], 18)
		if "look" in v:
			if v["look"] in tragaperras.LOOKS_EDIFICIO:
				e2["look"] = v["look"]
			else:
				err(f"contenido/buildings/{k}/look: uno de {', '.join(tragaperras.LOOKS_EDIFICIO)}")
		if e2:
			out.setdefault("buildings", {})[k] = e2
	return out


LOOKS_REINO = ("castle", "farm", "mill", "quarry", "barracks", "stable", "range")


def _reino(c: dict, err) -> dict:
	"""Reino: nombres del tema para recursos, edificios, tropas, heroes y campamentos; numeros de
	las tropas como mucho un 30 % (los papeles, el piedra-papel-tijera, no cambian)."""
	import json as _json
	from pathlib import Path as _Path
	base = _json.loads((_Path(__file__).resolve().parents[1] / "orqkit" / "kit" / "realm" / "realm_catalog.json").read_text(encoding="utf-8"))["default"]
	out: dict = {}
	if "realm" in c:
		out["realm"] = _nombre(err, "realm", c["realm"], 24)
	for sec, largo in (("res", 12), ("buildings", 18), ("troops", 16), ("heroes", 16)):
		for k, v in _dic(err, sec, c.get(sec, {}), 8).items():
			if k not in base[sec] or not isinstance(v, dict):
				err(f"contenido/{sec}/{k}: usa los ids de serie ({', '.join(base[sec])}) con su nombre")
				continue
			e: dict = {}
			if "name" in v:
				e["name"] = _nombre(err, f"{sec}/{k}/name", v["name"], largo)
			if sec == "buildings" and "look" in v:
				if v["look"] in LOOKS_REINO:
					e["look"] = v["look"]
				else:
					err(f"contenido/buildings/{k}/look: uno de {', '.join(LOOKS_REINO)}")
			if sec == "troops":
				for campo in ("hp", "atk"):
					if campo in v:
						r = float(base["troops"][k][campo])
						e[campo] = _num(err, f"troops/{k}/{campo}", v[campo], round(r * 0.7, 2), round(r * 1.3, 2))
			if e:
				out.setdefault(sec, {})[k] = e
	if "camp_names" in c:
		if isinstance(c["camp_names"], list) and 2 <= len(c["camp_names"]) <= 6:
			out["camp_names"] = [_nombre(err, "camp_names", x, 26) for x in c["camp_names"]]
		else:
			err("contenido/camp_names: de 2 a 6 nombres (el ultimo, el jefe)")
	return out


# ------------------------------------------------------------------ arena

def _arena(c: dict, err) -> dict:
	"""Personajes de la arena (8 papeles fijos: kit/brawl/brawlers.gd) con nombres y color del tema, y
	el nombre y color de lo que cierra la arena (el gas: marea, niebla, lava...)."""
	out: dict = {}
	bs = []
	for k, b in _dic(err, "brawlers", c.get("brawlers", {}), 8).items():
		if k not in BRAWLERS:
			err(f"contenido/brawlers/{k}: ids {', '.join(BRAWLERS)}")
			continue
		if not isinstance(b, dict):
			err(f"contenido/brawlers/{k}: objeto con name")
			continue
		x = {"id": k, "name": _nombre(err, f"brawlers/{k}/name", b.get("name", ""), 16)}
		## Descripcion visual (en ingles) para dibujar su propio personaje (14 nov: antes compartian arte).
		desc = b.get("desc")
		if isinstance(desc, str) and 8 <= len(desc.strip()) <= 220:
			x["desc"] = desc.strip()
		elif desc is not None:
			err(f"contenido/brawlers/{k}/desc: descripcion visual en ingles de 8 a 220 letras")
		if "tint" in b:
			if isinstance(b["tint"], str) and COLOR.match(b["tint"]):
				x["tint"] = b["tint"]
			else:
				err(f"contenido/brawlers/{k}/tint: color #rrggbb")
		bs.append(x)
	if bs:
		out["brawlers"] = bs
	hz = c.get("hazard")
	if hz is not None:
		if not isinstance(hz, dict):
			err("contenido/hazard: objeto con name y color")
		else:
			out["hazard"] = {"name": _nombre(err, "hazard/name", hz.get("name", ""), 14)}
			col = hz.get("color", "")
			if isinstance(col, str) and COLOR.match(col):
				out["hazard"]["color"] = col
			elif col:
				err("contenido/hazard/color: color #rrggbb")
	return out


def validar(genero: str, c) -> tuple[dict, list[str]]:
	"""(contenido limpio, errores). Sin errores, el limpio es lo que va al juego."""
	err = _Err()
	if not isinstance(c, dict):
		return {}, ["contenido: tiene que ser un objeto"]
	if genero not in GENEROS:
		return {}, [f"contenido: solo para {', '.join(GENEROS)} (este juego es {genero})"]
	limpio = {"rpg": _rpg, "supervivencia": _supervivencia, "horda": _horda, "zombis": _fps, "imperio": _imperio, "karts": _karts, "tycoon": _tycoon, "tragaperras": _tragaperras, "reino": _reino, "arena": _arena}[genero](c, err)
	return copy.deepcopy(limpio), list(err)


# ------------------------------------------------------------------ aprender

def fiable(genero: str) -> bool:
	return giros.fiable(genero, CLAVE)


def anotar(genero: str, ok: bool, problema: str = "") -> None:
	giros.anotar(genero, [CLAVE], ok, problema)


def guia(genero: str | None = None) -> str:
	"""Para la directora: como inventar el contenido de rpg y supervivencia."""
	partes = []
	if genero in (None, "rpg") and fiable("rpg"):
		partes.append(GUIA_RPG)
	if genero in (None, "supervivencia") and fiable("supervivencia"):
		partes.append(GUIA_SV)
	if genero in (None, "horda") and fiable("horda"):
		partes.append(GUIA_HORDA)
	if genero in (None, "zombis") and fiable("zombis"):
		partes.append(GUIA_FPS)
	if genero in (None, "imperio") and fiable("imperio"):
		partes.append(GUIA_IMPERIO)
	if genero in (None, "karts") and fiable("karts"):
		partes.append(GUIA_KARTS)
	if genero in (None, "tycoon") and fiable("tycoon"):
		partes.append(GUIA_TYCOON)
	if genero in (None, "tragaperras") and fiable("tragaperras"):
		partes.append(GUIA_TRAGAPERRAS)
	if genero in (None, "reino") and fiable("reino"):
		partes.append(GUIA_REINO)
	if genero in (None, "arena") and fiable("arena"):
		partes.append(GUIA_ARENA)
	if not partes:
		return ""
	return ("CONTENIDO PROPIO (opcional, campo «contenido», solo en los generos de abajo): inventa el contenido de ESTE "
		"juego para que no se parezca a ningun otro. Son datos con margenes; la fabrica los prueba con bots y, si no salen "
		"niveles justos, vuelve al estilo probado. Nombres originales (nada de marcas), en el idioma del juego.\n" + "\n".join(partes))


GUIA_RPG = """- rpg: {"heroes": {id: {"name", "hp" 60-400, "atk" 8-40, "def" 0-60, "spd" 60-160, "element" (fire, water, nature, light, dark), "look" (sword, staff, cross, bow, beast), "skills": [2-4 ids]}}, "party": [1-4 ids], "lineup": true si es uno contra uno (criaturas), "skills": {id: {"name", "target" (enemy, all_enemies, ally, all_allies, self), "power" 0-3.5, "hits" 1-4, "heal" 0-0.6, "shield" 0-0.6, "drain" 0-1, "cleanse", "cooldown" 0-6, "telegraph", "effects": [{"status" (poison, burn, regen, stun, taunt, atk_up, atk_down, def_up, def_down), "turns" 1-5}]}}, "enemies": {letra W, S, F, M, N, L o B (jefe): {"name", "hp" 20-900, "atk", "def", "spd", "element", "skills", "thorns" 0-0.4}}}. Cada heroe y enemigo necesita un ataque basico (a enemigos, con power, sin cooldown). Equilibrio de referencia: un equipo de 3-4 heroes de 100-170 de vida y 14-25 de ataque contra enemigos de 50-110 de vida y 12-17 de ataque; el jefe 300-460. Ejemplo: tripulacion pirata con capitan (provocar), artillera (andanada a todos) y cocinero (cura a todos)."""

GUIA_SV = """- supervivencia: {"items": {id: {"name", "food" 0-60, "water" 0-40, "heal" 0-60, "fuel" 0-60, "cook": id, "sick" 0-30}}, "tiles": {letra T (arbol), R (roca), G (hierba), B (arbusto), X (restos), H (casa), C (coche): {"item": id o "loot": {id: n}, "yield" 1-6, "time" 0.2-3, "tool", "regrow", "tint" "#rrggbb"}, "D": {"den": criatura}}, "recipes": {id: {"name", "cost": {id: n}, y UNA de: "tool": {"gather" 0.3-1, "dmg" 10-80, "warm" 0.2-1}, "fire": true, "build" (muro, puerta, mesa, cama), "item": {id: n}, "win": true; "station": "fire" o una construccion}} (null quita una de las de siempre: hacha, lanza, hoguera), "creatures": {id: {"name", "hp" 10-300, "dmg" 0-40, "speed" 1-4, "when" (night, always), "hostile", "fear_fire", "drops": {id: n}, "look" (wolf, zombie, beast), "color"}}, "cold" 0-3, "bag" 0 o 12-60, "palette": {"ground", "sand", "sea"}}. Los objetos de siempre son wood, stone, fiber, berry, meat, cooked. Que haya una receta de fuego y comida al alcance. Ejemplo: naufragio en un planeta alienigena con cristales en vez de roca, frutos luminosos y bestias nocturnas."""

GUIA_HORDA = """- horda: {"start": id, "weapons": {id: {"name", "desc", "pattern" (shot: al mas cercano; fan: abanico delante; orbit: giran alrededor; aura: halo; nova: anillo; chain: rayo que salta; bomb: explosion donde hay mas; whip: latigazo a los lados), "cd" 0.15-4, "count" 1-16, "dmg" 0.5-12, "pierce" 1-5, "range" 200-900, "radius" 40-260, "color"; cada numero puede ser una lista de 5, uno por nivel}}, "passives": {id: {"name", "desc", "stat" (speed, hp, magnet, power, haste, area, count), "per"}}, "evolutions": [{"weapon", "passive", "into": arma nueva de weapons}], "enemies": {walker/spiky/flyer/boss: {"hp", "speed", "damage"}}}. Referencia: un arma de inicio de dmg 2-3 y cd 0.5-0.8; 4-6 armas y 3-5 mejoras. Ejemplo: un gato astronauta con pistola laser, satelites que orbitan y una supernova."""

GUIA_FPS = """- zombis (shooter 3D): {"weapons": {id: {"name", "dmg" 8-120, "rate" 0.06-1.5 (segundos entre disparos), "mag" 2-60, "reload" 0.6-3.5, "spread" 0-0.2, "pellets" 1-10, "range" 5-22, "look" (pistol, shotgun, rifle)}}, "slots": {"start": arma inicial, "S": arma que se recoge en las S, "R": la de las R}, "kinds": {walker/runner/brute: {"hp", "speed", "dmg"}}}. Las de serie: pistola (34 de dano, 12 balas), escopeta (6 perdigones de 24) y fusil (28, 30 balas, muy rapido). Ejemplo: cazadores de monstruos con ballesta, trabuco y arcabuz."""

GUIA_IMPERIO = """- imperio: {"units": {aldeano/lancero/arquero/jinete/ariete: {"name", "hp", "dmg", "speed", "range"}}, "builds": {centro/casa/granja/almacen/cuartel/arqueria/establo/taller/torre/muro: {"name"}}, "res_names": {"comida", "madera", "oro"}}. Los papeles no cambian (lancero gana a jinete, jinete a arquero, arquero a lancero; el ariete tira edificios): cambia los nombres al tema y los numeros como mucho un 30-40 % arriba o abajo de los de serie (aldeano 25 de vida, lancero 60, arquero 35 y alcance 4, jinete 120 y velocidad 2.6, ariete 220). Ejemplo: un imperio de hormigas con obreras, soldados, escupidoras, voladoras y una reina ariete; recursos azucar, hojas y miel."""

GUIA_KARTS = """- karts: {"items": {id: {"name", "effect" (seek: va a por el de delante; trap: se queda en la pista detras; boost: acelera; star: acelera y nada te para), "weights": [delante, en medio, detras] 0-1, "dur" 0.5-6 (boost y star), "count" 1-3 (cargas)}}} (null quita cascara, platano o turbo). Que haya trampas para el que va primero y ayudas para los de atras. Ejemplo: karts de cocina con tomate que persigue, mancha de aceite y guindilla turbo."""

GUIA_TYCOON = """- tycoon: {"cur": "$" (o €, £, ¥ o hasta 3 letras), "biz": {limonada/periodicos/lavadero/pizzeria/donuts/pescado/estadio/cine: {"name", "look" (lemon, paper, car, pizza, donut, fish, ball, film, coal, iron, copper, silver, gold, gem, shop, coffee, bank, rocket, farm, factory, oil, phone, game, burger, cake, hotel), "profit", "time", "cost"}}; con el giro mina: "shafts": {carbon/hierro/cobre/plata/oro/diamante: {"name", "look", "value"}}, "lift": {"name"}, "store": {"name"}}. Los ids no cambian (van de mas barato a mas caro); cambia nombres y dibujos al tema y, si quieres, los numeros como mucho un 30-40 % (la meta se calibra sola). Ejemplo: imperio de la reposteria con puesto de churros, cafeteria, pasteleria, fabrica de chocolate y cadena de hamburguesas."""

GUIA_TRAGAPERRAS = """- tragaperras: {"village": nombre de la aldea, "symbols": {coin/bag/star/chest/energy/hammer/pig: {"name", "look" (coin, bag, chest, energy, hammer, pig, star, cherry, bell, seven, gem, crown)}}, "buildings": {casa/molino/pozo/torre/estatua: {"name", "look" (house, tower, mill, statue, ship, tree, castle, well, tent, bridge)}}}. Los papeles no cambian (energy da tiradas, hammer abre cofres, pig es el asalto); cambia nombres y dibujos al tema. Monedas de mentira: nada de dinero real. Ejemplo: isla pirata con doblones, cofres y loros; puerto, barco, faro y fortaleza."""

GUIA_REINO = """- reino: {"realm": nombre del reino, "res": {food/wood/stone: {"name"}}, "buildings": {castillo/granja/aserradero/cantera/cuartel/establo/arqueria: {"name", "look" (castle, farm, mill, quarry, barracks, stable, range)}}, "troops": {infantry/cavalry/archer: {"name", "hp", "atk"}}, "heroes": {amadea/jabel/saul: {"name"}}, "camp_names": [2-6 nombres de campamentos enemigos, el ultimo el jefe]}. Los papeles no cambian (infanteria gana a caballeria, caballeria a arqueros, arqueros a infanteria); cambia los nombres al tema y la vida y el ataque como mucho un 30 % (de serie: lanceros 12 y 3, jinetes 14 y 4, arqueros 7 y 5). Ejemplo: un reino helado con iglu-castillo, pescaderia, leñera y mina de hielo; cazadores, trineos de lobos y lanzanieves; campamentos de yetis."""

GUIA_ARENA = """- arena: {"brawlers": {tenaza/coraza/aguja/rapida/alga/tinta/perla/rey: {"name", "tint" "#rrggbb", "desc"}}, "hazard": {"name", "color"}}. desc: como es por fuera, en ingles, 1 frase (se dibuja cada uno con su arte propio; tenaza es el heroe y usa su dibujo). Los papeles no cambian (tenaza: rafaga y onda; coraza: escopeta y escudo, mucha vida; aguja: francotiradora con bomba; rapida: veloz con embestida; alga: cura al equipo; tinta: escopeta con bomba; perla: tiro largo y onda; rey: el mas fuerte, se gana el ultimo); pon nombres del tema (cortos, 16 letras como mucho) y un tinte claro distinto a cada uno. hazard es lo que cierra la arena (de serie, gas verde). Ejemplo: cangrejos en una playa con Pinzas, Caparazon, Arponera, Corre-Corre, Anemona, Calamar, Perla y Rey Cangrejo; la marea azul (#3fa9f5) que sube."""

class_name Heroes
extends RefCounted
## Coleccion de heroes del RPG de equipo (14 nov, como los RPG de heroes mas jugados del movil):
## 1 - Plantel: los heroes del juego (catalogo + game.json "rpg") y 9 de coleccion del kit con su
##     rareza (comun, raro, epico, legendario). Al empezar tienes el equipo de serie.
## 2 - Invocar con la moneda del juego: 1 o 10 a la vez, probabilidades a la vista (las pide
##     Google para las cajas de premio) y garantia de legendario cada 40 invocaciones sin el.
##     Repetidos: +1 estrella (hasta 5, +10 % cada una); con 5, devuelve moneda.
## 3 - Nivel de cada heroe (1 a 30) con moneda: +5 % de vida y ataque por nivel.
## 4 - Equipo: hasta 4 heroes tuyos (Save.meta()["team"]); el juego los saca a pelear.
## 5 - Botin mientras no juegas: moneda por hora segun lo lejos que vas (hasta 12 horas).
## game.json -> "rpg": {"collection": false} lo apaga. Todo se guarda en Save.meta()["heroes"].

const RARITIES: Array[String] = ["comun", "raro", "epico", "legendario"]
const RATES: Dictionary = {"comun": 50.0, "raro": 33.0, "epico": 14.0, "legendario": 3.0}
const RARITY_MULT: Dictionary = {"comun": 0.9, "raro": 1.0, "epico": 1.1, "legendario": 1.22}
const RARITY_COL: Dictionary = {"comun": "#b0bec5", "raro": "#4fc3ff", "epico": "#c77dff", "legendario": "#ffc94d"}
const PITY: int = 40
const COST_ONE: int = 280
const COST_TEN: int = 2500
const MAX_LEVEL: int = 30
const PER_LEVEL: float = 0.05
const MAX_STARS: int = 5
const PER_STAR: float = 0.1
const DUP_REFUND: int = 100
const IDLE_CAP_H: float = 12.0

## Heroes de coleccion del kit (se suman a los del juego). Sus habilidades nuevas van en EXTRA_SKILLS.
const EXTRA: Dictionary = {
	"escudero": {"name": "Escudero", "rarity": "comun", "hp": 160.0, "atk": 14.0, "def": 30.0, "spd": 92.0, "element": "nature", "look": "sword", "skills": ["golpe", "provocar"]},
	"ballestero": {"name": "Ballestero", "rarity": "comun", "hp": 110.0, "atk": 20.0, "def": 14.0, "spd": 115.0, "element": "water", "look": "bow", "skills": ["flecha", "lluvia"]},
	"berserker": {"name": "Berserker", "rarity": "raro", "hp": 150.0, "atk": 26.0, "def": 15.0, "spd": 100.0, "element": "fire", "look": "sword", "skills": ["golpe", "tajo", "furia"]},
	"monje": {"name": "Monje", "rarity": "raro", "hp": 135.0, "atk": 19.0, "def": 20.0, "spd": 118.0, "element": "light", "look": "cross", "skills": ["golpe", "bendicion", "curar_aliado"]},
	"paladina": {"name": "Paladina", "rarity": "epico", "hp": 190.0, "atk": 16.0, "def": 40.0, "spd": 90.0, "element": "light", "look": "sword", "skills": ["golpe", "provocar", "curar_aliado"]},
	"nigromante": {"name": "Nigromante", "rarity": "epico", "hp": 95.0, "atk": 27.0, "def": 8.0, "spd": 108.0, "element": "dark", "look": "staff", "skills": ["chispa", "drenar", "maldicion"]},
	"druida": {"name": "Druida", "rarity": "epico", "hp": 125.0, "atk": 17.0, "def": 18.0, "spd": 104.0, "element": "nature", "look": "staff", "skills": ["luz", "curar", "regenerar"]},
	"asesina": {"name": "Asesina", "rarity": "legendario", "hp": 95.0, "atk": 28.0, "def": 10.0, "spd": 135.0, "element": "dark", "look": "bow", "skills": ["flecha", "veneno", "golpe_letal"]},
	"dragona": {"name": "Dragona", "rarity": "legendario", "hp": 210.0, "atk": 30.0, "def": 25.0, "spd": 110.0, "element": "fire", "look": "beast", "skills": ["zarpazo", "bola_fuego", "aliento"]},
}
const EXTRA_SKILLS: Dictionary = {
	"furia": {"name": "Furia", "target": "self", "effects": [{"status": "atk_up", "turns": 3}], "cooldown": 4},
	"drenar": {"name": "Drenar", "target": "enemy", "power": 1.1, "drain": 0.5, "cooldown": 3},
	"maldicion": {"name": "Maldición", "target": "all_enemies", "power": 0.4, "effects": [{"status": "def_down", "turns": 2}], "cooldown": 3},
	"regenerar": {"name": "Regenerar", "target": "all_allies", "effects": [{"status": "regen", "turns": 3}], "cooldown": 4},
	"golpe_letal": {"name": "Golpe letal", "target": "enemy", "power": 2.4, "cooldown": 4},
	"aliento": {"name": "Aliento de fuego", "target": "all_enemies", "power": 1.0, "effects": [{"status": "burn", "turns": 2}], "cooldown": 4},
}


static func _rpg() -> Dictionary:
	var r: Variant = Kit.param("rpg", null)
	if r is Dictionary:
		return r
	for lv: Variant in Kit.config.get("levels", []):
		if lv is Dictionary and (lv as Dictionary).get("rpg", null) is Dictionary:
			return (lv as Dictionary)["rpg"]
	return {}


## Hay coleccion en este juego: RPG de equipo (no el de criaturas uno contra uno) y sin apagar.
static func enabled() -> bool:
	var r: Dictionary = _rpg()
	if r.is_empty() or r.get("collection", true) == false:
		return false
	return not bool(TurnsParty.catalog({"rpg": r}).get("lineup", false))


## Todos los heroes que se pueden tener: los del juego y los de coleccion del kit.
static func roster() -> Dictionary:
	var cat: Dictionary = TurnsParty.catalog({"rpg": _rpg()})
	var out: Dictionary = {}
	var base_team: Array = cat.get("party", [])
	for id: Variant in cat["heroes"]:
		var d: Dictionary = (cat["heroes"][id] as Dictionary).duplicate(true)
		if not RARITIES.has(str(d.get("rarity", ""))):
			d["rarity"] = "raro" if base_team.has(id) or (cat["heroes"] as Dictionary).size() <= 4 else "epico"
		out[str(id)] = d
	if _rpg().get("collection_extra", true) != false:
		for id: String in EXTRA:
			if not out.has(id):
				out[id] = (EXTRA[id] as Dictionary).duplicate(true)
	return out


static func skills_extra() -> Dictionary:
	return EXTRA_SKILLS


static func hero(id: String) -> Dictionary:
	return roster().get(id, {})


static func rarity(id: String) -> String:
	return str(hero(id).get("rarity", "raro"))


static func rarity_color(id: String) -> Color:
	return Color(str(RARITY_COL.get(rarity(id), "#b0bec5")))


# ------------------------------------------------------------------ coleccion guardada

static func _col() -> Dictionary:
	var m: Dictionary = Save.meta()
	if not (m.get("heroes", null) is Dictionary):
		var start: Dictionary = {}
		for id: Variant in TurnsParty.catalog({"rpg": _rpg()}).get("party", []):
			start[str(id)] = {"lv": 1, "stars": 1}
		m["heroes"] = start
		Save.data["meta"] = m
	return m["heroes"]


static func owned(id: String) -> bool:
	return _col().has(id)


static func owned_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in roster().keys():
		if owned(id):
			out.append(id)
	return out


static func level(id: String) -> int:
	return clampi(int((_col().get(id, {}) as Dictionary).get("lv", 1)), 1, MAX_LEVEL)


static func stars(id: String) -> int:
	return clampi(int((_col().get(id, {}) as Dictionary).get("stars", 1)), 1, MAX_STARS)


## Fuerza del heroe: rareza, nivel y estrellas (vida y ataque).
static func power_mult(id: String) -> float:
	return float(RARITY_MULT.get(rarity(id), 1.0)) * (1.0 + PER_LEVEL * float(level(id) - 1)) * (1.0 + PER_STAR * float(stars(id) - 1))


static func level_cost(id: String) -> int:
	return 30 + 25 * level(id) if level(id) < MAX_LEVEL else 0


static func level_up(id: String) -> bool:
	if not owned(id) or level(id) >= MAX_LEVEL or not Save.spend(level_cost(id)):
		return false
	(_col()[id] as Dictionary)["lv"] = level(id) + 1
	Save.save_data()
	QA.log_event("hero_level", {"id": id, "level": level(id)})
	return true


# ------------------------------------------------------------------ equipo

static func team() -> Array[String]:
	var out: Array[String] = []
	var t: Variant = Save.meta().get("team", null)
	if t is Array:
		for id: Variant in t:
			if owned(str(id)) and roster().has(str(id)) and not out.has(str(id)) and out.size() < 4:
				out.append(str(id))
	if out.is_empty():
		for id: Variant in TurnsParty.catalog({"rpg": _rpg()}).get("party", []):
			if owned(str(id)) and out.size() < 4:
				out.append(str(id))
	return out


## Pone o quita un heroe del equipo (como mucho 4, al menos 1).
static func toggle_team(id: String) -> bool:
	var t: Array[String] = team()
	if t.has(id):
		if t.size() <= 1:
			return false
		t.erase(id)
	elif owned(id) and t.size() < 4:
		t.append(id)
	else:
		return false
	var m: Dictionary = Save.meta()
	m["team"] = t
	Save.data["meta"] = m
	Save.save_data()
	return true


## El nivel con el equipo elegido y los heroes de coleccion que hagan falta (para TurnsParty).
static func apply_to_level(lv: Dictionary) -> Dictionary:
	var out: Dictionary = lv.duplicate(true)
	var r: Dictionary = (out.get("rpg", {}) as Dictionary).duplicate(true)
	var hs: Dictionary = (r.get("heroes", {}) as Dictionary).duplicate(true)
	var sk: Dictionary = (r.get("skills", {}) as Dictionary).duplicate(true)
	var all: Dictionary = roster()
	for id: String in team():
		if not hs.has(id) and EXTRA.has(id):
			hs[id] = all[id]
	for id: String in EXTRA_SKILLS:
		if not sk.has(id):
			sk[id] = EXTRA_SKILLS[id]
	r["heroes"] = hs
	r["skills"] = sk
	out["rpg"] = r
	out["party"] = team()
	return out


## Despues de crear la partida: cada heroe con su fuerza (rareza, nivel y estrellas).
static func apply_power(state: Dictionary) -> void:
	for u: Variant in state.get("heroes", []):
		var d: Dictionary = u
		var m: float = power_mult(str(d["id"]))
		d["hp"] = float(d["hp"]) * m
		d["max_hp"] = float(d["max_hp"]) * m
		d["atk"] = float(d["atk"]) * m


# ------------------------------------------------------------------ invocar

static func pity() -> int:
	return int(Save.meta().get("pity", 0))


## Una invocacion (sin cobrar). Devuelve {"id", "rarity", "new", "stars", "refund"}.
static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var m: Dictionary = Save.meta()
	var p: int = pity() + 1
	var rar: String = "comun"
	if p >= PITY:
		rar = "legendario"
	else:
		var x: float = rng.randf() * 100.0
		var acc: float = 0.0
		for r: String in ["legendario", "epico", "raro", "comun"]:
			acc += float(RATES[r])
			if x < acc:
				rar = r
				break
	var pool: Array[String] = []
	for id: String in roster().keys():
		if rarity(id) == rar:
			pool.append(id)
	if pool.is_empty():
		pool = roster().keys()
	var id: String = pool[rng.randi_range(0, pool.size() - 1)]
	m["pity"] = 0 if rarity(id) == "legendario" else p
	Save.data["meta"] = m
	var col: Dictionary = _col()
	var res: Dictionary = {"id": id, "rarity": rarity(id), "new": not col.has(id), "stars": 1, "refund": 0}
	if col.has(id):
		if stars(id) < MAX_STARS:
			(col[id] as Dictionary)["stars"] = stars(id) + 1
		else:
			res["refund"] = DUP_REFUND
			Save.add_wallet(DUP_REFUND)
	else:
		col[id] = {"lv": 1, "stars": 1}
	res["stars"] = stars(id)
	return res


## Invoca n (1 o 10) cobrando la moneda. [] si no llega.
static func summon(n: int, rng: RandomNumberGenerator) -> Array:
	var cost: int = COST_TEN if n >= 10 else COST_ONE
	if not Save.spend(cost):
		return []
	var out: Array = []
	for i: int in (10 if n >= 10 else 1):
		out.append(roll(rng))
	Save.save_data()
	QA.log_event("summon", {"n": out.size(), "legend": out.filter(func(r: Dictionary) -> bool: return r["rarity"] == "legendario").size()})
	return out


# ------------------------------------------------------------------ botin mientras no juegas

static func idle_rate() -> int:
	return 40 + 15 * maxi(0, Save.unlocked_count() - 1)


## Moneda acumulada (hasta 12 horas). now: segundos unix (para las pruebas).
static func idle_pending(now: float = -1.0) -> int:
	var t: float = now if now >= 0.0 else Time.get_unix_time_from_system()
	var m: Dictionary = Save.meta()
	if not m.has("idle_t"):
		m["idle_t"] = t
		Save.data["meta"] = m
		return 0
	var h: float = clampf((t - float(m["idle_t"])) / 3600.0, 0.0, IDLE_CAP_H)
	return int(h * float(idle_rate()))


static func idle_claim(now: float = -1.0) -> int:
	var t: float = now if now >= 0.0 else Time.get_unix_time_from_system()
	var n: int = idle_pending(t)
	var m: Dictionary = Save.meta()
	m["idle_t"] = t
	Save.data["meta"] = m
	if n > 0:
		Save.add_wallet(n)
		QA.log_event("idle_claim", {"coins": n})
	Save.save_data()
	return n


# ------------------------------------------------------------------ dibujo

const ELEM_COL: Dictionary = {"fire": Color("#ff7043"), "water": Color("#42a5f5"), "nature": Color("#66bb6a"),
	"light": Color("#ffe082"), "dark": Color("#9575cd")}


## El dibujo del heroe: el de la fabrica (heroe_<id>; el primero del equipo de serie usa el del
## jugador) o una figura con el color de su elemento y su arma. Pies en (0, 0), alto h.
static func figure(id: String, h: float) -> Node2D:
	var art: Dictionary = Kit.sprite_entry("heroe_" + id)
	var d: Dictionary = hero(id)
	var base_party: Array = TurnsParty.catalog({"rpg": _rpg()}).get("party", [])
	if art.is_empty() and not base_party.is_empty() and str(base_party[0]) == id and str(d.get("look", "")) != "beast":
		art = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		var root: Node2D = Node2D.new()
		var spr: AnimatedSprite2D = SpriteKit.animado(art, h, "idle", true)
		root.add_child(spr)
		return root
	var fig: Node2D = Node2D.new()
	var col: Color = ELEM_COL.get(str(d.get("element", "")), Color("#b0bec5"))
	var lk: String = str(d.get("look", "sword"))
	fig.draw.connect(func() -> void:
		var s: float = h / 140.0
		if lk == "beast":
			fig.draw_circle(Vector2(0, -40) * s, 40.0 * s, col)
			fig.draw_colored_polygon(PackedVector2Array([Vector2(-30, -62) * s, Vector2(-18, -100) * s, Vector2(-8, -70) * s]), col.darkened(0.2))
			fig.draw_colored_polygon(PackedVector2Array([Vector2(30, -62) * s, Vector2(18, -100) * s, Vector2(8, -70) * s]), col.darkened(0.2))
			fig.draw_circle(Vector2(14, -48) * s, 7.0 * s, Color.WHITE)
			fig.draw_circle(Vector2(16, -48) * s, 3.5 * s, Color.BLACK)
			fig.draw_circle(Vector2(-6, -48) * s, 7.0 * s, Color.WHITE)
			fig.draw_circle(Vector2(-4, -48) * s, 3.5 * s, Color.BLACK)
			return
		fig.draw_rect(Rect2(Vector2(-22, -78) * s, Vector2(44, 70) * s), col)
		fig.draw_rect(Rect2(Vector2(-18, -10) * s, Vector2(14, 10) * s), col.darkened(0.4))
		fig.draw_rect(Rect2(Vector2(4, -10) * s, Vector2(14, 10) * s), col.darkened(0.4))
		fig.draw_circle(Vector2(0, -100) * s, 24.0 * s, Color("#ffd7b5"))
		fig.draw_circle(Vector2(8, -102) * s, 3.5 * s, Color.BLACK)
		match lk:
			"sword":
				fig.draw_line(Vector2(30, -40) * s, Vector2(52, -110) * s, Color("#e0e0e0"), 7.0 * s)
				fig.draw_line(Vector2(22, -50) * s, Vector2(40, -44) * s, Color("#8d6e63"), 6.0 * s)
			"staff":
				fig.draw_line(Vector2(32, 0) * s, Vector2(40, -120) * s, Color("#8d6e63"), 6.0 * s)
				fig.draw_circle(Vector2(40, -126) * s, 12.0 * s, col.lightened(0.4))
			"cross":
				fig.draw_rect(Rect2(Vector2(28, -86) * s, Vector2(10, 40) * s), Color("#fff8e1"))
				fig.draw_rect(Rect2(Vector2(18, -74) * s, Vector2(30, 10) * s), Color("#fff8e1"))
			"bow":
				fig.draw_arc(Vector2(26, -60) * s, 40.0 * s, -PI * 0.45, PI * 0.45, 12, Color("#8d6e63"), 6.0 * s)
		fig.draw_colored_polygon(PackedVector2Array([Vector2(-26, -112) * s, Vector2(0, -136) * s, Vector2(26, -112) * s]), col.darkened(0.25)))
	return fig

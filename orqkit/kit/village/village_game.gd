extends Node2D
## Aldea (asalto a una base, estilo juegos de clanes) en vista isometrica.
## 1 - Eliges una tropa abajo y tocas fuera de la base para soltarla (mantener suelta varias).
##     Guerrero: cuerpo a cuerpo. Arquera: dispara desde lejos y por encima de los muros.
##     Gigante: aguanta mucho y solo va a por las defensas.
## 2 - Las tropas van solas al edificio mas cercano; si un muro les corta el paso, lo rompen.
## 3 - Defensas: canon (un objetivo), torre arquera (mas alcance) y mortero (dano en area, no
##     dispara de cerca).
## 4 - Estrellas: 50 % de destruccion, el ayuntamiento y el 100 %. Con una estrella ganas.
##     El botin de oro y elixir de lo que destruyes va a tu monedero.
## Mapa: ver village_map.gd. Nivel: {"map", "army": {"guerrero": n, "arquera": n, "gigante": n},
##   "seconds", "base_hp" (multiplica la vida de los edificios), "def_dmg" (y el dano de las defensas)}.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const VMap = preload("res://kit/village/village_map.gd")
const VSave = preload("res://kit/village/village_save.gd")
const CW: float = 64.0
const CH: float = 32.0
const WALL_COST: float = 9.0
const SEP: float = 0.35
const ZOOM_IN: float = 1.35

var rows: Array[String] = []
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
var coins: int = 0
var coins_total: int = 0

var seconds: float = 150.0
var base_hp: float = 1.0
var def_dmg: float = 1.0
var army: Dictionary = {}
var left: Dictionary = {}
var selected: String = ""
var stars: int = 0
var destruction: float = 0.0
var hall_down: bool = false
var buildings: Array[Dictionary] = []
var troops: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var deployed: int = 0
## Ayudas de tu aldea (village_save.gd): fuerza de las tropas y botin extra.
var strength: float = 1.0
var loot_bonus: float = 1.0
## Nivel de cada edificio en tu aldea (para dibujarlos mas grandes); vacio en los asaltos.
var levels_by_cell: Dictionary = {}
## Asalto de liga en curso (copia de Online.liga_match); vacio en los niveles normales.
var liga: Dictionary = {}
## Repeticion de un asalto de liga (Online.liga_replay): se vuelve a simular igual, sin tocar nada.
var replay: Dictionary = {}
## Lo que se graba en un asalto: [paso de fisica, tropa, x, y, desvio x, desvio y] por cada tropa.
var record: Array = []
var _frame: int = 0
var _replay_i: int = 0

var _w: int = 0
var _h: int = 0
var _occ: Dictionary = {}
var _deploy: Dictionary = {}
var _flows: Dictionary = {}
var _counted: int = 0
var _ground: Node2D
var _world: Node2D
var _fx: Node2D
var _camera: Camera2D
var _hero_art: Dictionary = {}
var _guard_art: Dictionary = {}
var _zone_flash: float = 2.5
var _press: Dictionary = {}
var _hold_acc: float = 0.0
var _star_icons: Array[UiIcon] = []
var _pct_label: Label
var _time_label: Label
var _cards: HBoxContainer
var _ending: float = -1.0


func _ready() -> void:
	var lv: Dictionary = Kit.current_level()
	for r: Variant in lv.get("map", []):
		rows.append(str(r))
	seconds = float(lv.get("seconds", 150.0))
	base_hp = float(lv.get("base_hp", 1.0))
	def_dmg = float(lv.get("def_dmg", 1.0))
	army = (lv.get("army", {"guerrero": 10, "arquera": 6}) as Dictionary).duplicate()
	## Asalto de liga: la aldea de otro jugador (la elige el servidor) y el ejercito segun tu ayuntamiento.
	liga = Online.liga_match.duplicate()
	if not liga.is_empty():
		rows.clear()
		for r: Variant in liga.get("mapa", []):
			rows.append(str(r))
		var ayto: float = float(liga.get("ayto", 1))
		base_hp = 1.0 + 0.15 * (ayto - 1.0)
		def_dmg = 1.0 + 0.15 * (ayto - 1.0)
		seconds = 150.0
		army = VSave.liga_army(VSave.hall())
	replay = Online.liga_replay.duplicate(true)
	Online.liga_replay = {}
	if not replay.is_empty():
		liga = {}
		rows.clear()
		for r: Variant in replay.get("mapa", []):
			rows.append(str(r))
		base_hp = float(replay.get("base_hp", 1.0))
		def_dmg = float(replay.get("def_dmg", 1.0))
		seconds = float(replay.get("seconds", 150.0))
		army = (replay.get("army", {}) as Dictionary).duplicate()
	_hero_art = Kit.sprite_by_role("jugador")
	var gid: String = str(Kit.param("art.enemies.walker", ""))
	_guard_art = Kit.sprite_entry(gid) if gid != "" else {}
	if _guard_art.is_empty():
		_guard_art = Kit.sprite_by_role("enemigo")
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")).lerp(Color("#2f5a2a"), 0.6).darkened(0.35))
	## Lo que has construido en tu aldea ayuda en el asalto (mas tropas y mas fuertes).
	var bonus: Dictionary = VSave.bonus()
	if replay.is_empty():
		for k: String in ["guerrero", "arquera"]:
			if army.has(k):
				army[k] = int(army[k]) + int(bonus["troops"])
		strength = 1.0 + float(bonus["strength"])
		loot_bonus = 1.0 + float(bonus["loot"])
	_setup_layers()
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	if not replay.is_empty():
		QA.log_event("liga_replay", {"rival": str(replay.get("alias", "")), "events": (replay.get("eventos", []) as Array).size()})
		(get_node("Hud").find_child("Hint", true, false) as Label).text = Kit.text("replay_of", "Repetici\u00f3n: asalto de {name}").format({"name": str(replay.get("alias", ""))})
		_cards.visible = false
		Look.call("_dress")
	elif liga.is_empty():
		QA.log_event("level_start", {"level": Kit.level_index, "genre": "village", "buildings": buildings.size()})
	else:
		## Sin historia ni niveles: solo el acabado visual.
		QA.log_event("liga_start", {"rival": str(liga.get("alias", "")), "buildings": buildings.size()})
		Look.call("_dress")


## Tiene su propio suelo con arboles: sin fondo ilustrado detras.
func wants_backdrop() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/village_bot.gd"


func _setup_layers() -> void:
	_ground = Node2D.new()
	_ground.name = "Ground"
	_ground.draw.connect(_draw_ground)
	add_child(_ground)
	_world = Node2D.new()
	_world.name = "World"
	_world.y_sort_enabled = true
	add_child(_world)
	_fx = Node2D.new()
	_fx.name = "Fx"
	_fx.z_index = 10
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_camera = Camera2D.new()
	_camera.name = "Camera"
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)


# ------------------------------------------------------------------ montaje

func _reset() -> void:
	for c: Node in _world.get_children():
		_world.remove_child(c)
		c.queue_free()
	buildings.clear()
	troops.clear()
	shots.clear()
	_occ.clear()
	_flows.clear()
	finished = false
	failed = false
	time_in_level = 0.0
	coins = 0
	stars = 0
	destruction = 0.0
	hall_down = false
	deployed = 0
	_frame = 0
	_replay_i = 0
	record.clear()
	_ending = -1.0
	_zone_flash = 2.5
	left = army.duplicate()
	selected = ""
	for k: String in VMap.ORDER:
		if int(left.get(k, 0)) > 0 and selected == "":
			selected = k
	var parsed: Dictionary = VMap.parse(rows)
	_w = int(parsed["w"])
	_h = int(parsed["h"])
	coins_total = 0
	_counted = 0
	for b: Dictionary in parsed["buildings"]:
		var t: Dictionary = VMap.TYPES[b["key"]]
		var s: int = int(b["size"])
		var hp: float = float(t["hp"]) * base_hp
		var d: Dictionary = {"key": b["key"], "id": t["id"], "cell": b["cell"], "size": s, "hp": hp, "max_hp": hp,
			"alive": true, "def": bool(t.get("def", false)), "wall": bool(t.get("wall", false)), "cd": 1.0,
			"aim": PI * 0.75, "loot": int(t["loot"]), "h": float(t["h"]), "hit_t": 99.0}
		var idx: int = buildings.size()
		buildings.append(d)
		for dy: int in s:
			for dx: int in s:
				_occ[Vector2i(b["cell"]) + Vector2i(dx, dy)] = idx
		if not d["wall"]:
			_counted += 1
			coins_total += int(d["loot"]) / 10
		var n: Node2D = Node2D.new()
		n.name = "B%d" % idx
		n.position = iso(Vector2(b["cell"]) + Vector2(s, s))
		n.draw.connect(_draw_building.bind(n, idx))
		_world.add_child(n)
		d["node"] = n
		if d["id"] == "archer" and not _guard_art.is_empty():
			var g: AnimatedSprite2D = SpriteKit.animado(_guard_art, 40.0, "idle" if (_guard_art.get("animaciones", {}) as Dictionary).has("idle") else "run", true)
			g.position = iso(Vector2(s, s) * 0.5) - iso(Vector2(s, s)) + Vector2(0.0, -float(t["h"]) - 6.0)
			n.add_child(g)
			d["guard"] = g
	_deploy.clear()
	for c: Vector2i in VMap.deploy_cells(parsed):
		_deploy[c] = true
	_fit_camera()
	_ground.queue_redraw()
	_update_hud()


func _fit_camera() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var span: float = float(_w + _h) * CW * 0.5
	## Un poco mas cerca que "todo a lo ancho": se arrastra con el dedo para ver los lados.
	_camera.zoom = Vector2.ONE * clampf(vp.x / (span + 40.0) * ZOOM_IN, 0.3, 2.0)
	_camera.position = _view_center()


func _view_center() -> Vector2:
	return iso(Vector2(_w, _h) * 0.5) + Vector2(0.0, 20.0)


func _pan(by: Vector2) -> void:
	var c: Vector2 = _view_center()
	var half: float = float(_w + _h) * CW * 0.25
	var p: Vector2 = _camera.position - by / _camera.zoom.x
	_camera.position = Vector2(clampf(p.x, c.x - half * 0.5, c.x + half * 0.5), clampf(p.y, c.y - half * 0.35, c.y + half * 0.35))


func _build_hud() -> void:
	var hud: CanvasLayer = CanvasLayer.new()
	hud.name = "Hud"
	hud.layer = 20
	add_child(hud)
	var root: Control = Control.new()
	root.theme = UI.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var safe: MarginContainer = UI.safe_root(root, 20.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 6)
	col.add_child(bar)
	for i: int in 3:
		var st: UiIcon = UiIcon.make("star", UI.colors["texto_suave"], 44.0)
		_star_icons.append(st)
		bar.add_child(st)
	_pct_label = Label.new()
	_pct_label.name = "Destruction"
	_pct_label.theme_type_variation = "HeaderLabel"
	_pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pct_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_pct_label)
	_time_label = Label.new()
	_time_label.name = "Timer"
	bar.add_child(_time_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	bar.add_child(pause_btn)
	var hint: Label = Label.new()
	hint.name = "Hint"
	hint.theme_type_variation = "SubtleLabel"
	hint.text = Kit.text("village_hint", "Elige una tropa y toca fuera de la base")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	_cards = HBoxContainer.new()
	_cards.name = "Cards"
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 12)
	col.add_child(_cards)


func _rebuild_cards() -> void:
	for c: Node in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	for k: String in VMap.ORDER:
		if not army.has(k):
			continue
		var b: Button = UI.make_button("%s\nx%d" % [Kit.text("troop_" + k, k.capitalize()), int(left.get(k, 0))], k == selected, "")
		b.name = "Card_" + k
		b.custom_minimum_size = Vector2(150, 120)
		b.disabled = int(left.get(k, 0)) <= 0
		b.pressed.connect(select.bind(k))
		_cards.add_child(b)


func select(kind: String) -> void:
	if int(left.get(kind, 0)) <= 0:
		return
	selected = kind
	_rebuild_cards()


func _update_hud() -> void:
	if _pct_label == null:
		return
	_pct_label.text = "%d %%" % int(destruction)
	var t: int = int(ceil(maxf(seconds - time_in_level, 0.0)))
	_time_label.text = "%d:%02d" % [t / 60, t % 60]
	for i: int in 3:
		_star_icons[i].color = Kit.color("coin", Color("#ffcf3f")) if i < stars else (UI.colors["texto_suave"] as Color).darkened(0.3)
		_star_icons[i].queue_redraw()
	if _cards.get_child_count() == 0:
		_rebuild_cards()


# ------------------------------------------------------------------ geometria

func iso(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * CW * 0.5, (p.x + p.y) * CH * 0.5)


func from_iso(s: Vector2) -> Vector2:
	var a: float = s.x / (CW * 0.5)
	var b: float = s.y / (CH * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


func center_of(i: int) -> Vector2:
	var b: Dictionary = buildings[i]
	return Vector2(b["cell"]) + Vector2.ONE * float(b["size"]) * 0.5


func dist_to(i: int, p: Vector2) -> float:
	var b: Dictionary = buildings[i]
	var o: Vector2 = Vector2(b["cell"])
	var s: float = float(b["size"])
	var q: Vector2 = Vector2(clampf(p.x, o.x, o.x + s), clampf(p.y, o.y, o.y + s))
	return q.distance_to(p)


func can_deploy(cell: Vector2i) -> bool:
	return _deploy.has(cell)


func deploy_cells() -> Array:
	return _deploy.keys()


func _blocked(c: Vector2i, except: int) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= _w or c.y >= _h:
		return true
	var i: int = int(_occ.get(c, -1))
	return i >= 0 and i != except and not bool(buildings[i]["wall"])


## Coste hasta el edificio i desde cada casilla (los muros cuestan WALL_COST: se rodean si hay hueco cerca).
func flow(i: int) -> Dictionary:
	if _flows.has(i):
		return _flows[i]
	var cost: Dictionary = {}
	var open: Array[Vector2i] = []
	var b: Dictionary = buildings[i]
	var s: int = int(b["size"])
	var o: Vector2i = b["cell"]
	for y: int in range(o.y - 1, o.y + s + 1):
		for x: int in range(o.x - 1, o.x + s + 1):
			var c: Vector2i = Vector2i(x, y)
			if int(_occ.get(c, -1)) == i or _blocked(c, i):
				continue
			cost[c] = _enter_cost(c)
			open.append(c)
	while not open.is_empty():
		var bi: int = 0
		for k: int in range(1, open.size()):
			if float(cost[open[k]]) < float(cost[open[bi]]):
				bi = k
		var cur: Vector2i = open[bi]
		open.remove_at(bi)
		for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var nc: Vector2i = cur + n
			if _blocked(nc, -1) or int(_occ.get(nc, -1)) == i:
				continue
			if n.x != 0 and n.y != 0 and (_blocked(cur + Vector2i(n.x, 0), -1) or _blocked(cur + Vector2i(0, n.y), -1)):
				continue
			var step: float = (1.414 if n.x != 0 and n.y != 0 else 1.0)
			var nv: float = float(cost[cur]) + step + (_enter_cost(cur) - 1.0)
			if not cost.has(nc) or nv < float(cost[nc]):
				if not cost.has(nc):
					open.append(nc)
				cost[nc] = nv
	_flows[i] = cost
	return cost


func _enter_cost(c: Vector2i) -> float:
	var i: int = int(_occ.get(c, -1))
	return 1.0 + WALL_COST if i >= 0 and bool(buildings[i]["wall"]) else 1.0


# ------------------------------------------------------------------ tropas

## Fuerza de cada tropa: mejora de la tienda (+12 % por nivel) y lo construido en tu aldea.
## En una repeticion, la del atacante (viene grabada).
func troop_up() -> float:
	if not replay.is_empty():
		return float(replay.get("up", 1.0))
	return (1.0 + 0.12 * float(Save.upgrade_level("tropas"))) * strength


func deploy(kind: String, cell: Vector2i, jitter: Vector2 = Vector2.INF) -> bool:
	if finished or failed or int(left.get(kind, 0)) <= 0 or not can_deploy(cell):
		if not finished and not failed and not can_deploy(cell):
			_zone_flash = 1.2
		return false
	left[kind] = int(left[kind]) - 1
	deployed += 1
	var t: Dictionary = VMap.TROOPS[kind]
	var up: float = troop_up()
	## Desvio al soltar, redondeado: asi la repeticion lo reproduce exacto.
	var jit: Vector2 = jitter
	if jit == Vector2.INF:
		jit = Vector2(snappedf(randf_range(-0.2, 0.2), 0.001), snappedf(randf_range(-0.2, 0.2), 0.001))
	if replay.is_empty():
		record.append([_frame, kind, cell.x, cell.y, jit.x, jit.y])
	var p: Vector2 = Vector2(cell) + Vector2(0.5, 0.5) + jit
	var n: Node2D = Node2D.new()
	n.position = iso(p)
	var rig: Node2D = Node2D.new()
	rig.name = "Rig"
	n.add_child(rig)
	var scale_k: float = 1.45 if kind == "gigante" else 1.0
	if not _hero_art.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(_hero_art, 44.0 * scale_k, "run" if (_hero_art.get("animaciones", {}) as Dictionary).has("run") else "idle", true)
		spr.modulate = {"guerrero": Color.WHITE, "arquera": Color(0.75, 1.0, 0.7), "gigante": Color(1.0, 0.78, 0.66)}[kind]
		rig.add_child(spr)
	else:
		var body: Polygon2D = Polygon2D.new()
		body.polygon = LevelBuilder._circle(12.0 * scale_k, 16)
		body.position = Vector2(0, -14.0 * scale_k)
		body.color = Kit.color("accent", Color.ORANGE)
		rig.add_child(body)
	n.draw.connect(func() -> void:
		n.draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.5))
		n.draw_circle(Vector2.ZERO, 13.0 * scale_k, Color(0, 0, 0, 0.3))
		n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	_world.add_child(n)
	troops.append({"kind": kind, "pos": p, "hp": float(t["hp"]) * up, "max_hp": float(t["hp"]) * up, "alive": true, "target": -1,
		"cd": 0.3, "node": n, "rig": rig, "hit_t": 99.0, "goal": -1, "up": up})
	Juice.burst(_fx, iso(p), Color(1, 1, 1, 0.8), 6, 120.0)
	Audio.play("jump", 0.1, -10.0)
	if int(left[kind]) <= 0:
		for k: String in VMap.ORDER:
			if int(left.get(k, 0)) > 0:
				selected = k
				break
	_rebuild_cards()
	return true


func _pick_target(tr: Dictionary) -> int:
	var pref: String = str(VMap.TROOPS[tr["kind"]]["pref"])
	var best: int = -1
	var best_d: float = 1e9
	for pass_i: int in 2:
		for i: int in buildings.size():
			var b: Dictionary = buildings[i]
			if not b["alive"] or b["wall"]:
				continue
			if pass_i == 0 and pref == "def" and not b["def"]:
				continue
			var d: float = dist_to(i, tr["pos"])
			if d < best_d:
				best_d = d
				best = i
		if best >= 0 or pref == "":
			break
	return best


func _step_troops(delta: float) -> void:
	for tr: Dictionary in troops:
		if not tr["alive"]:
			continue
		var t: Dictionary = VMap.TROOPS[tr["kind"]]
		tr["cd"] = float(tr["cd"]) - delta
		tr["hit_t"] = float(tr["hit_t"]) + delta
		var tgt: int = int(tr["target"])
		if tgt < 0 or not buildings[tgt]["alive"]:
			tgt = _pick_target(tr)
			tr["target"] = tgt
		if tgt < 0:
			continue
		var p: Vector2 = tr["pos"]
		var rng: float = float(t["range"])
		var hit_idx: int = -1
		if dist_to(tgt, p) <= rng + 0.15:
			hit_idx = tgt
		else:
			## Siguiente casilla del camino; si es un muro, se rompe.
			var f: Dictionary = flow(tgt)
			var here: Vector2i = Vector2i(floori(p.x), floori(p.y))
			var best: Vector2i = here
			var best_c: float = float(f.get(here, 1e9))
			for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				var nc: Vector2i = here + n
				if f.has(nc) and float(f[nc]) < best_c:
					best_c = float(f[nc])
					best = nc
			var wi: int = int(_occ.get(best, -1))
			if best != here and wi >= 0 and buildings[wi]["wall"] and buildings[wi]["alive"]:
				if dist_to(wi, p) <= maxf(rng, 0.7) + 0.15:
					hit_idx = wi
				else:
					_walk(tr, Vector2(best) + Vector2(0.5, 0.5), float(t["speed"]), delta)
			else:
				var goal: Vector2 = Vector2(best) + Vector2(0.5, 0.5) if best != here else center_of(tgt)
				_walk(tr, goal, float(t["speed"]), delta)
		if hit_idx >= 0 and float(tr["cd"]) <= 0.0:
			tr["cd"] = float(t["rate"])
			if tr["kind"] == "arquera":
				shots.append({"kind": "arrow_up", "from": p, "to": center_of(hit_idx), "t": 0.0, "dur": 0.35, "target_b": hit_idx, "dmg": float(t["dmg"]) * float(tr["up"])})
			else:
				_damage_building(hit_idx, float(t["dmg"]) * float(tr["up"]))
				var rig: Node2D = tr["rig"]
				Juice.squash(rig, Vector2(1.25, 0.8), 0.15)
				if tr["kind"] == "gigante":
					Juice.shake(0.06)
	## Se separan un poco (nadie se monta encima de otro).
	for a: int in troops.size():
		var ta: Dictionary = troops[a]
		if not ta["alive"]:
			continue
		for b: int in range(a + 1, troops.size()):
			var tb: Dictionary = troops[b]
			if not tb["alive"]:
				continue
			var d: Vector2 = (ta["pos"] as Vector2) - (tb["pos"] as Vector2)
			var l: float = d.length()
			if l < SEP and l > 0.001:
				var push: Vector2 = d / l * (SEP - l) * 0.5
				ta["pos"] = _slide(ta["pos"], push)
				tb["pos"] = _slide(tb["pos"], -push)
	for tr: Dictionary in troops:
		if tr["alive"]:
			(tr["node"] as Node2D).position = iso(tr["pos"])


func _slide(p: Vector2, d: Vector2) -> Vector2:
	var q: Vector2 = p + d
	return q if not _blocked(Vector2i(floori(q.x), floori(q.y)), -1) and int(_occ.get(Vector2i(floori(q.x), floori(q.y)), -1)) < 0 else p


func _walk(tr: Dictionary, goal: Vector2, speed: float, delta: float) -> void:
	var p: Vector2 = tr["pos"]
	var to: Vector2 = goal - p
	if to.length() < 0.02:
		return
	var step: Vector2 = to.normalized() * minf(speed * delta, to.length())
	tr["pos"] = p + step
	var spr: Node = (tr["rig"] as Node2D).get_child(0) if (tr["rig"] as Node2D).get_child_count() > 0 else null
	if spr is AnimatedSprite2D:
		(spr as AnimatedSprite2D).flip_h = iso(step).x < 0.0


func _hurt_troop(tr: Dictionary, dmg: float) -> void:
	if not tr["alive"]:
		return
	tr["hp"] = float(tr["hp"]) - dmg
	tr["hit_t"] = 0.0
	if float(tr["hp"]) <= 0.0:
		tr["alive"] = false
		var n: Node2D = tr["node"]
		Juice.burst(_fx, n.position + Vector2(0, -16), Color(1, 1, 1, 0.9), 8, 160.0)
		n.queue_free()
		QA.log_event("troop_down", {"kind": tr["kind"]})


# ------------------------------------------------------------------ edificios y defensas

func _damage_building(i: int, dmg: float) -> void:
	var b: Dictionary = buildings[i]
	if not b["alive"]:
		return
	b["hp"] = float(b["hp"]) - dmg
	b["hit_t"] = 0.0
	var n: Node2D = b["node"]
	n.queue_redraw()
	if float(b["hp"]) > 0.0:
		return
	b["alive"] = false
	_flows.clear()
	for dy: int in int(b["size"]):
		for dx: int in int(b["size"]):
			_occ.erase(Vector2i(b["cell"]) + Vector2i(dx, dy))
	if b.has("guard"):
		(b["guard"] as Node).queue_free()
		b.erase("guard")
	var at: Vector2 = iso(center_of(i)) + Vector2(0, -float(b["h"]) * 0.5)
	if not b["wall"]:
		Juice.burst(_fx, at, Color("#c9a26b"), 18, 300.0)
		Juice.ring(_fx, iso(center_of(i)), Color(1, 0.9, 0.6), 30.0 * float(b["size"]), 0.35)
		Juice.shake(0.2)
		Audio.play("stomp")
		if int(b["loot"]) > 0:
			var gain: int = int(round(float(int(b["loot"]) / 10) * loot_bonus))
			coins += gain
			UI.float_text(_fx, at + Vector2(0, -30), "+%d" % gain, Kit.color("coin", Color("#ffcf3f")), 30)
		if b["id"] == "hall":
			hall_down = true
			UI.float_text(_fx, at + Vector2(0, -80), Kit.text("village_hall_down", "\u00a1Ayuntamiento destruido!"), Color("#ffe066"), 34)
	else:
		Juice.burst(_fx, at, Color("#9aa3ad"), 6, 160.0)
	_recount()
	n.queue_redraw()


func _recount() -> void:
	var down: int = 0
	for b: Dictionary in buildings:
		if not b["wall"] and not b["alive"]:
			down += 1
	destruction = 100.0 * float(down) / float(maxi(_counted, 1))
	var s: int = 0
	if destruction >= 50.0:
		s += 1
	if hall_down:
		s += 1
	if destruction >= 99.99:
		s += 1
	if s > stars:
		for k: int in range(stars, s):
			UI.pop_in(_star_icons[k], 0.0)
		Audio.play("coin")
	stars = maxi(stars, s)


func _step_defenses(delta: float) -> void:
	for i: int in buildings.size():
		var b: Dictionary = buildings[i]
		b["hit_t"] = float(b["hit_t"]) + delta
		if not b["alive"] or not b["def"]:
			continue
		var t: Dictionary = VMap.TYPES[b["key"]]
		b["cd"] = float(b["cd"]) - delta
		var c: Vector2 = center_of(i)
		var best: Dictionary = {}
		var best_d: float = float(t["range"])
		for tr: Dictionary in troops:
			if not tr["alive"]:
				continue
			var d: float = (tr["pos"] as Vector2).distance_to(c)
			if d <= best_d and d >= float(t.get("min", 0.0)):
				best_d = d
				best = tr
		if best.is_empty():
			continue
		var dir: Vector2 = iso(best["pos"]) - iso(c)
		b["aim"] = dir.angle()
		(b["node"] as Node2D).queue_redraw()
		if float(b["cd"]) > 0.0:
			continue
		b["cd"] = float(t["rate"])
		var dmg: float = float(t["dmg"]) * def_dmg
		match str(b["id"]):
			"cannon":
				shots.append({"kind": "ball", "from": c, "to": best["pos"], "t": 0.0, "dur": 0.22, "troop": best, "dmg": dmg})
				Audio.play("shoot", 0.1, -12.0)
			"archer":
				shots.append({"kind": "arrow", "from": c, "to": best["pos"], "t": 0.0, "dur": 0.3, "troop": best, "dmg": dmg, "h0": float(b["h"])})
			"mortar":
				shots.append({"kind": "shell", "from": c, "to": best["pos"], "t": 0.0, "dur": 1.3, "dmg": dmg, "splash": float(t["splash"])})
				Audio.play("shoot", 0.1, -8.0)


func _step_shots(delta: float) -> void:
	var i: int = shots.size() - 1
	while i >= 0:
		var s: Dictionary = shots[i]
		s["t"] = float(s["t"]) + delta
		if float(s["t"]) >= float(s["dur"]):
			match str(s["kind"]):
				"ball", "arrow":
					_hurt_troop(s["troop"], float(s["dmg"]))
				"shell":
					var at: Vector2 = s["to"]
					for tr: Dictionary in troops:
						if tr["alive"] and (tr["pos"] as Vector2).distance_to(at) <= float(s["splash"]):
							_hurt_troop(tr, float(s["dmg"]))
					Juice.burst(_fx, iso(at), Color("#ffb04a"), 12, 220.0)
					Juice.ring(_fx, iso(at), Color(1.0, 0.7, 0.3), float(s["splash"]) * CW * 0.6, 0.3)
				"arrow_up":
					_damage_building(int(s["target_b"]), float(s["dmg"]))
			shots.remove_at(i)
		i -= 1


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	if finished or failed or get_tree().paused:
		return
	## Repeticion: las tropas salen en el mismo paso de fisica que en el asalto de verdad.
	if not replay.is_empty():
		var evs: Array = replay.get("eventos", [])
		while _replay_i < evs.size() and int((evs[_replay_i] as Array)[0]) <= _frame:
			var e: Array = evs[_replay_i]
			deploy(str(e[1]), Vector2i(int(e[2]), int(e[3])), Vector2(float(e[4]), float(e[5])))
			_replay_i += 1
	time_in_level += delta
	var zone_was: float = _zone_flash
	_zone_flash = maxf(_zone_flash - delta, 0.0)
	_step_troops(delta)
	_step_defenses(delta)
	_step_shots(delta)
	_frame += 1
	_hold_deploy(delta)
	_fx.queue_redraw()
	if zone_was > 0.0:
		_ground.queue_redraw()
	_update_hud()
	## Final: todo destruido, sin tiempo o sin tropas (ni vivas ni por soltar).
	var any_alive: bool = false
	for tr: Dictionary in troops:
		if tr["alive"]:
			any_alive = true
			break
	var any_left: bool = false
	for k: String in left.keys():
		if int(left[k]) > 0:
			any_left = true
	var over: bool = destruction >= 99.99 or time_in_level >= seconds or (not any_alive and not any_left and shots.is_empty())
	if over and _ending < 0.0:
		_ending = 0.8
	if _ending >= 0.0:
		_ending -= delta
		if _ending <= 0.0:
			_end()


func _hold_deploy(delta: float) -> void:
	if _press.is_empty() or bool(_press.get("moved", false)):
		return
	_press["t"] = float(_press["t"]) + delta
	if float(_press["t"]) < 0.35:
		return
	_hold_acc += delta
	if _hold_acc >= 0.12:
		_hold_acc = 0.0
		var j: Vector2 = Vector2(randf_range(-6, 6), randf_range(-6, 6))
		deploy(selected, _screen_cell(_press["at"] + j))


func _screen_cell(screen: Vector2) -> Vector2i:
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen
	var p: Vector2 = from_iso(world)
	return Vector2i(floori(p.x), floori(p.y))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	## Solo raton: el toque llega emulado como raton (emulate_mouse_from_touch), asi no se suelta doble.
	var pos: Vector2 = Vector2.ZERO
	var pressed: int = -1
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m: InputEventMouseButton = event as InputEventMouseButton
		pos = m.position
		pressed = 1 if m.pressed else 0
	elif event is InputEventMouseMotion:
		if not _press.is_empty():
			var at: Vector2 = (event as InputEventMouseMotion).position
			if at.distance_to(_press["at"]) > 18.0:
				_press["moved"] = true
			if bool(_press["moved"]):
				_pan((event as InputEventMouseMotion).relative)
		return
	if pressed == 1 and not replay.is_empty():
		return
	if pressed == 1:
		_press = {"at": pos, "t": 0.0, "moved": false}
		_hold_acc = 0.0
	elif pressed == 0 and not _press.is_empty():
		if not bool(_press["moved"]) and float(_press["t"]) < 0.35:
			deploy(selected, _screen_cell(pos))
		_press = {}


func _end() -> void:
	if not replay.is_empty():
		finished = true
		QA.log_event("liga_replay_end", {"stars": stars, "destruction": int(destruction)})
		LigaPanel.open_replay_end(self, replay, stars, int(destruction))
		return
	if not liga.is_empty():
		_end_liga()
		return
	if stars >= 1:
		_win()
	else:
		_lose()


func _win() -> void:
	finished = true
	var level_id: String = str(Kit.level_index)
	var score: int = int(destruction) * 100 + coins * 10 + int(maxf(seconds - time_in_level, 0.0)) * 5
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "destruction": int(destruction), "loot": coins,
		"troops": deployed, "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Fin de un asalto de liga: el servidor reparte trofeos; el botin va al monedero.
func _end_liga() -> void:
	finished = true
	Online.liga_match = {}
	if coins > 0:
		Save.add_wallet(coins)
	QA.log_event("liga_end", {"stars": stars, "destruction": int(destruction), "loot": coins})
	Audio.play("win" if stars >= 1 else "hurt")
	var r: Dictionary = await Online.liga_result(int(liga.get("ataque", 0)), stars, int(destruction))
	## Repeticion para el defensor: con lo necesario para volver a simularlo igual.
	if not r.is_empty():
		Online.liga_replay_upload(int(liga.get("ataque", 0)), replay_data())
	if not is_inside_tree():
		return
	LigaPanel.open_result(self, liga, stars, int(destruction), coins, r)


func replay_data() -> Dictionary:
	return {"v": 1, "mapa": rows.duplicate(), "army": army.duplicate(), "base_hp": base_hp, "def_dmg": def_dmg,
		"seconds": seconds, "up": troop_up(), "eventos": record.duplicate(true)}


func stars_earned() -> int:
	return stars


func _lose() -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "village", "destruction": int(destruction), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("village_lose", "\u00a1Asalto fallido!"),
		Kit.text("village_fail_hint", "Has destruido el {n} %. Llega al 50 % o tira el ayuntamiento.").format({"n": int(destruction)}))
	p.closed.connect(retry)


func retry() -> void:
	_reset()
	_rebuild_cards()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_press = {}
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	var alive: int = 0
	for tr: Dictionary in troops:
		if tr["alive"]:
			alive += 1
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stars": stars,
		"destruction": destruction, "troops_alive": alive, "deployed": deployed, "time": time_in_level, "stomps": 0}


func capture_delays() -> Vector2:
	return Vector2(9.0, 2.0)


# ------------------------------------------------------------------ dibujo

func _grass() -> Color:
	return Kit.color("solid", Color("#3e5c84")).lerp(Color("#5cae4a"), 0.72)


func _draw_ground() -> void:
	var g: Color = _grass()
	var pad: float = 16.0
	## Hierba de fuera (mas oscura) con arboles alrededor.
	var outer: PackedVector2Array = PackedVector2Array([iso(Vector2(-pad, -pad)), iso(Vector2(_w + pad, -pad)), iso(Vector2(_w + pad, _h + pad)), iso(Vector2(-pad, _h + pad))])
	_ground.draw_colored_polygon(outer, g.darkened(0.28))
	var tex: Texture2D = Kit.first_tile_texture()
	for y: int in _h:
		for x: int in _w:
			var c: Vector2 = Vector2(x, y)
			var poly: PackedVector2Array = PackedVector2Array([iso(c), iso(c + Vector2(1, 0)), iso(c + Vector2(1, 1)), iso(c + Vector2(0, 1))])
			var col: Color = g if (x + y) % 2 == 0 else g.darkened(0.05)
			if _zone_flash > 0.0 and not _deploy.has(Vector2i(x, y)):
				col = col.lerp(Color(1, 1, 1), 0.18 * minf(_zone_flash, 1.0))
			_ground.draw_colored_polygon(poly, col)
	## Borde de la parcela.
	var edge: PackedVector2Array = PackedVector2Array([iso(Vector2.ZERO), iso(Vector2(_w, 0)), iso(Vector2(_w, _h)), iso(Vector2(0, _h)), iso(Vector2.ZERO)])
	_ground.draw_polyline(edge, g.lightened(0.25), 4.0, true)
	if tex != null:
		for k: int in 18:
			var a: Vector2 = Vector2(float((k * 7) % _w), float((k * 11) % _h)) + Vector2(0.5, 0.5)
			if not _occ.has(Vector2i(a)):
				_ground.draw_texture_rect(tex, Rect2(iso(a) - Vector2(10, 5), Vector2(20, 10)), false, Color(1, 1, 1, 0.08))
	## Arboles fuera de la parcela.
	for k: int in 76:
		var side: int = k % 4
		var u: float = fposmod(float(k) * 0.618, 1.0)
		var p: Vector2
		match side:
			0:
				p = Vector2(u * float(_w + 6) - 3.0, -2.2 - fposmod(float(k) * 0.37, 1.0) * 5.0)
			1:
				p = Vector2(float(_w) + 1.8 + fposmod(float(k) * 0.37, 1.0) * 5.0, u * float(_h + 6) - 3.0)
			2:
				p = Vector2(u * float(_w + 6) - 3.0, float(_h) + 1.8 + fposmod(float(k) * 0.37, 1.0) * 5.0)
			_:
				p = Vector2(-2.2 - fposmod(float(k) * 0.37, 1.0) * 5.0, u * float(_h + 6) - 3.0)
		var s: Vector2 = iso(p)
		var r: float = 20.0 + 8.0 * fposmod(float(k) * 0.71, 1.0)
		_ground.draw_set_transform(s + Vector2(0, 4), 0.0, Vector2(1.0, 0.5))
		_ground.draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.25))
		_ground.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_ground.draw_rect(Rect2(s + Vector2(-3, -14), Vector2(6, 14)), Color("#6b4a32"))
		_ground.draw_circle(s + Vector2(0, -24), r, g.darkened(0.45))
		_ground.draw_circle(s + Vector2(-r * 0.3, -30), r * 0.6, g.darkened(0.25))


## Prisma isometrico: huella (con margen) y altura; devuelve la cara de arriba.
func _prism(n: Node2D, i: int, inset: float, hgt: float, side: Color, top: Color) -> PackedVector2Array:
	var b: Dictionary = buildings[i]
	var o: Vector2 = Vector2(b["cell"])
	var s: float = float(b["size"])
	var base: Vector2 = iso(o + Vector2(s, s))
	var up: Vector2 = Vector2(0, -hgt)
	var t: Vector2 = iso(o + Vector2(inset, inset)) - base
	var r: Vector2 = iso(o + Vector2(s - inset, inset)) - base
	var l: Vector2 = iso(o + Vector2(inset, s - inset)) - base
	var bt: Vector2 = iso(o + Vector2(s - inset, s - inset)) - base
	n.draw_colored_polygon(PackedVector2Array([l, bt, bt + up, l + up]), side.darkened(0.18))
	n.draw_colored_polygon(PackedVector2Array([bt, r, r + up, bt + up]), side.darkened(0.38))
	var topf: PackedVector2Array = PackedVector2Array([t + up, r + up, bt + up, l + up])
	n.draw_colored_polygon(topf, top)
	var outline: PackedVector2Array = topf.duplicate()
	outline.append(topf[0])
	n.draw_polyline(outline, top.lightened(0.25), 2.0, true)
	return topf


func _draw_building(n: Node2D, i: int) -> void:
	var b: Dictionary = buildings[i]
	var o: Vector2 = Vector2(b["cell"])
	var s: float = float(b["size"])
	var base: Vector2 = iso(o + Vector2(s, s))
	var ctr: Vector2 = iso(o + Vector2(s, s) * 0.5) - base
	var stone: Color = Kit.color("solid", Color("#7c8aa5")).lerp(Color("#a49a8a"), 0.5)
	var acc: Color = Kit.color("accent", Color("#e8b04b"))
	if not b["alive"]:
		## Escombros.
		var foot: PackedVector2Array = PackedVector2Array([iso(o + Vector2(0.15, 0.15)) - base, iso(o + Vector2(s - 0.15, 0.15)) - base, iso(o + Vector2(s - 0.15, s - 0.15)) - base, iso(o + Vector2(0.15, s - 0.15)) - base])
		n.draw_colored_polygon(foot, Color(0.18, 0.15, 0.12, 0.75))
		for k: int in int(4 * s):
			var q: Vector2 = ctr + Vector2(sin(float(k) * 2.3) * CW * 0.25 * s, cos(float(k) * 1.7) * CH * 0.22 * s)
			n.draw_circle(q, 4.0 + float(k % 3) * 2.0, stone.darkened(0.3 + 0.1 * float(k % 2)))
		return
	var flash: bool = float(b["hit_t"]) < 0.08
	var lvl: int = int(levels_by_cell.get(b["cell"], 0))
	match str(b["id"]):
		"wall":
			_prism(n, i, 0.12, float(b["h"]), stone, stone.lightened(0.18))
		"hall":
			var top: PackedVector2Array = _prism(n, i, 0.2, float(b["h"]), Color("#c9b48a"), Color("#d8c59c"))
			var apex: Vector2 = ctr + Vector2(0, -float(b["h"]) - 46.0)
			n.draw_colored_polygon(PackedVector2Array([top[3], top[2], apex]), acc.darkened(0.15))
			n.draw_colored_polygon(PackedVector2Array([top[2], top[1], apex]), acc.darkened(0.4))
			n.draw_line(apex, apex + Vector2(0, -26), Color("#4a3a2a"), 3.0)
			n.draw_colored_polygon(PackedVector2Array([apex + Vector2(0, -26), apex + Vector2(18, -21), apex + Vector2(0, -16)]), Color("#ff5a4f"))
			n.draw_rect(Rect2(ctr + Vector2(-9, -22), Vector2(18, 22)), Color("#5a3a22"))
		"gold", "elixir", "mine":
			var col: Color = {"gold": Color("#e9b949"), "elixir": Color("#b55cff"), "mine": Color("#a77a4a")}[b["id"]]
			var top2: PackedVector2Array = _prism(n, i, 0.25, float(b["h"]), Color("#8a6a4a"), Color("#a5825c"))
			var tc: Vector2 = (top2[0] + top2[2]) * 0.5
			if b["id"] == "elixir":
				n.draw_circle(tc + Vector2(0, -14), 22.0, col)
				n.draw_circle(tc + Vector2(-7, -21), 7.0, Color(1, 1, 1, 0.45))
			elif b["id"] == "gold":
				for k: int in 6:
					n.draw_circle(tc + Vector2(-12.0 + 8.0 * float(k % 3), -4.0 - 7.0 * float(k / 3)), 7.0, col.lightened(0.1 * float(k % 2)))
			else:
				n.draw_circle(tc + Vector2(0, -6), 12.0, Color("#3a2a1a"))
				n.draw_arc(tc + Vector2(0, -6), 12.0, PI, TAU, 12, col, 4.0)
		"house":
			var top3: PackedVector2Array = _prism(n, i, 0.25, float(b["h"]), Color("#d9cdb0"), Color("#e6dcc2"))
			var ridge_a: Vector2 = (top3[0] + top3[3]) * 0.5 + Vector2(0, -24)
			var ridge_b: Vector2 = (top3[1] + top3[2]) * 0.5 + Vector2(0, -24)
			n.draw_colored_polygon(PackedVector2Array([top3[3], top3[2], ridge_b, ridge_a]), Color("#c0503a"))
			n.draw_colored_polygon(PackedVector2Array([top3[2], top3[1], ridge_b]), Color("#8f3a2a"))
		"cannon":
			var top4: PackedVector2Array = _prism(n, i, 0.18, float(b["h"]), stone, stone.lightened(0.12))
			var tc4: Vector2 = (top4[0] + top4[2]) * 0.5
			var dir: Vector2 = Vector2.RIGHT.rotated(float(b["aim"]))
			n.draw_circle(tc4, 16.0, Color("#3a3a44"))
			n.draw_line(tc4, tc4 + dir * Vector2(34, 20), Color("#24242c"), 13.0, true)
			n.draw_circle(tc4 + dir * Vector2(34, 20), 7.0, Color("#15151a"))
		"archer":
			var top5: PackedVector2Array = _prism(n, i, 0.3, float(b["h"]), Color("#8a5a32"), Color("#a8743f"))
			var tc5: Vector2 = (top5[0] + top5[2]) * 0.5
			n.draw_colored_polygon(PackedVector2Array([top5[0] + Vector2(0, -6), top5[1] + Vector2(6, -2), top5[2] + Vector2(0, 4), top5[3] + Vector2(-6, -2)]), Color("#6b4426"))
			n.draw_line(tc5 + Vector2(0, -2), tc5 + Vector2(0, -50), Color("#4a3a2a"), 3.0)
			n.draw_colored_polygon(PackedVector2Array([tc5 + Vector2(0, -50), tc5 + Vector2(20, -44), tc5 + Vector2(0, -38)]), acc)
		"mortar":
			var top6: PackedVector2Array = _prism(n, i, 0.18, float(b["h"]), stone.darkened(0.1), stone)
			var tc6: Vector2 = (top6[0] + top6[2]) * 0.5
			n.draw_set_transform(tc6, 0.0, Vector2(1.0, 0.55))
			n.draw_circle(Vector2.ZERO, 22.0, Color("#2a2a30"))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			n.draw_rect(Rect2(tc6 + Vector2(-10, -26), Vector2(20, 24)), Color("#3a3a44"))
			n.draw_set_transform(tc6 + Vector2(0, -26), 0.0, Vector2(1.0, 0.5))
			n.draw_circle(Vector2.ZERO, 10.0, Color("#101014"))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	## En tu aldea: insignia con el nivel del edificio.
	if lvl > 0 and not b["wall"]:
		var badge: Vector2 = ctr + Vector2(CW * 0.35 * s, -float(b["h"]) - 8.0)
		n.draw_circle(badge, 13.0, Color(0.08, 0.08, 0.12, 0.9))
		n.draw_circle(badge, 10.0, acc if lvl >= 3 else (Color("#c0c8d8") if lvl == 2 else Color("#c98a3c")))
		var f: Font = UI.font
		if f != null:
			n.draw_string(f, badge + Vector2(-5, 7), str(lvl), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.08, 0.08, 0.12))
	if flash:
		n.modulate = Color(1.6, 1.6, 1.6)
	else:
		n.modulate = Color.WHITE


func _draw_fx() -> void:
	## Proyectiles.
	for s: Dictionary in shots:
		var k: float = clampf(float(s["t"]) / float(s["dur"]), 0.0, 1.0)
		var to: Vector2 = s["to"]
		if s.has("troop") and (s["troop"] as Dictionary)["alive"]:
			to = (s["troop"] as Dictionary)["pos"]
		var a: Vector2 = iso(s["from"])
		var b: Vector2 = iso(to)
		match str(s["kind"]):
			"ball":
				_fx.draw_circle(a.lerp(b, k) + Vector2(0, -16), 6.0, Color("#15151a"))
			"arrow", "arrow_up":
				var h0: float = float(s.get("h0", 10.0))
				var p0: Vector2 = a + Vector2(0, -h0 if s["kind"] == "arrow" else -20.0)
				var p1: Vector2 = b + Vector2(0, -16 if s["kind"] == "arrow" else -24.0)
				var p: Vector2 = p0.lerp(p1, k) + Vector2(0, -sin(k * PI) * 20.0)
				var d: Vector2 = (p1 - p0).normalized()
				_fx.draw_line(p - d * 12.0, p, Color("#f0e0c0"), 2.5, true)
			"shell":
				var g: Vector2 = a.lerp(b, k)
				_fx.draw_set_transform(g, 0.0, Vector2(1.0, 0.5))
				_fx.draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.3))
				_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				_fx.draw_circle(g + Vector2(0, -sin(k * PI) * 160.0 - 16.0), 9.0, Color("#2a2a30"))
				_fx.draw_circle(g + Vector2(-3, -sin(k * PI) * 160.0 - 19.0), 3.0, Color(1, 0.7, 0.3, 0.9))
	## Barras de vida (solo de lo que esta recibiendo dano).
	for i: int in buildings.size():
		var b: Dictionary = buildings[i]
		if not b["alive"] or float(b["hit_t"]) > 2.5 or b["wall"]:
			continue
		var c: Vector2 = iso(center_of(i)) + Vector2(0, -float(b["h"]) - 30.0)
		_bar(c, 56.0, float(b["hp"]) / float(b["max_hp"]), Color("#ff5a4f") if b["def"] else Color("#ffcf3f"))
	for tr: Dictionary in troops:
		if tr["alive"] and float(tr["hit_t"]) < 2.0:
			_bar(iso(tr["pos"]) + Vector2(0, -60), 30.0, float(tr["hp"]) / float(tr["max_hp"]), Color("#5fd35f"))


func _bar(c: Vector2, w: float, f: float, col: Color) -> void:
	var r: Rect2 = Rect2(c - Vector2(w * 0.5, 0), Vector2(w, 7))
	_fx.draw_rect(r.grow(2.0), Color(0.05, 0.05, 0.08, 0.85))
	_fx.draw_rect(Rect2(r.position, Vector2(w * clampf(f, 0.0, 1.0), 7)), col)

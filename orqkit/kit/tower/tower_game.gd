extends Node2D
## Genero torres (tower defense). Los enemigos del juego recorren el camino hasta tu base (el
## heroe); tu pones torres en las casillas libres para pararlos.
## 1 - Toca una casilla libre y elige torre: Rayo (rapida, un objetivo), Canon (lenta, dano en
##     area) o Hielo (frena). Toca una torre para mejorarla (hasta nivel 3) o venderla.
## 2 - Oleadas cada vez mas grandes y duras (walker normal, flyer rapido, spiky acorazado);
##     en el ultimo nivel puede venir el jefe en la ultima oleada.
## 3 - Cada baja da oro; pasar una oleada da un extra. Lanzar la oleada antes de tiempo da oro.
## 4 - Cada enemigo que llega a la base quita vidas. Sin vidas: ventana para reintentar.
## El nivel (game.json -> levels[i]) trae: map, waves, density, enemies, boss, gold y lives.

const REVIVE_N: int = 3
const TOWERS: Dictionary = {
	"rayo": {"cost": 50, "range": 2.3, "rate": 0.55, "dmg": 2.0},
	"canon": {"cost": 85, "range": 2.0, "rate": 1.3, "dmg": 3.4},
	"hielo": {"cost": 65, "range": 1.9, "rate": 0.9, "dmg": 0.7},
}
const ENEMIES: Dictionary = {
	"walker": {"hp": 6.0, "speed": 1.0, "gold": 4, "lives": 1, "size": 0.62},
	"flyer": {"hp": 3.6, "speed": 1.7, "gold": 4, "lives": 1, "size": 0.55},
	"spiky": {"hp": 16.0, "speed": 0.62, "gold": 9, "lives": 2, "size": 0.7},
	"boss": {"hp": 110.0, "speed": 0.45, "gold": 60, "lives": 6, "size": 1.25},
}
const WAVE_GAP: float = 9.0
## A quien apunta cada torre (se cambia tocandola): el mas adelantado, el de mas vida o el mas cerca.
const AIMS: Array[String] = ["first", "strong", "close"]
const AIM_TXT: Dictionary = {"first": "Primero", "strong": "Fuerte", "close": "Cerca"}
const ENEMY_TXT: Dictionary = {"walker": "normal", "flyer": "r\u00e1pido", "spiky": "acorazado", "boss": "jefe"}

var rows: Array[String] = []
var path: Array[Vector2i] = []
var path_px: PackedVector2Array = PackedVector2Array()
var path_len: float = 0.0
var cell: float = 75.0
var origin: Vector2 = Vector2.ZERO
var level: Dictionary = {}
var waves_total: int = 5
var wave: int = 0
var in_wave: bool = false
var gold: int = 150
var lives: int = 10
var lives_max: int = 10
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var kills: int = 0
var time_in_level: float = 0.0
var countdown: float = WAVE_GAP
var towers: Dictionary = {}
var enemies: Array[Dictionary] = []
var auto_retry: bool = false
var fast: bool = false
var selected: Vector2i = Vector2i(-1, -1)
var result_panel: ResultPanel

var _spawn_queue: Array[String] = []
var _spawn_left: float = 0.0
var _spawn_gap: float = 0.8
var _hp_mult: float = 1.0
var _shells: Array[Dictionary] = []
var _board: Node2D
var _fx: Node2D
var _hud: CanvasLayer
var _lives_label: Label
var _gold_label: Label
var _wave_label: Label
var _bar: HBoxContainer
var _next_btn: Button
var _attempt: int = 0


func _ready() -> void:
	level = Kit.current_level()
	rows = TowerMap.rows_of(level.get("map", ["S=B"]))
	path = TowerMap.path_cells(rows)
	waves_total = int(level.get("waves", 5))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")).darkened(0.3))
	_board = Node2D.new()
	_board.name = "Board"
	add_child(_board)
	_fx = Node2D.new()
	_fx.name = "Fx"
	_fx.z_index = 5
	add_child(_fx)
	_build_hud()
	_reset()
	get_viewport().size_changed.connect(_layout)
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "tower", "waves": waves_total})


## Bandera para los bots: este juego se juega con TowerBot.
func tower_bot_step() -> void:
	pass


func _reset() -> void:
	gold = int(level.get("gold", 150))
	lives_max = int(level.get("lives", 10))
	lives = lives_max
	wave = 0
	in_wave = false
	failed = false
	countdown = WAVE_GAP
	towers.clear()
	for e: Dictionary in enemies:
		(e["node"] as Node2D).queue_free()
	enemies.clear()
	_spawn_queue.clear()
	selected = Vector2i(-1, -1)
	_layout()
	_update_hud()


func _layout() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var w: int = rows[0].length()
	var h: int = rows.size()
	cell = floorf(minf((vs.x - 24.0) / float(w), (vs.y - 400.0) / float(h)))
	origin = Vector2((vs.x - cell * w) * 0.5, 170.0 + (vs.y - 400.0 - cell * h) * 0.5)
	path_px = PackedVector2Array()
	for c: Vector2i in path:
		path_px.append(cell_pos(c))
	path_len = 0.0
	for i: int in range(1, path_px.size()):
		path_len += path_px[i].distance_to(path_px[i - 1])
	_draw_board()


func cell_pos(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell


func cell_at(p: Vector2) -> Vector2i:
	var c: Vector2 = (p - origin) / cell
	return Vector2i(int(floor(c.x)), int(floor(c.y)))


func buildable(c: Vector2i) -> bool:
	return c.y >= 0 and c.y < rows.size() and c.x >= 0 and c.x < rows[0].length() and rows[c.y][c.x] == "." and not towers.has(c)


# ------------------------------------------------------------------ dibujo

func _draw_board() -> void:
	for n: Node in _board.get_children():
		n.queue_free()
	var tex: Texture2D = Kit.first_tile_texture()
	var grass: Color = Kit.color("sky", Color("#1b2a41")).lightened(0.12)
	for y: int in rows.size():
		for x: int in rows[0].length():
			var ch: String = rows[y][x]
			var o: Vector2 = origin + Vector2(x, y) * cell
			var sq: Polygon2D = Polygon2D.new()
			sq.polygon = PackedVector2Array([o, o + Vector2(cell, 0), o + Vector2(cell, cell), o + Vector2(0, cell)])
			if TowerMap.is_path(ch):
				if tex != null:
					sq.texture = tex
					var k: float = float(tex.get_width()) / cell
					sq.uv = PackedVector2Array([Vector2.ZERO, Vector2(cell, 0) * k, Vector2(cell, cell) * k, Vector2(0, cell) * k])
					sq.color = Color(0.85, 0.85, 0.85)
				else:
					sq.color = Kit.color("solid", Color("#e8f0fa")).darkened(0.3)
			elif ch == "#":
				sq.color = grass.darkened(0.35)
			else:
				sq.color = grass if (x + y) % 2 == 0 else grass.lightened(0.05)
			_board.add_child(sq)
	## La base es el heroe del juego; la entrada, una puerta oscura.
	var b: Vector2i = TowerMap.find(rows, "B")
	var hero: Dictionary = Kit.sprite_by_role("jugador")
	if b.x >= 0:
		if not hero.is_empty():
			var spr: AnimatedSprite2D = SpriteKit.animado(hero, cell * 0.95, "idle", false)
			spr.position = cell_pos(b)
			Skins.apply(spr)
			_board.add_child(spr)
		else:
			var star: Polygon2D = Polygon2D.new()
			star.color = Kit.color("accent", Color.ORANGE)
			star.polygon = LevelBuilder._circle(cell * 0.38, 6)
			star.position = cell_pos(b)
			_board.add_child(star)
	var s: Vector2i = TowerMap.find(rows, "S")
	if s.x >= 0:
		var door: Polygon2D = Polygon2D.new()
		door.color = Color(0, 0, 0, 0.55)
		door.polygon = LevelBuilder._circle(cell * 0.4, 16)
		door.position = cell_pos(s)
		_board.add_child(door)
	for c: Variant in towers.keys():
		_draw_tower(c)
	if selected.x >= 0:
		var ring: Line2D = Line2D.new()
		ring.width = 3.0
		ring.default_color = Color(1, 1, 1, 0.7)
		var r: float = cell
		if towers.has(selected):
			r = tower_range(selected)
		var pts: PackedVector2Array = LevelBuilder._circle(r if towers.has(selected) else cell * 0.5, 36)
		pts.append(pts[0])
		ring.points = pts
		ring.position = cell_pos(selected)
		_board.add_child(ring)


func _draw_tower(c: Vector2i) -> void:
	var t: Dictionary = towers[c]
	var n: Node2D = Node2D.new()
	n.position = cell_pos(c)
	var base: Polygon2D = Polygon2D.new()
	base.color = Color(0.12, 0.12, 0.16)
	base.polygon = LevelBuilder._circle(cell * 0.4, 8)
	n.add_child(base)
	var top: Polygon2D = Polygon2D.new()
	match str(t["kind"]):
		"rayo":
			top.color = Kit.color("accent", Color.ORANGE)
			top.polygon = PackedVector2Array([Vector2(0, -cell * 0.32), Vector2(cell * 0.24, cell * 0.2), Vector2(-cell * 0.24, cell * 0.2)])
		"canon":
			top.color = Color(0.85, 0.35, 0.3)
			top.polygon = LevelBuilder._circle(cell * 0.27, 12)
		_:
			top.color = Color(0.55, 0.85, 1.0)
			top.polygon = PackedVector2Array([Vector2(0, -cell * 0.32), Vector2(cell * 0.28, 0), Vector2(0, cell * 0.32), Vector2(-cell * 0.28, 0)])
	n.add_child(top)
	for k: int in int(t["level"]) - 1:
		var pip: Polygon2D = Polygon2D.new()
		pip.color = Color(1, 0.9, 0.4)
		pip.polygon = LevelBuilder._circle(cell * 0.07, 8)
		pip.position = Vector2((float(k) - 0.5) * cell * 0.2, cell * 0.33)
		n.add_child(pip)
	_board.add_child(n)


# ------------------------------------------------------------------ HUD

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "Hud"
	_hud.layer = 20
	add_child(_hud)
	var root: Control = Control.new()
	root.theme = UI.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(root)
	var safe: MarginContainer = UI.safe_root(root, 20.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	top.add_child(UiIcon.make("heart", UI.colors["peligro"], 40.0))
	_lives_label = Label.new()
	_lives_label.name = "Lives"
	top.add_child(_lives_label)
	top.add_child(UiIcon.make("coin", Kit.color("coin", UI.colors["acento"]), 40.0))
	_gold_label = Label.new()
	_gold_label.name = "Gold"
	top.add_child(_gold_label)
	_wave_label = Label.new()
	_wave_label.name = "Wave"
	_wave_label.theme_type_variation = "SubtleLabel"
	_wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_wave_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	_bar = HBoxContainer.new()
	_bar.name = "Actions"
	_bar.add_theme_constant_override("separation", 10)
	col.add_child(_bar)


func _update_hud() -> void:
	if _lives_label == null:
		return
	_lives_label.text = str(lives)
	_gold_label.text = str(gold)
	_wave_label.text = Kit.text("wave", "Oleada") + " %d/%d" % [mini(wave + (1 if in_wave else 0), waves_total), waves_total]
	_refresh_actions()


## Barra de abajo: segun lo elegido, construir, mejorar/vender o lanzar la oleada.
func _refresh_actions() -> void:
	for c: Node in _bar.get_children():
		c.queue_free()
	if selected.x >= 0 and towers.has(selected):
		var t: Dictionary = towers[selected]
		var up_cost: int = upgrade_cost(selected)
		var up: Button = UI.make_button(Kit.text("upgrade", "Mejorar") + " %d" % up_cost if up_cost > 0 else Kit.text("max", "Al maximo"), true, "")
		up.name = "BtnUpgrade"
		up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		up.disabled = up_cost <= 0 or gold < up_cost
		up.pressed.connect(func() -> void: upgrade(selected))
		_bar.add_child(up)
		var sell: Button = UI.make_button(Kit.text("sell", "Vender") + " %d" % sell_value(selected), false, "")
		sell.name = "BtnSell"
		sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sell.pressed.connect(func() -> void: sell_tower(selected))
		_bar.add_child(sell)
		var aim: Button = UI.make_button("\u25ce " + Kit.text("tw_aim_" + str(t.get("aim", "first")), str(AIM_TXT[str(t.get("aim", "first"))])), false, "")
		aim.name = "BtnAim"
		aim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		aim.pressed.connect(func() -> void: cycle_aim(selected))
		_bar.add_child(aim)
		## Tres botones en una fila: que se repartan el ancho (sin minimo propio) y el texto quepa.
		for b2: Button in [up, sell, aim]:
			b2.custom_minimum_size = Vector2(0.0, b2.custom_minimum_size.y)
			b2.clip_text = true
			b2.add_theme_font_size_override("font_size", 24)
		return
	if selected.x >= 0:
		for kind: String in TOWERS.keys():
			var cost: int = int(TOWERS[kind]["cost"])
			var b: Button = UI.make_button(Kit.text("tower_" + kind, kind.capitalize()) + "\n%d" % cost, kind == "rayo", "")
			b.name = "Build_" + kind
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0.0, 110.0)
			b.disabled = gold < cost
			b.pressed.connect(func() -> void: build(selected, kind))
			_bar.add_child(b)
		return
	var label: String = Kit.text("next_wave", "Lanzar oleada") if not in_wave else Kit.text("wave_running", "Oleada en marcha")
	## Lo que trae la siguiente oleada.
	if not in_wave and wave < waves_total:
		label += "\n" + wave_preview(wave)
	_next_btn = UI.make_button(label, not in_wave, "play")
	_next_btn.name = "BtnNextWave"
	_next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_btn.disabled = in_wave or finished
	_next_btn.pressed.connect(start_wave)
	_bar.add_child(_next_btn)


# ------------------------------------------------------------------ torres

## "6 normal  2 rapido  1 jefe" de la oleada k.
func wave_preview(k: int) -> String:
	var count: Dictionary = {}
	var order: Array[String] = []
	for kind: String in wave_plan(k):
		if not count.has(kind):
			order.append(kind)
		count[kind] = int(count.get(kind, 0)) + 1
	var parts: Array[String] = []
	for kind: String in order:
		parts.append("%d %s" % [int(count[kind]), Kit.text("tw_e_" + kind, str(ENEMY_TXT.get(kind, kind)))])
	return "  ".join(parts)


func cycle_aim(c: Vector2i) -> void:
	if not towers.has(c):
		return
	var t: Dictionary = towers[c]
	t["aim"] = AIMS[(AIMS.find(str(t.get("aim", "first"))) + 1) % AIMS.size()]
	Audio.play("click", 0.05, -10.0)
	_refresh_actions()


## Enemigo al que dispara una torre segun su punteria (dentro del alcance).
func pick_target(t: Dictionary, from: Vector2, r: float) -> Dictionary:
	var aim: String = str(t.get("aim", "first"))
	var best: Dictionary = {}
	var best_v: float = -INF
	for e: Dictionary in enemies:
		var dist: float = (e["node"] as Node2D).position.distance_to(from)
		if dist > r:
			continue
		var v: float = float(e["d"])
		if aim == "strong":
			v = float(e["hp"]) * 1000.0 + float(e["d"])
		elif aim == "close":
			v = -dist
		if v > best_v:
			best_v = v
			best = e
	return best


func tower_range(c: Vector2i) -> float:
	var t: Dictionary = towers[c]
	return (float(TOWERS[t["kind"]]["range"]) + 0.25 * float(int(t["level"]) - 1)) * cell


func upgrade_cost(c: Vector2i) -> int:
	var t: Dictionary = towers[c]
	var lvl: int = int(t["level"])
	if lvl >= 3:
		return 0
	return int(float(TOWERS[t["kind"]]["cost"]) * (0.75 if lvl == 1 else 1.1))


func sell_value(c: Vector2i) -> int:
	return int(float(towers[c]["spent"]) * 0.6)


func build(c: Vector2i, kind: String) -> bool:
	var cost: int = int(TOWERS[kind]["cost"])
	if not buildable(c) or gold < cost or finished:
		return false
	gold -= cost
	towers[c] = {"kind": kind, "level": 1, "cd": 0.0, "spent": cost, "aim": "first"}
	Audio.play("powerup", 0.05, -4.0)
	QA.log_event("tower_build", {"kind": kind, "cell": c})
	selected = Vector2i(-1, -1)
	_draw_board()
	_update_hud()
	return true


func upgrade(c: Vector2i) -> bool:
	if not towers.has(c):
		return false
	var cost: int = upgrade_cost(c)
	if cost <= 0 or gold < cost:
		return false
	gold -= cost
	towers[c]["level"] = int(towers[c]["level"]) + 1
	towers[c]["spent"] = int(towers[c]["spent"]) + cost
	Audio.play("powerup")
	_draw_board()
	_update_hud()
	return true


func sell_tower(c: Vector2i) -> void:
	if not towers.has(c):
		return
	gold += sell_value(c)
	towers.erase(c)
	selected = Vector2i(-1, -1)
	Audio.play("coin")
	_draw_board()
	_update_hud()


# ------------------------------------------------------------------ oleadas

## Composicion de la oleada k (0..waves-1): mas enemigos, mas vida y nuevos tipos poco a poco.
func wave_plan(k: int) -> Array[String]:
	var dens: float = float(level.get("density", 0.5))
	var types: Array = level.get("enemies", ["walker"])
	var count: int = int(round((6.5 + 2.2 * float(k)) * (0.8 + 0.5 * dens)))
	var out: Array[String] = []
	for i: int in count:
		var kind: String = "walker"
		if types.has("flyer") and k >= 1 and i % 4 == 1:
			kind = "flyer"
		if types.has("spiky") and k >= 2 and i % 5 == 3:
			kind = "spiky"
		out.append(kind)
	if bool(level.get("boss", false)) and k == waves_total - 1:
		out.append("boss")
	return out


func start_wave() -> void:
	if in_wave or finished or failed or wave >= waves_total:
		return
	## Lanzarla antes de tiempo da oro (2 por segundo ahorrado).
	if countdown > 0.0:
		gold += int(countdown * 2.0)
	var dens: float = float(level.get("density", 0.5))
	_hp_mult = (1.0 + 0.47 * float(wave)) * (0.8 + 0.75 * dens)
	_spawn_queue = wave_plan(wave)
	_spawn_gap = maxf(0.9 - 0.04 * float(wave), 0.45)
	_spawn_left = 0.0
	in_wave = true
	QA.log_event("wave_start", {"wave": wave + 1, "count": _spawn_queue.size()})
	_update_hud()


func _physics_process(delta: float) -> void:
	if finished or failed or get_tree().paused:
		return
	time_in_level += delta
	if not in_wave:
		countdown -= delta
		if countdown <= 0.0:
			start_wave()
	else:
		_spawn_left -= delta
		if not _spawn_queue.is_empty() and _spawn_left <= 0.0:
			_spawn(_spawn_queue.pop_front())
			_spawn_left = _spawn_gap
	_move_enemies(delta)
	_fire_towers(delta)
	_move_shells(delta)
	if in_wave and _spawn_queue.is_empty() and enemies.is_empty():
		in_wave = false
		wave += 1
		gold += 15 + 4 * wave
		countdown = WAVE_GAP
		QA.log_event("wave_clear", {"wave": wave, "lives": lives})
		if wave >= waves_total:
			_win()
			return
		_update_hud()


func _spawn(kind: String) -> void:
	var st: Dictionary = ENEMIES[kind]
	var n: Node2D = Node2D.new()
	var art_id: String = str(Kit.param("art.enemies." + kind, ""))
	var entry: Dictionary = Kit.sprite_entry(art_id) if art_id != "" else {}
	if entry.is_empty() and kind != "boss":
		entry = Kit.sprite_by_role("enemigo")
	if not entry.is_empty():
		n.add_child(SpriteKit.animado(entry, cell * float(st["size"]), "run", false))
	else:
		var body: Polygon2D = Polygon2D.new()
		body.color = Kit.color("enemy", Color("#d9774a")) if kind != "boss" else Kit.color("danger", Color("#ff6b5b"))
		body.polygon = LevelBuilder._circle(cell * float(st["size"]) * 0.45, 14)
		n.add_child(body)
	var bar: ColorRect = ColorRect.new()
	bar.name = "Hp"
	bar.color = Color(0.4, 1.0, 0.5)
	bar.size = Vector2(cell * 0.6, 5.0)
	bar.position = Vector2(-cell * 0.3, -cell * float(st["size"]) * 0.6)
	n.add_child(bar)
	n.position = path_px[0]
	_fx.add_child(n)
	var hp: float = float(st["hp"]) * _hp_mult
	enemies.append({"node": n, "kind": kind, "hp": hp, "max": hp, "d": 0.0, "slow": 0.0})


func _pos_at(d: float) -> Vector2:
	var left: float = d
	for i: int in range(1, path_px.size()):
		var seg: float = path_px[i].distance_to(path_px[i - 1])
		if left <= seg:
			return path_px[i - 1].lerp(path_px[i], left / maxf(seg, 0.001))
		left -= seg
	return path_px[path_px.size() - 1]


func _move_enemies(delta: float) -> void:
	var base_speed: float = cell * 1.3
	for e: Dictionary in enemies.duplicate():
		var st: Dictionary = ENEMIES[e["kind"]]
		var slow: float = 0.5 if float(e["slow"]) > 0.0 else 1.0
		e["slow"] = maxf(float(e["slow"]) - delta, 0.0)
		var before: Vector2 = (e["node"] as Node2D).position
		e["d"] = float(e["d"]) + base_speed * float(st["speed"]) * slow * Mods.tune("enemy_speed") * delta
		var n: Node2D = e["node"]
		n.position = _pos_at(float(e["d"]))
		if absf(n.position.x - before.x) > 0.1 and n.get_child_count() > 0 and n.get_child(0) is Node2D:
			(n.get_child(0) as Node2D).scale.x = absf((n.get_child(0) as Node2D).scale.x) * signf(n.position.x - before.x)
		if float(e["d"]) >= path_len:
			_leak(e)


func _leak(e: Dictionary) -> void:
	enemies.erase(e)
	(e["node"] as Node2D).queue_free()
	lives -= int(ENEMIES[e["kind"]]["lives"])
	Audio.play("hurt")
	Juice.shake(0.25)
	QA.log_event("leak", {"kind": e["kind"], "lives": lives})
	_update_hud()
	if lives <= 0:
		_lose()


func _fire_towers(delta: float) -> void:
	for c: Variant in towers.keys():
		var t: Dictionary = towers[c]
		t["cd"] = float(t["cd"]) - delta
		if float(t["cd"]) > 0.0:
			continue
		var spec: Dictionary = TOWERS[t["kind"]]
		var r: float = tower_range(c)
		var from: Vector2 = cell_pos(c)
		## Apunta segun su punteria (por defecto, al mas adelantado).
		var target: Dictionary = pick_target(t, from, r)
		if target.is_empty():
			continue
		t["cd"] = float(spec["rate"]) / Mods.tune("fire_rate")
		var dmg: float = float(spec["dmg"]) * pow(1.5, float(int(t["level"]) - 1)) * Mods.tune("damage")
		var to: Vector2 = (target["node"] as Node2D).position
		match str(t["kind"]):
			"canon":
				_shells.append({"from": from, "to": to, "t": 0.0, "dmg": dmg, "node": _shell_node(from)})
			"hielo":
				_beam(from, to, Color(0.6, 0.9, 1.0))
				target["slow"] = 1.4
				_hit(target, dmg)
			_:
				_beam(from, to, Kit.color("accent", Color.ORANGE))
				_hit(target, dmg)


func _beam(a: Vector2, b: Vector2, col: Color) -> void:
	if fast:
		return
	var l: Line2D = Line2D.new()
	l.points = PackedVector2Array([a, b])
	l.width = 4.0
	l.default_color = col
	_fx.add_child(l)
	var tw: Tween = l.create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.12)
	tw.tween_callback(l.queue_free)


func _shell_node(at: Vector2) -> Node2D:
	var p: Polygon2D = Polygon2D.new()
	p.color = Color(0.2, 0.2, 0.22)
	p.polygon = LevelBuilder._circle(cell * 0.1, 8)
	p.position = at
	_fx.add_child(p)
	return p


func _move_shells(delta: float) -> void:
	for s: Dictionary in _shells.duplicate():
		s["t"] = float(s["t"]) + delta / 0.35
		var p: Vector2 = (s["from"] as Vector2).lerp(s["to"], minf(float(s["t"]), 1.0))
		(s["node"] as Node2D).position = p + Vector2(0.0, -sin(minf(float(s["t"]), 1.0) * PI) * cell * 0.5)
		if float(s["t"]) >= 1.0:
			_shells.erase(s)
			(s["node"] as Node2D).queue_free()
			if not fast:
				Juice.burst(_fx, p, Color(1.0, 0.6, 0.3), 8, 180.0)
			for e: Dictionary in enemies.duplicate():
				if (e["node"] as Node2D).position.distance_to(p) <= cell * 0.9:
					_hit(e, float(s["dmg"]))


func _hit(e: Dictionary, dmg: float) -> void:
	if not enemies.has(e):
		return
	## Los acorazados (spiky) aguantan 1 de cada golpe.
	if str(e["kind"]) == "spiky":
		dmg = maxf(dmg - 1.0, dmg * 0.4)
	e["hp"] = float(e["hp"]) - dmg
	var n: Node2D = e["node"]
	var bar: ColorRect = n.get_node("Hp")
	bar.size.x = cell * 0.6 * clampf(float(e["hp"]) / float(e["max"]), 0.0, 1.0)
	if float(e["hp"]) <= 0.0:
		enemies.erase(e)
		kills += 1
		gold += int(ENEMIES[e["kind"]]["gold"])
		if not fast:
			Juice.burst(_fx, n.position, Kit.color("enemy", Color("#d9774a")), 6, 160.0)
			Audio.play("stomp", 0.15, -8.0)
		n.queue_free()
		_update_hud()


# ------------------------------------------------------------------ entrada

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if finished or failed:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var c: Vector2i = cell_at((event as InputEventMouseButton).position)
		tap(c)


func tap(c: Vector2i) -> void:
	if towers.has(c) or buildable(c):
		selected = c if selected != c else Vector2i(-1, -1)
	else:
		selected = Vector2i(-1, -1)
	_draw_board()
	_refresh_actions()


# ------------------------------------------------------------------ final

func _win() -> void:
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = kills * 10 + lives * 100 + gold
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "lives": lives, "kills": kills, "deaths": deaths, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	_update_hud()
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": lives, "coins_total": lives_max, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: una por ganar, otra con la mitad de las vidas y otra sin perder ninguna.
func stars_earned() -> int:
	var n: int = 1
	if lives * 2 >= lives_max:
		n += 1
	if lives >= lives_max:
		n += 1
	return n


func _lose() -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "base", "wave": wave + 1, "deaths": deaths})
	if auto_retry:
		retry()
		return
	Audio.play("hurt")
	var p: FailPanel = FailPanel.open(self, Kit.text("base_lost", "Han llegado a tu base"), Kit.text("reached_wave", "Llegaste a la oleada") + " %d/%d" % [wave + 1, waves_total])
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): la base recupera unas vidas y la oleada sigue.
func revive() -> void:
	lives = maxi(REVIVE_N, lives_max / 3)
	failed = false
	_update_hud()


func revive_text() -> String:
	return Kit.text("revive_lives", "+{n} vidas").format({"n": maxi(REVIVE_N, lives_max / 3)})


func retry() -> void:
	_attempt += 1
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {
		"pos": Vector2.ZERO, "deaths": deaths, "coins": gold, "finished": finished, "failed": failed, "stomps": kills,
		"lives": lives, "wave": wave, "towers": towers.size(), "progress": float(wave) / float(maxi(waves_total, 1)),
	}

extends Node2D
## Tirachinas (estilo Angry Birds): arrastra el pajaro hacia atras, apunta con los puntos y
## suelta. Tira estructuras de madera, piedra y hielo para acabar con todos los cerdos. Algunos
## pajaros tienen poder: toca la pantalla en el aire (amarillo acelera, azul se parte en tres,
## negro explota). Los derrumbes son fisica de verdad (cuerpos rigidos de Godot).
## Mapa, balistica y analizador en sling_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const REVIVE_N: int = 1
const M = preload("res://kit/sling/sling_map.gd")
const BIRD_R: float = 22.0
const BIRD_COL: Dictionary = {"red": "#e53935", "yellow": "#fdd835", "blue": "#42a5f5", "black": "#37474f"}
const MAT_COL: Dictionary = {"W": "#c58b4a", "S": "#9aa3ad", "I": "#a8e4f5", "=": "#c58b4a", "|": "#c58b4a", "T": "#e53935", "#": "#6b6258"}
const BOOM_R: float = 170.0

var level: Dictionary = {}
var info: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
var score: int = 0
var par: int = 0

var _world: Node2D
var _bodies: Node2D
var _camera: Camera2D
var _score_lbl: Label
var _birds_lbl: Label
var _queue: Array[String] = []
var _bird: RigidBody2D = null
var _flying: Array = []
var _state: String = "ready"
var _drag: bool = false
var _pull: Vector2 = Vector2.ZERO
var _wait: float = 0.0
var _bot: bool = false
var _bot_plan: Dictionary = {}
var _shots_at: Dictionary = {}
var _t: float = 0.0
var _fx: Array = []
var _hero_tex: Texture2D = null


class Piece:
	extends RigidBody2D
	var kind: String = "block"
	var mat: String = "W"
	var hp: float = 50.0
	var max_hp: float = 50.0
	var hit: float = 0.0
	var size: Vector2 = Vector2.ZERO
	var radius: float = 0.0
	var dead: bool = false
	var prev_v: Vector2 = Vector2.ZERO

	func _integrate_forces(s: PhysicsDirectBodyState2D) -> void:
		for i: int in s.get_contact_count():
			hit = maxf(hit, s.get_contact_impulse(i).length())


func _ready() -> void:
	level = Kit.current_level()
	par = int(level.get("par", 0))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#8fd3f4")))
	var hero: Dictionary = Kit.sprite_by_role("jugador")
	if not hero.is_empty():
		var sf: SpriteFrames = SpriteKit.frames_de(hero)
		for anim: String in sf.get_animation_names():
			if sf.get_frame_count(anim) > 0:
				_hero_tex = sf.get_frame_texture(anim, 0)
				break
	_world = Node2D.new()
	_world.name = "World"
	_world.z_index = -1
	_world.draw.connect(_draw_back)
	add_child(_world)
	_bodies = Node2D.new()
	_bodies.name = "Bodies"
	add_child(_bodies)
	var fxl: Node2D = Node2D.new()
	fxl.name = "Front"
	fxl.z_index = 5
	fxl.draw.connect(_draw_front.bind(fxl))
	add_child(fxl)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "sling", "pigs": (info["pigs"] as Array).size()})


func bot_script() -> String:
	return "res://qa/sling_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(5.0, 4.0)


func _reset() -> void:
	finished = false
	failed = false
	info = M.parse(level)
	for c: Node in _bodies.get_children():
		_bodies.remove_child(c)
		c.queue_free()
	_flying.clear()
	_fx.clear()
	_bird = null
	score = 0
	coins = 0
	coins_total = (info["pigs"] as Array).size()
	time_in_level = 0.0
	_queue.assign(info["birds"])
	_shots_at.clear()
	_build_ground()
	for p: Dictionary in info["pieces"]:
		_add_piece(p)
	for pg: Dictionary in info["pigs"]:
		_add_pig(pg)
	## Todo quieto hasta que algo lo toque (asi la torre no se mueve sola al empezar).
	for c: Node in _bodies.get_children():
		if c is Piece:
			(c as Piece).set_deferred("sleeping", true)
	## Camara: todo el nivel a la vista (del tirachinas a la ultima pieza).
	var right: float = M.STRUCT_X + float(info["width"]) + 80.0
	var w: float = right + 40.0
	var z: float = clampf(get_viewport_rect().size.x / w, 0.35, 1.0)
	_camera.zoom = Vector2(z, z)
	## El suelo al 82 % de la altura de la pantalla.
	_camera.position = Vector2(w * 0.5 - 20.0, -(get_viewport_rect().size.y * 0.27) / z)
	_state = "ready"
	_wait = 0.6
	_next_bird()
	_refresh()


func _build_ground() -> void:
	var g: StaticBody2D = StaticBody2D.new()
	g.name = "Ground"
	var sh: CollisionShape2D = CollisionShape2D.new()
	var r: RectangleShape2D = RectangleShape2D.new()
	r.size = Vector2(6000, 400)
	sh.shape = r
	sh.position = Vector2(1000, 200)
	g.add_child(sh)
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = 0.9
	g.physics_material_override = pm
	_bodies.add_child(g)


func _add_piece(p: Dictionary) -> void:
	var rect: Rect2 = p["rect"]
	var mat: String = str(p["mat"])
	if str(p["kind"]) == "rock":
		var s: StaticBody2D = StaticBody2D.new()
		s.position = rect.get_center()
		var cs: CollisionShape2D = CollisionShape2D.new()
		var rs: RectangleShape2D = RectangleShape2D.new()
		rs.size = rect.size
		cs.shape = rs
		s.add_child(cs)
		s.set_meta("rock", rect.size)
		_bodies.add_child(s)
		return
	var b: Piece = Piece.new()
	b.kind = "tnt" if mat == "T" else "block"
	b.mat = mat
	b.size = rect.size
	b.position = rect.get_center()
	var cells: float = rect.size.x * rect.size.y / (M.CELL * M.CELL)
	b.mass = maxf(0.2, float(M.MATS[mat]["mass"]) * cells)
	b.max_hp = float(M.MATS[mat]["hp"]) * maxf(1.0, sqrt(cells))
	b.hp = b.max_hp
	var cs2: CollisionShape2D = CollisionShape2D.new()
	var rs2: RectangleShape2D = RectangleShape2D.new()
	rs2.size = rect.size - Vector2(1, 1)
	cs2.shape = rs2
	b.add_child(cs2)
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = 0.25 if mat == "I" else 0.8
	pm.bounce = 0.05
	b.physics_material_override = pm
	b.contact_monitor = true
	b.max_contacts_reported = 6
	b.custom_integrator = false
	b.can_sleep = true
	b.draw.connect(_draw_piece.bind(b))
	_bodies.add_child(b)


func _add_pig(pg: Dictionary) -> void:
	var b: Piece = Piece.new()
	b.kind = str(pg["kind"])
	b.radius = float(pg["r"])
	b.position = pg["c"]
	b.mass = 0.7 if b.kind == "pig" else 1.4
	b.max_hp = 28.0 if b.kind == "pig" else 70.0
	b.hp = b.max_hp
	var cs: CollisionShape2D = CollisionShape2D.new()
	var c: CircleShape2D = CircleShape2D.new()
	c.radius = b.radius
	cs.shape = c
	b.add_child(cs)
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = 0.8
	pm.bounce = 0.1
	b.physics_material_override = pm
	b.contact_monitor = true
	b.max_contacts_reported = 6
	b.draw.connect(_draw_piece.bind(b))
	_bodies.add_child(b)


func _next_bird() -> void:
	if _queue.is_empty():
		_bird = null
		return
	var kind: String = _queue.pop_front()
	var b: Piece = Piece.new()
	b.kind = "bird"
	b.mat = kind
	b.radius = BIRD_R
	b.position = M.SLING
	b.mass = 1.6 if kind != "black" else 2.0
	b.freeze = true
	b.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	## Sin el frenado por aire del proyecto: vuela justo por la parabola que se ve al apuntar.
	b.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	b.linear_damp = 0.0
	var cs: CollisionShape2D = CollisionShape2D.new()
	var c: CircleShape2D = CircleShape2D.new()
	c.radius = BIRD_R
	cs.shape = c
	b.add_child(cs)
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.25
	b.physics_material_override = pm
	b.contact_monitor = true
	b.max_contacts_reported = 4
	b.set_meta("used", false)
	b.draw.connect(_draw_piece.bind(b))
	_bodies.add_child(b)
	_bird = b
	_state = "ready"


# ------------------------------------------------------------------ interfaz

func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Hud"
	layer.layer = 20
	add_child(layer)
	var root: Control = Control.new()
	root.theme = UI.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var safe: MarginContainer = UI.safe_root(root, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_theme_constant_override("separation", 12)
	safe.add_child(top)
	_score_lbl = _label(34)
	_score_lbl.name = "Score"
	_score_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_score_lbl)
	_birds_lbl = _label(30)
	_birds_lbl.name = "Birds"
	top.add_child(_birds_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)


func _label(sz: int) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _refresh() -> void:
	if _score_lbl == null:
		return
	_score_lbl.text = Kit.text("sg_score", "Puntos {n}").format({"n": score})
	_birds_lbl.text = Kit.text("sg_birds", "Pajaros {n}").format({"n": _queue.size() + (1 if _bird != null and _state == "ready" else 0)})


# ------------------------------------------------------------------ jugar

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func pigs_alive() -> Array:
	var out: Array = []
	for c: Node in _bodies.get_children():
		if c is Piece and ((c as Piece).kind == "pig" or (c as Piece).kind == "king") and not (c as Piece).dead:
			out.append(c)
	return out


## Lanza el pajaro del tirachinas con un tiron (px desde el tirachinas hacia atras).
func shoot(pull: Vector2) -> bool:
	if not can_act() or _state != "ready" or _bird == null or pull.length() < 15.0:
		return false
	var v: Vector2 = M.launch_velocity(pull)
	_bird.freeze = false
	## Sale desde el centro del tirachinas (asi el tiro va justo por los puntos que se ven).
	_bird.position = M.SLING
	_bird.linear_velocity = v
	_flying.append(_bird)
	_bird.set_meta("t", 0.0)
	_state = "flying"
	_wait = 0.0
	_sfx("jump", -6.0, 0.9)
	Juice.vibrate(14)
	_refresh()
	return true


## Poder del pajaro en vuelo (toca la pantalla).
func ability() -> void:
	if _flying.is_empty():
		return
	var b: Piece = _flying[0]
	if not is_instance_valid(b) or bool(b.get_meta("used", false)):
		return
	b.set_meta("used", true)
	match b.mat:
		"yellow":
			b.linear_velocity = b.linear_velocity.normalized() * maxf(b.linear_velocity.length() * 1.9, 900.0)
			_sfx("powerup", -6.0, 1.3)
		"blue":
			for da: float in [-0.2, 0.2]:
				var c: Piece = Piece.new()
				c.kind = "bird"
				c.mat = "blue"
				c.radius = BIRD_R * 0.75
				c.mass = 0.9
				c.position = b.position + Vector2(0, da * 60.0)
				c.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
				c.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
				c.linear_damp = 0.0
				var cs: CollisionShape2D = CollisionShape2D.new()
				var sh: CircleShape2D = CircleShape2D.new()
				sh.radius = c.radius
				cs.shape = sh
				c.add_child(cs)
				c.contact_monitor = true
				c.max_contacts_reported = 4
				c.set_meta("used", true)
				c.set_meta("t", float(b.get_meta("t", 0.0)))
				c.draw.connect(_draw_piece.bind(c))
				_bodies.add_child(c)
				c.linear_velocity = b.linear_velocity.rotated(da)
				_flying.append(c)
			_sfx("click", -4.0, 1.4)
		"black":
			_explode(b.position, BOOM_R, 140.0)
			b.dead = true
			b.queue_free()
			_flying.erase(b)


func _explode(at: Vector2, radius: float, dmg: float) -> void:
	_sfx("hurt", -2.0, 0.6)
	Juice.shake(0.3)
	_fx.append({"kind": "boom", "p": at, "r": radius, "t": 0.0})
	for c: Node in _bodies.get_children():
		if c is Piece and not (c as Piece).dead and (c as Piece).kind != "bird":
			var p: Piece = c
			var d: Vector2 = p.position - at
			var k: float = 1.0 - d.length() / radius
			if k > 0.0:
				p.apply_central_impulse(d.normalized() * 900.0 * k * p.mass)
				p.hp -= dmg * k
				if p.hp <= 0.0:
					_destroy(p)


func _destroy(p: Piece) -> void:
	if p.dead:
		return
	p.dead = true
	var pts: int = 5000 if p.kind == "pig" else (10000 if p.kind == "king" else 500)
	score += pts
	if p.kind == "pig" or p.kind == "king":
		coins += 1
		_sfx("coin", -4.0, 1.0 + 0.1 * float(coins % 4))
	else:
		_sfx("stomp", -10.0, 0.8 + randf() * 0.4)
	_fx.append({"kind": "pop", "p": p.position, "pts": pts, "t": 0.0, "col": Color(str(MAT_COL.get(p.mat, "#7cc45a"))) if p.kind == "block" or p.kind == "tnt" else Color("#7cc45a")})
	if p.kind == "tnt":
		_explode.call_deferred(p.position, BOOM_R, 160.0)
	p.queue_free()
	_refresh()


func _physics_process(delta: float) -> void:
	_t += delta
	for f: Dictionary in _fx:
		f["t"] = float(f["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 0.8)
	(get_node("Front") as Node2D).queue_redraw()
	if finished:
		return
	time_in_level += delta
	## Dano por golpes: lo que pasa del peso que aguanta quieto (asi una torre en pie no se rompe sola).
	for c: Node in _bodies.get_children():
		if not (c is Piece):
			continue
		var p: Piece = c
		p.queue_redraw()
		if p.dead:
			continue
		if p.kind == "bird":
			if p.mat == "black" and p.hit > 400.0 and not bool(p.get_meta("used", false)):
				p.set_meta("used", true)
				_explode.call_deferred(p.position, BOOM_R, 140.0)
				p.dead = true
				p.queue_free()
				_flying.erase(p)
			p.hit = 0.0
			continue
		var limit: float = 70.0 * p.mass
		## Golpe = cambio brusco de velocidad (lo nota igual quien recibe y quien choca, aunque
		## estuviera dormido) o empujon fuerte de un contacto. Lo que aguanta: el peso y caer poco.
		var dv: float = (p.linear_velocity - p.prev_v).length()
		p.prev_v = p.linear_velocity
		## Al principio todo se asienta: los primeros segundos no hay dano.
		if time_in_level < 1.5:
			p.hit = 0.0
			dv = 0.0
		var dmg: float = maxf((p.hit - limit) / p.mass * 0.16, (dv - 140.0) * 0.18)
		if dmg > 0.0:
			p.hp -= dmg
			if p.hp <= 0.0:
				_destroy(p)
		p.hit = 0.0
		if p.position.y > 600.0:
			_destroy(p)
	## Pajaros en vuelo: cuando se paran (o tras 7 s) se van y llega el siguiente.
	for b: Variant in _flying.duplicate():
		if not is_instance_valid(b):
			_flying.erase(b)
			continue
		var bb: Piece = b
		bb.set_meta("t", float(bb.get_meta("t", 0.0)) + delta)
		if (bb.linear_velocity.length() < 25.0 and float(bb.get_meta("t")) > 1.0) or float(bb.get_meta("t")) > 7.0 or bb.position.x > 2600.0:
			_flying.erase(bb)
			_fx.append({"kind": "pop", "p": bb.position, "pts": 0, "t": 0.0, "col": Color.WHITE})
			bb.queue_free()
	if _state == "flying" and _flying.is_empty():
		_state = "settle"
		_wait = 1.2
	if _state == "settle":
		_wait -= delta
		if _wait <= 0.0 and _calm():
			if pigs_alive().is_empty():
				_finish()
				return
			_next_bird()
			if _bird == null:
				_lose()
				return
			_refresh()
	elif _state == "ready" and pigs_alive().is_empty():
		_state = "settle"
		_wait = 0.8
	if fast and auto_retry:
		_bot = true
	if _bot:
		_bot_think(delta)


## Todo quieto (o casi): para que el siguiente tiro no llegue con la torre aun cayendo.
func _calm() -> bool:
	if _wait < -4.0:
		return true
	for c: Node in _bodies.get_children():
		if c is Piece and not (c as Piece).dead and (c as Piece).linear_velocity.length() > 30.0:
			return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	var pos: Vector2 = Vector2.ZERO
	var kind: int = 0
	if event is InputEventScreenTouch:
		kind = 1 if (event as InputEventScreenTouch).pressed else 2
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		kind = 1 if (event as InputEventMouseButton).pressed else 2
		pos = (event as InputEventMouseButton).position
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _drag:
		var w: Vector2 = get_canvas_transform().affine_inverse() * (event as InputEvent).get("position")
		_pull = (w - M.SLING).limit_length(M.MAX_PULL)
		return
	if kind == 0 or not can_act():
		return
	_bot = false
	var wp: Vector2 = get_canvas_transform().affine_inverse() * pos
	if kind == 1:
		if _state == "ready" and _bird != null and wp.distance_to(M.SLING) < 140.0:
			_drag = true
			_pull = (wp - M.SLING).limit_length(M.MAX_PULL)
		elif _state == "flying":
			ability()
	elif kind == 2 and _drag:
		_drag = false
		shoot(_pull)
		_pull = Vector2.ZERO


func _sfx(nm: String, vol: float = -10.0, pitch: float = 1.0) -> void:
	if not fast:
		Audio.play(nm, 0.05, vol, pitch)


# ------------------------------------------------------------------ bot

func bot_step() -> void:
	_bot = true


## Apunta al cerdo vivo mas cercano: busca un tiro (tenso o en parabola, con mas o menos fuerza)
## cuyo camino no choque con nada antes de llegar; si no hay ninguno libre, parabola alta (lo que
## pille por el camino tambien cae). Usa el poder del pajaro poco antes de llegar.
func _bot_think(_delta: float) -> void:
	if _state == "ready" and _bird != null:
		var pigs: Array = pigs_alive()
		if pigs.is_empty():
			return
		pigs.sort_custom(func(a: Piece, b: Piece) -> bool: return a.position.x < b.position.x)
		var target: Piece = pigs[0]
		var key: int = target.get_instance_id()
		var tries: int = int(_shots_at.get(key, 0))
		_shots_at[key] = tries + 1
		var best: Vector2 = Vector2.ZERO
		for k: float in [0.98, 0.9, 0.82, 0.74]:
			var speed: float = M.max_speed() * k
			var angles: Array[float] = M.aim_angles(M.SLING, target.position, speed)
			for ang: float in angles:
				if best == Vector2.ZERO and _clear_path(ang, speed, target):
					best = M.pull_for(ang, speed)
		if best == Vector2.ZERO:
			var hi: Array[float] = M.aim_angles(M.SLING, target.position, M.max_speed() * (0.98 - 0.05 * float(tries % 2)))
			best = M.pull_for(hi[hi.size() - 1] if not hi.is_empty() else deg_to_rad(45.0), M.max_speed() * 0.95)
		_bot_plan = {"x": target.position.x}
		shoot(best)
	elif _state == "flying" and not _flying.is_empty() and is_instance_valid(_flying[0]):
		var b: Piece = _flying[0]
		if b.mat != "red" and not bool(b.get_meta("used", false)) and b.position.x > float(_bot_plan.get("x", 9999.0)) - (220.0 if b.mat == "yellow" else (150.0 if b.mat == "blue" else 30.0)):
			ability()


## El tiro llega al cerdo sin tocar antes ninguna pieza (mira la caja de cada una).
func _clear_path(angle: float, speed: float, target: Piece) -> bool:
	var v: Vector2 = Vector2(cos(angle), -sin(angle)) * speed
	var boxes: Array[Rect2] = []
	for c: Node in _bodies.get_children():
		if c == target or c == _bird:
			continue
		if c is Piece and not (c as Piece).dead and (c as Piece).kind != "bird":
			var p: Piece = c
			var ext: Vector2 = Vector2(p.radius, p.radius) * 2.0 if p.radius > 0.0 else p.size.rotated(p.rotation).abs()
			boxes.append(Rect2(p.position - ext * 0.5, ext).grow(BIRD_R * 0.8))
		elif c is StaticBody2D and c.has_meta("rock"):
			var sz: Vector2 = c.get_meta("rock")
			boxes.append(Rect2((c as Node2D).position - sz * 0.5, sz).grow(BIRD_R * 0.8))
	var t: float = 0.0
	while t < 4.0:
		t += 0.015
		var q: Vector2 = M.at_time(M.SLING, v, t)
		if q.distance_to(target.position) < target.radius + BIRD_R:
			return true
		if q.y > 0.0 or q.x > target.position.x + 60.0:
			return false
		for r: Rect2 in boxes:
			if r.has_point(q):
				return false
	return false


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	score += 10000 * (_queue.size() + (1 if _bird != null and _state == "ready" else 0))
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "score": score})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas por puntos (par = puntos de 3 estrellas; sin par, por pajaros que sobran).
func stars_earned() -> int:
	if par > 0:
		return 3 if score >= par else (2 if score >= par * 0.7 else 1)
	return clampi(1 + _queue.size(), 1, 3)


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "no_birds", "pigs": pigs_alive().size(), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("sg_lost", "\u00a1Quedan cerdos!"),
		Kit.text("sg_fail_hint", "Apunta a la base de las torres y a lo que sujeta a los cerdos: se caen solas. El negro y la TNT rompen la piedra."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): un pajaro mas, como el primero.
func revive() -> void:
	var kinds: Array = info["birds"]
	_queue.append(str(kinds[0]) if not kinds.is_empty() else "red")
	finished = false
	failed = false
	_next_bird()
	_refresh()


func revive_text() -> String:
	return Kit.text("revive_tries", "+{n} intentos").format({"n": REVIVE_N})


func retry() -> void:
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
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "time": time_in_level,
		"pigs": pigs_alive().size(), "birds": _queue.size(), "score": score, "state": _state}


# ------------------------------------------------------------------ dibujo

func _draw_back() -> void:
	var cam: Vector2 = _camera.position
	var half: Vector2 = get_viewport_rect().size * 0.5 / _camera.zoom
	var sky: Color = Kit.color("sky", Color("#8fd3f4"))
	## Colinas lejanas y suelo.
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(Vector2(cam.x - half.x, 10))
	var x: float = cam.x - half.x
	while x <= cam.x + half.x + 60.0:
		pts.append(Vector2(x, -120.0 - sin(x * 0.006) * 70.0 - sin(x * 0.017) * 25.0))
		x += 40.0
	pts.append(Vector2(cam.x + half.x + 60.0, 10))
	_world.draw_colored_polygon(pts, sky.darkened(0.15).lerp(Color("#5c9c42"), 0.35))
	var ground: Color = Kit.color("ground", Color("#6fae4f"))
	if ground.get_luminance() < 0.2 or ground.s < 0.2:
		ground = Color("#6fae4f")
	_world.draw_rect(Rect2(Vector2(cam.x - half.x - 10.0, 0), Vector2(half.x * 2.0 + 20.0, half.y + 400.0)), Color("#8a5a2b"))
	_world.draw_rect(Rect2(Vector2(cam.x - half.x - 10.0, 0), Vector2(half.x * 2.0 + 20.0, 18)), ground)
	## Tirachinas: horquilla detras.
	var s: Vector2 = M.SLING
	_world.draw_line(Vector2(s.x, 0), s + Vector2(0, 40), Color("#6d4422"), 16.0)
	_world.draw_line(s + Vector2(0, 40), s + Vector2(-22, -10), Color("#6d4422"), 12.0)
	## Rocas fijas.
	for c: Node in _bodies.get_children():
		if c is StaticBody2D and c.has_meta("rock"):
			var sz: Vector2 = c.get_meta("rock")
			_world.draw_rect(Rect2((c as Node2D).position - sz * 0.5, sz), Color("#6b6258"))
			_world.draw_rect(Rect2((c as Node2D).position - sz * 0.5 + Vector2(4, 4), sz - Vector2(8, 14)), Color("#7d7468"))


func _draw_piece(p: Piece) -> void:
	if p.kind == "bird":
		var col: Color = Color(str(BIRD_COL.get(p.mat, "#e53935")))
		var r: float = p.radius
		p.draw_circle(Vector2.ZERO, r, col.darkened(0.25))
		p.draw_circle(Vector2(-2, -2), r - 3.0, col)
		p.draw_circle(Vector2(r * 0.35, -r * 0.25), r * 0.28, Color.WHITE)
		p.draw_circle(Vector2(r * 0.45, -r * 0.25), r * 0.13, Color.BLACK)
		p.draw_colored_polygon(PackedVector2Array([Vector2(r * 0.7, 0), Vector2(r * 1.25, r * 0.15), Vector2(r * 0.7, r * 0.35)]), Color("#ffb300"))
		p.draw_line(Vector2(r * 0.1, -r * 0.55), Vector2(r * 0.65, -r * 0.4), Color.BLACK, 3.0)
		if p.mat == "black":
			p.draw_line(Vector2(0, -r), Vector2(4, -r - 10), Color("#ffb300"), 3.0)
		return
	if p.kind == "pig" or p.kind == "king":
		var r2: float = p.radius
		var green: Color = Color("#7cc45a")
		p.draw_circle(Vector2.ZERO, r2, green.darkened(0.3))
		p.draw_circle(Vector2(-1, -2), r2 - 3.0, green)
		p.draw_circle(Vector2(0, r2 * 0.2), r2 * 0.32, green.lightened(0.25))
		p.draw_circle(Vector2(-r2 * 0.1, r2 * 0.2), r2 * 0.07, green.darkened(0.5))
		p.draw_circle(Vector2(r2 * 0.1, r2 * 0.2), r2 * 0.07, green.darkened(0.5))
		for ex: float in [-0.38, 0.38]:
			p.draw_circle(Vector2(r2 * ex, -r2 * 0.3), r2 * 0.18, Color.WHITE)
			p.draw_circle(Vector2(r2 * ex, -r2 * 0.3), r2 * 0.08, Color.BLACK)
		if p.kind == "king":
			p.draw_colored_polygon(PackedVector2Array([Vector2(-r2 * 0.6, -r2 * 0.8), Vector2(-r2 * 0.6, -r2 * 1.3), Vector2(-r2 * 0.3, -r2 * 1.05),
				Vector2(0, -r2 * 1.4), Vector2(r2 * 0.3, -r2 * 1.05), Vector2(r2 * 0.6, -r2 * 1.3), Vector2(r2 * 0.6, -r2 * 0.8)]), Color("#ffd23f"))
		if p.hp < p.max_hp * 0.6:
			p.draw_line(Vector2(-r2 * 0.5, -r2 * 0.6), Vector2(-r2 * 0.2, -r2 * 0.45), Color.BLACK, 3.0)
		return
	var col2: Color = Color(str(MAT_COL.get(p.mat, "#c58b4a")))
	var rect: Rect2 = Rect2(-p.size * 0.5, p.size)
	p.draw_rect(rect, col2.darkened(0.35))
	p.draw_rect(rect.grow(-3.0), col2)
	match p.mat:
		"W", "=", "|":
			for k: int in 3:
				var yy: float = rect.position.y + rect.size.y * (0.25 + 0.25 * float(k))
				if rect.size.y > 20.0:
					p.draw_line(Vector2(rect.position.x + 5.0, yy), Vector2(rect.end.x - 5.0, yy), col2.darkened(0.2), 2.0)
		"S":
			p.draw_rect(Rect2(rect.position + Vector2(6, 6), rect.size * 0.35), col2.lightened(0.15))
		"I":
			p.draw_line(rect.position + Vector2(6, 6), rect.position + Vector2(18, 18), Color(1, 1, 1, 0.8), 3.0)
		"T":
			var f: Font = UI.font if UI.font != null else ThemeDB.fallback_font
			p.draw_string(f, Vector2(-18, 8), "TNT", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ffd23f"))
	## Grietas segun el dano.
	var dmg: float = 1.0 - p.hp / p.max_hp
	if dmg > 0.3:
		p.draw_line(rect.position + Vector2(rect.size.x * 0.3, 2), rect.get_center(), Color(0, 0, 0, 0.6), 2.0)
	if dmg > 0.6:
		p.draw_line(rect.get_center(), rect.end - Vector2(rect.size.x * 0.2, 3), Color(0, 0, 0, 0.6), 2.0)


func _draw_front(ci: Node2D) -> void:
	var s: Vector2 = M.SLING
	## Goma del tirachinas y el pajaro cargado.
	if _bird != null and is_instance_valid(_bird) and _state == "ready":
		var at: Vector2 = s + (_pull if _drag else Vector2.ZERO)
		_bird.position = at
		ci.draw_line(s + Vector2(-22, -10), at, Color("#4e2a12"), 6.0)
		ci.draw_line(s + Vector2(16, -14), at, Color("#4e2a12"), 6.0)
		## Puntos de la trayectoria mientras se apunta.
		if _drag and _pull.length() > 15.0:
			var v: Vector2 = M.launch_velocity(_pull)
			for k: int in 14:
				var q: Vector2 = M.at_time(s, v, 0.06 * float(k + 1))
				ci.draw_circle(q, 6.0 - float(k) * 0.3, Color(1, 1, 1, 0.85 - 0.05 * float(k)))
	ci.draw_line(s + Vector2(0, 40), s + Vector2(18, -14), Color("#6d4422"), 12.0)
	for f: Dictionary in _fx:
		var k2: float = float(f["t"]) / 0.8
		if str(f["kind"]) == "boom":
			ci.draw_circle(f["p"], float(f["r"]) * (0.4 + 0.6 * k2), Color(1.0, 0.6, 0.15, 0.6 * (1.0 - k2)))
		else:
			for j: int in 6:
				var d: Vector2 = Vector2(cos(float(j) * 1.05), sin(float(j) * 1.05)) * 60.0 * k2
				ci.draw_rect(Rect2((f["p"] as Vector2) + d - Vector2(6, 6), Vector2(12, 12)), Color(f["col"], 1.0 - k2))
			if int(f["pts"]) > 0:
				var font: Font = UI.font if UI.font != null else ThemeDB.fallback_font
				ci.draw_string_outline(font, (f["p"] as Vector2) + Vector2(-30, -40 - 40.0 * k2), str(f["pts"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, Color(0, 0, 0, 1.0 - k2))
				ci.draw_string(font, (f["p"] as Vector2) + Vector2(-30, -40 - 40.0 * k2), str(f["pts"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 1, 1, 1.0 - k2))

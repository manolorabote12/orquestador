class_name Enemy
extends CharacterBody2D
## Enemigos de plataformas. Tipos (letra en el mapa):
## 1 - E walker: patrulla por el suelo y se gira en paredes, bordes y pinchos. Se le puede pisar.
## 2 - K spiky: patrulla igual pero lleva pinchos encima: pisarlo hace dano. Hay que esquivarlo.
## 3 - F flyer: vuela de lado a lado con vaiven, sin gravedad. Se le puede pisar.
## 3b - B boss (jefe final): grande, con vida. Persigue, se agacha avisando y salta hacia ti.
##      Pisarlo le quita 2 de vida y le deja aturdido un momento; un disparo le quita 1.
## Parametros en game.json -> "enemies" -> <tipo> (speed, width, height, points, range, bob).
## Los enemigos no empujan al jugador: el contacto lo resuelve el juego (pisoton o dano).

signal defeated(enemy: Enemy)

const KINDS: Dictionary = {"E": "walker", "K": "spiky", "F": "flyer", "B": "boss"}
const DEFAULTS: Dictionary = {
	"walker": {"speed": 90.0, "width": 48.0, "height": 40.0, "points": 100.0, "range": 0.0, "bob": 0.0},
	"spiky": {"speed": 60.0, "width": 50.0, "height": 44.0, "points": 0.0, "range": 0.0, "bob": 0.0},
	"flyer": {"speed": 110.0, "width": 50.0, "height": 36.0, "points": 150.0, "range": 2.5, "bob": 18.0},
	"boss": {"speed": 95.0, "width": 112.0, "height": 100.0, "points": 1000.0, "range": 0.0, "bob": 0.0, "hp": 6.0, "jump_every": 3.2},
}
const GRAVITY: float = 2600.0
const LAYER_ENEMY: int = 4

var kind: String = "walker"
var p: Dictionary = {}
var dir: float = -1.0
var alive: bool = true
var rows: Array[String] = []
var tile: float = 64.0
var home: Vector2 = Vector2.ZERO
var body: Node2D
var visual: Node2D
var anim_sprite: AnimatedSprite2D = null
var _t: float = 0.0
var hp: int = 1
var max_hp: int = 1
var stun_left: float = 0.0
var target: Node2D = null
var _jump_timer: float = 0.0
var _crouch_left: float = 0.0
var _was_on_floor: bool = true

signal damaged(hp_left: int)


## 4 - feet: para walker/spiky es el punto bajo los pies; para flyer, el centro del cuerpo.
func setup(enemy_kind: String, params: Dictionary, level_rows: Array[String], tile_size: float, col: Color, art: Dictionary = {}) -> void:
	kind = enemy_kind if DEFAULTS.has(enemy_kind) else "walker"
	p = (DEFAULTS[kind] as Dictionary).duplicate()
	for key: String in params.keys():
		if p.has(key):
			p[key] = float(params[key])
	rows = level_rows
	tile = tile_size
	home = position
	if kind == "boss":
		max_hp = int(p["hp"])
		hp = max_hp
		_jump_timer = float(p["jump_every"])
	_t = fmod(position.x * 0.013, TAU)
	collision_layer = LAYER_ENEMY
	collision_mask = 1
	floor_snap_length = 6.0
	var w: float = float(p["width"])
	var h: float = float(p["height"])
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	shape.position = Vector2(0.0, 0.0 if kind == "flyer" else -h * 0.5)
	add_child(shape)
	body = Node2D.new()
	body.name = "Body"
	add_child(body)
	visual = Node2D.new()
	visual.name = "Visual"
	body.add_child(visual)
	if art.is_empty():
		_build_shapes(col, w, h)
	else:
		anim_sprite = SpriteKit.animado(art, h * 1.4, "run", kind != "flyer")
		anim_sprite.name = "Sprite"
		visual.add_child(anim_sprite)
		if kind == "spiky":
			_add_spikes(col.lightened(0.5), w, h)
	_face()


func stompable() -> bool:
	return kind != "spiky" and stun_left <= 0.0


## 9 - Jefe: hace dano solo si no esta aturdido (tras un golpe da un respiro al jugador).
func harmful() -> bool:
	return stun_left <= 0.0


## 10 - Recibe un golpe. Devuelve true si muere. Los enemigos normales mueren de un golpe.
func damage(amount: int) -> bool:
	if not alive or stun_left > 0.0:
		return false
	if kind != "boss":
		die()
		return true
	hp -= amount
	damaged.emit(hp)
	if hp <= 0:
		die()
		return true
	stun_left = 1.1
	_crouch_left = 0.0
	velocity.x = 0.0
	Juice.flash(visual)
	Juice.squash(visual, Vector2(1.35, 0.7), 0.25)
	return false


func points() -> int:
	return int(p["points"])


## 5 - Caja de contacto en coordenadas del mundo.
func hitbox() -> Rect2:
	var w: float = float(p["width"])
	var h: float = float(p["height"])
	if kind == "flyer":
		return Rect2(global_position - Vector2(w, h) * 0.5, Vector2(w, h))
	return Rect2(global_position + Vector2(-w * 0.5, -h), Vector2(w, h))


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_t += delta
	if kind == "flyer":
		_fly(delta)
	elif kind == "boss":
		_boss(delta)
	else:
		_walk(delta)
	_face()


func _walk(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 1400.0)
	if is_on_floor() and _blocked_ahead():
		dir = -dir
	velocity.x = dir * float(p["speed"]) * Mods.tune("enemy_speed")
	move_and_slide()
	if is_on_wall():
		dir = -dir
	## 6 - Paso con rebote suave para que se note que camina.
	visual.position.y = -absf(sin(_t * 9.0)) * 3.0
	if global_position.y > float(rows.size() + 3) * tile:
		alive = false
		queue_free()


## 11 - Jefe: persigue al jugador dentro de su arena, cada pocos segundos se agacha (aviso)
## y salta hacia el. Al caer sacude la camara. Aturdido: parpadea y no se mueve.
func _boss(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 1600.0)
	var on_floor: bool = is_on_floor()
	if stun_left > 0.0:
		stun_left = maxf(stun_left - delta, 0.0)
		visual.modulate.a = 0.4 if int(stun_left * 12.0) % 2 == 0 else 1.0
		if stun_left == 0.0:
			visual.modulate.a = 1.0
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
		move_and_slide()
		return
	var near: bool = target != null and is_instance_valid(target) and absf(target.global_position.x - global_position.x) < tile * 9.0
	if on_floor:
		if _crouch_left > 0.0:
			_crouch_left -= delta
			velocity.x = 0.0
			if _crouch_left <= 0.0:
				var dx: float = (target.global_position.x - global_position.x) if near else dir * tile * 3.0
				velocity = Vector2(clampf(dx * 1.4, -420.0, 420.0), -980.0)
				dir = signf(velocity.x) if velocity.x != 0.0 else dir
				Juice.squash(visual, Vector2(0.8, 1.25))
		else:
			if near:
				dir = signf(target.global_position.x - global_position.x) if absf(target.global_position.x - global_position.x) > 8.0 else dir
			if _blocked_ahead():
				dir = -dir
			velocity.x = dir * float(p["speed"]) * (1.35 if hp * 2 <= max_hp else 1.0)
			_jump_timer -= delta
			if _jump_timer <= 0.0 and near:
				_jump_timer = float(p["jump_every"]) * (0.75 if hp * 2 <= max_hp else 1.0)
				_crouch_left = 0.45
				Juice.squash(visual, Vector2(1.3, 0.7), 0.45)
	move_and_slide()
	if is_on_wall():
		dir = -dir
	var landed: bool = is_on_floor() and not _was_on_floor
	_was_on_floor = is_on_floor()
	if landed:
		Juice.shake(0.25)
		Juice.squash(visual, Vector2(1.3, 0.75))
		Audio.play("land", 0.05, 2.0, 0.6)


func _fly(delta: float) -> void:
	var nx: float = position.x + dir * float(p["speed"]) * Mods.tune("enemy_speed") * delta
	var limit: float = float(p["range"]) * tile
	var front: int = int(floor((nx + dir * float(p["width"]) * 0.5) / tile))
	var row: int = int(floor(position.y / tile))
	if absf(nx - home.x) > limit or LevelAnalyzer.is_solid(rows, front, row):
		dir = -dir
		nx = position.x
	position.x = nx
	position.y = home.y + sin(_t * 2.4) * float(p["bob"])


## 7 - Mira delante: pared, pinchos o borde sin suelo hacen que se de la vuelta.
func _blocked_ahead() -> bool:
	var feet: Vector2 = global_position
	var front: int = int(floor((feet.x + dir * (float(p["width"]) * 0.5 + 4.0)) / tile))
	var row: int = int(floor((feet.y - 2.0) / tile))
	if LevelAnalyzer.is_solid(rows, front, row):
		return true
	if row >= 0 and row < rows.size() and front >= 0 and front < rows[row].length() and rows[row][front] == LevelBuilder.SPIKE:
		return true
	return not LevelAnalyzer.is_solid(rows, front, row + 1)


func _face() -> void:
	body.scale.x = 1.0 if dir > 0.0 else -1.0


## 8 - Derrota: se aplasta, se desvanece y desaparece. Ya no toca a nadie.
func die() -> void:
	if not alive:
		return
	alive = false
	collision_layer = 0
	collision_mask = 0
	defeated.emit(self)
	if anim_sprite != null and anim_sprite.sprite_frames.has_animation("hurt"):
		anim_sprite.play("hurt")
	var tw: Tween = create_tween()
	tw.tween_property(visual, "scale", Vector2(1.5, 0.28), 0.07).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(0.18)
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.tween_callback(queue_free)


func _build_shapes(col: Color, w: float, h: float) -> void:
	var base: Color = col if kind != "spiky" else col.darkened(0.25)
	var y0: float = -h * 0.5 if kind == "flyer" else -h
	if kind == "flyer":
		for side: float in [-1.0, 1.0]:
			var wing: Polygon2D = Polygon2D.new()
			wing.name = "Wing"
			wing.color = base.lightened(0.35)
			wing.polygon = PackedVector2Array([Vector2(0, -h * 0.2), Vector2(side * w * 0.7, -h * 0.75), Vector2(side * w * 0.55, -h * 0.05)])
			visual.add_child(wing)
			var flap: Tween = wing.create_tween().set_loops()
			flap.tween_property(wing, "scale:y", 0.35, 0.09)
			flap.tween_property(wing, "scale:y", 1.0, 0.09)
	var blob: Polygon2D = Polygon2D.new()
	blob.name = "Blob"
	blob.color = base
	blob.polygon = _rounded(Vector2(-w * 0.5, y0), Vector2(w, h), minf(w, h) * 0.38)
	visual.add_child(blob)
	var belly: Polygon2D = Polygon2D.new()
	belly.color = base.darkened(0.22)
	belly.polygon = _rounded(Vector2(-w * 0.5, y0 + h * 0.62), Vector2(w, h * 0.38), h * 0.16)
	visual.add_child(belly)
	for ex: float in [0.02, 0.24]:
		var eye: Polygon2D = Polygon2D.new()
		eye.color = Color("#f4f6fb")
		eye.polygon = _rounded(Vector2(w * ex, y0 + h * 0.2), Vector2(w * 0.18, h * 0.3), w * 0.06)
		visual.add_child(eye)
		var pupil: Polygon2D = Polygon2D.new()
		pupil.color = Color("#10131c")
		pupil.polygon = _rounded(Vector2(w * (ex + 0.08), y0 + h * 0.3), Vector2(w * 0.09, h * 0.16), w * 0.03)
		visual.add_child(pupil)
	if kind == "spiky":
		_add_spikes(col.lightened(0.55), w, h)
	if kind == "boss":
		## Corona y cuernos: el jefe se reconoce a primera vista.
		var crown: Polygon2D = Polygon2D.new()
		crown.name = "Crown"
		crown.color = Color("#f6cf7a")
		crown.polygon = PackedVector2Array([Vector2(-w * 0.25, y0 + 6.0), Vector2(-w * 0.28, y0 - h * 0.28), Vector2(-w * 0.12, y0 - h * 0.1),
			Vector2(0.0, y0 - h * 0.34), Vector2(w * 0.12, y0 - h * 0.1), Vector2(w * 0.28, y0 - h * 0.28), Vector2(w * 0.25, y0 + 6.0)])
		visual.add_child(crown)


func _add_spikes(col: Color, w: float, h: float) -> void:
	var spikes: Polygon2D = Polygon2D.new()
	spikes.name = "Spikes"
	spikes.color = col
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = 4
	for i: int in n:
		var x0: float = -w * 0.42 + w * 0.84 * float(i) / float(n)
		var x1: float = -w * 0.42 + w * 0.84 * float(i + 1) / float(n)
		pts.append(Vector2(x0, -h + 4.0))
		pts.append(Vector2((x0 + x1) * 0.5, -h - h * 0.38))
	pts.append(Vector2(w * 0.42, -h + 4.0))
	pts.append(Vector2(w * 0.42, -h + 10.0))
	pts.append(Vector2(-w * 0.42, -h + 10.0))
	spikes.polygon = pts
	visual.add_child(spikes)


static func _rounded(pos: Vector2, size: Vector2, r: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var rr: float = minf(r, minf(size.x, size.y) * 0.5)
	var corners: Array[Vector2] = [
		pos + Vector2(size.x - rr, rr), pos + Vector2(size.x - rr, size.y - rr),
		pos + Vector2(rr, size.y - rr), pos + Vector2(rr, rr),
	]
	for c: int in 4:
		for i: int in 5:
			var a: float = -PI * 0.5 + PI * 0.5 * float(c) + PI * 0.5 * float(i) / 4.0
			pts.append(corners[c] + Vector2(cos(a), sin(a)) * rr)
	return pts

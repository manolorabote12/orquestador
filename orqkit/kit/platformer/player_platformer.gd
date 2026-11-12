class_name PlayerPlatformer
extends CharacterBody2D
## Controlador de plataformas con el "feeling" de los juegos comerciales:
## 1 - Coyote time: puedes saltar un instante despues de dejar el borde.
## 2 - Buffer de salto: si pulsas justo antes de tocar el suelo, el salto sale igual.
## 3 - Salto variable: soltar el boton corta el salto.
## 4 - Apex hang: en lo mas alto del salto la gravedad baja un poco (mas control).
## 5 - Caida mas rapida que la subida y velocidad maxima de caida.
## 6 - Aceleracion y frenado separados en suelo y aire.
## 14 - Vida en corazones: un golpe empuja hacia atras, deja invulnerable y parpadea.
## 15b - Poderes: doble salto (resto del nivel), velocidad, estrella invencible e iman (temporales).
## 15c - Disparo (si game.json -> player -> shoot = true): proyectil hacia donde miras.
## 16 - Runner (player -> auto_run = 1): corre solo hacia la derecha; tu solo saltas.
##      speed_mult lo sube la partida segun avanzas (cada vez mas rapido).
## 21 - Volador (player -> flap = 1): arcade de un toque. Avanza solo, cae con gravedad y cada
##      toque da un impulso hacia arriba. Tocar un bloque es chocar. Espera al primer toque.
## Los parametros vienen de game.json -> "player" y se ajustan sin tocar codigo.

signal jumped
signal landed(impact_speed: float)
signal died(cause: String)
signal hurt_taken(hp_left: int)
signal shot(origin: Vector2, direction: float)
signal power_changed

const LAYER_PLAYER: int = 2

const DEFAULTS: Dictionary = {
	"run_speed": 430.0,
	"ground_accel": 4200.0,
	"ground_decel": 5200.0,
	"air_accel": 2600.0,
	"air_decel": 1400.0,
	"jump_height": 200.0,
	"time_to_apex": 0.36,
	"fall_gravity_mult": 1.7,
	"jump_cut_mult": 2.6,
	"apex_threshold": 60.0,
	"apex_gravity_mult": 0.55,
	"max_fall_speed": 1300.0,
	"coyote_time": 0.1,
	"jump_buffer": 0.12,
	"width": 40.0,
	"height": 56.0,
	"hp": 3.0,
	"invuln_time": 1.1,
	"hurt_lock": 0.28,
	"knockback_x": 380.0,
	"knockback_y": 520.0,
	"stomp_bounce": 0.62,
	"shoot": 0.0,
	"shoot_cooldown": 0.32,
	"power_seconds": 7.0,
	"auto_run": 0.0,
	"flap": 0.0,
	"flap_impulse": 600.0,
	"flap_gravity": 2000.0,
	"flap_max_fall": 820.0,
}

var p: Dictionary = {}
var gravity_up: float = 0.0
var jump_velocity: float = 0.0

var coyote_left: float = 0.0
var buffer_left: float = 0.0
var jumping: bool = false
var alive: bool = true
var facing: float = 1.0
var air_time: float = 0.0
var spawn_point: Vector2 = Vector2.ZERO
var max_hp: int = 3
var hp: int = 3
var invuln_left: float = 0.0
var hurt_lock_left: float = 0.0
var air_jumps: int = 0
var air_jumps_left: int = 0
var speed_left: float = 0.0
var star_left: float = 0.0
var magnet_left: float = 0.0
var can_shoot: bool = false
var auto_run: bool = false
var flap: bool = false
var flap_ready: bool = false
var speed_mult: float = 1.0
var _shoot_cd: float = 0.0

var body: Node2D
var anim_sprite: AnimatedSprite2D = null
var visual: Node2D
var _was_on_floor: bool = false
var _fall_speed_before: float = 0.0


func setup(params: Dictionary, color_body: Color, color_eye: Color, art: Dictionary = {}) -> void:
	p = DEFAULTS.duplicate()
	for key: String in params.keys():
		if p.has(key):
			p[key] = float(params[key])
	## 7 - Gravidad y velocidad de salto salen de la altura y el tiempo deseados.
	var h: float = float(p["jump_height"])
	var t: float = maxf(float(p["time_to_apex"]), 0.05)
	gravity_up = 2.0 * h / (t * t)
	jump_velocity = -2.0 * h / t
	max_hp = maxi(int(p["hp"]), 1)
	hp = max_hp
	can_shoot = float(p["shoot"]) > 0.5
	auto_run = float(p["auto_run"]) > 0.5
	flap = float(p["flap"]) > 0.5
	if flap:
		auto_run = true
	collision_layer = LAYER_PLAYER
	collision_mask = 1
	_build_shape(color_body, color_eye, art)
	## Aspecto comprado en la tienda (tinte sobre el arte del juego).
	Skins.apply(visual)


func _build_shape(color_body: Color, color_eye: Color, art: Dictionary) -> void:
	var w: float = float(p["width"])
	var hgt: float = float(p["height"])
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(w, hgt)
	shape.shape = rect
	shape.position = Vector2(0, -hgt * 0.5)
	add_child(shape)

	body = Node2D.new()
	body.name = "Body"
	add_child(body)
	## 11 - Body gira segun hacia donde miras; Visual se estira y aplasta. Asi no se pisan.
	visual = Node2D.new()
	visual.name = "Visual"
	body.add_child(visual)
	var poly: Polygon2D = Polygon2D.new()
	poly.color = color_body
	poly.polygon = PackedVector2Array([
		Vector2(-w * 0.5, -hgt), Vector2(w * 0.5, -hgt),
		Vector2(w * 0.5, 0), Vector2(-w * 0.5, 0),
	])
	visual.add_child(poly)
	var eye: Polygon2D = Polygon2D.new()
	eye.name = "Eye"
	eye.color = color_eye
	eye.polygon = PackedVector2Array([
		Vector2(4, -hgt + 14), Vector2(14, -hgt + 14),
		Vector2(14, -hgt + 26), Vector2(4, -hgt + 26),
	])
	visual.add_child(eye)
	## 12 - Con arte de la fabrica, el sprite animado sustituye a las formas simples.
	if not art.is_empty():
		poly.visible = false
		eye.visible = false
		## El dibujo va un 35 % mas grande que la caja de choque: asi el heroe se ve (12 nov: la critica
		## visual repetia "personaje pequeno") y los golpes siguen siendo justos.
		anim_sprite = SpriteKit.animado(art, hgt * 1.35, "idle", true)
		anim_sprite.name = "Sprite"
		visual.add_child(anim_sprite)
	floor_snap_length = 8.0
	floor_constant_speed = true


func respawn() -> void:
	global_position = spawn_point
	velocity = Vector2.ZERO
	jumping = false
	coyote_left = 0.0
	buffer_left = 0.0
	alive = true
	visual.scale = Vector2.ONE
	visual.rotation = 0.0
	hp = max_hp
	hurt_lock_left = 0.0
	speed_left = 0.0
	star_left = 0.0
	magnet_left = 0.0
	body.modulate = Color.WHITE
	## 15 - Proteccion breve al reaparecer para no morir dos veces seguidas.
	invuln_left = 0.6
	flap_ready = false


## 16 - Golpe de enemigo. Devuelve true si ha hecho dano (false si era invulnerable).
func hurt(from_x: float) -> bool:
	if not alive or invuln_left > 0.0 or star_left > 0.0:
		return false
	hp -= 1
	hurt_taken.emit(hp)
	if hp <= 0:
		kill("enemy")
		return true
	var away: float = signf(global_position.x - from_x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * float(p["knockback_x"]), -float(p["knockback_y"]))
	jumping = false
	invuln_left = float(p["invuln_time"])
	hurt_lock_left = float(p["hurt_lock"])
	Juice.squash(visual, Vector2(1.3, 0.75))
	return true


## 17 - Rebote al pisar un enemigo: manteniendo el salto se sube mas alto.
func bounce() -> void:
	var holding: bool = Input.is_action_pressed("jump")
	velocity.y = jump_velocity * Mods.tune("jump") * (1.0 if holding else float(p["stomp_bounce"]))
	jumping = true
	coyote_left = 0.0
	Juice.squash(visual, Vector2(0.75, 1.25))


## 18 - Poderes. Devuelve el texto que se ensena al cogerlo.
func give_power(kind: String) -> String:
	var secs: float = float(p["power_seconds"])
	match kind:
		"corazon":
			hp = mini(hp + 1, max_hp)
			power_changed.emit()
			return "+1"
		"doble_salto":
			air_jumps = 1
			air_jumps_left = 1
			power_changed.emit()
			return "x2"
		"velocidad":
			speed_left = secs
			power_changed.emit()
			return ">>"
		"estrella":
			star_left = secs
			power_changed.emit()
			return "*"
		"iman":
			magnet_left = secs + 3.0
			power_changed.emit()
			return "U"
	return ""


func invincible() -> bool:
	return star_left > 0.0


func hitbox() -> Rect2:
	var w: float = float(p["width"])
	var hgt: float = float(p["height"])
	return Rect2(global_position + Vector2(-w * 0.42, -hgt * 0.92), Vector2(w * 0.84, hgt * 0.92))


func kill(cause: String) -> void:
	if not alive:
		return
	alive = false
	died.emit(cause)


func _physics_process(delta: float) -> void:
	if not alive or p.is_empty():
		return
	var dir: float = 1.0 if auto_run else Input.get_axis("move_left", "move_right")
	var on_floor: bool = is_on_floor()
	if invuln_left > 0.0:
		invuln_left = maxf(invuln_left - delta, 0.0)
		body.modulate.a = 0.35 if int(invuln_left * 14.0) % 2 == 0 else 1.0
		if invuln_left == 0.0:
			body.modulate.a = 1.0
	if hurt_lock_left > 0.0:
		hurt_lock_left = maxf(hurt_lock_left - delta, 0.0)
		dir = 0.0
	_tick_powers(delta)
	if flap:
		_flap_process(delta)
		return

	## 8 - Horizontal: aceleracion distinta en suelo y aire, frenado mas brusco que el arranque.
	var target: float = dir * float(p["run_speed"]) * speed_mult * Mods.tune("speed") * (1.35 if speed_left > 0.0 else 1.0)
	var rate: float
	if on_floor:
		rate = float(p["ground_accel"]) if dir != 0.0 else float(p["ground_decel"])
	else:
		rate = float(p["air_accel"]) if dir != 0.0 else float(p["air_decel"])
	velocity.x = move_toward(velocity.x, target, rate * delta)
	if dir != 0.0:
		facing = signf(dir)
		body.scale.x = facing

	## 9 - Temporizadores de coyote y buffer.
	if on_floor:
		coyote_left = float(p["coyote_time"])
		jumping = false
		air_time = 0.0
		air_jumps_left = air_jumps
	else:
		coyote_left = maxf(coyote_left - delta, 0.0)
		air_time += delta
	if Input.is_action_just_pressed("jump"):
		buffer_left = float(p["jump_buffer"])
	else:
		buffer_left = maxf(buffer_left - delta, 0.0)

	if buffer_left > 0.0 and coyote_left > 0.0:
		_do_jump()
	elif Input.is_action_just_pressed("jump") and coyote_left <= 0.0 and air_jumps_left > 0 and not on_floor:
		## 19 - Doble salto: un segundo impulso en el aire, algo mas corto.
		air_jumps_left -= 1
		velocity.y = jump_velocity * Mods.tune("jump") * 0.88
		jumping = true
		buffer_left = 0.0
		Juice.squash(visual, Vector2(0.7, 1.3))
		Juice.ring(get_parent(), global_position + Vector2(0.0, -8.0), Color(1, 1, 1, 0.8), 44.0, 0.25)
		jumped.emit()

	if can_shoot:
		_shoot_cd = maxf(_shoot_cd - delta, 0.0)
		if Input.is_action_pressed("shoot") and _shoot_cd <= 0.0 and hurt_lock_left <= 0.0:
			_shoot_cd = float(p["shoot_cooldown"])
			shot.emit(global_position + Vector2(facing * float(p["width"]) * 0.6, -float(p["height"]) * 0.55), facing)

	## 10 - Gravedad: mas fuerte cayendo, mas fuerte si se suelta el salto, mas suave en el apice.
	var g: float = gravity_up
	var holding: bool = Input.is_action_pressed("jump")
	if velocity.y > 0.0:
		g = gravity_up * float(p["fall_gravity_mult"])
	elif jumping and not holding:
		g = gravity_up * float(p["jump_cut_mult"])
	if jumping and holding and absf(velocity.y) < float(p["apex_threshold"]):
		g *= float(p["apex_gravity_mult"])
	velocity.y = minf(velocity.y + g * Mods.tune("gravity") * delta, float(p["max_fall_speed"]))

	_fall_speed_before = velocity.y
	move_and_slide()

	var now_on_floor: bool = is_on_floor()
	if now_on_floor and not _was_on_floor:
		_on_landed(_fall_speed_before)
	_was_on_floor = now_on_floor
	_update_anim(now_on_floor)


## 22 - Volador: quieto flotando hasta el primer toque; luego avanza, cae y cada toque impulsa.
func _flap_process(delta: float) -> void:
	var tapped: bool = Input.is_action_just_pressed("jump")
	if not flap_ready:
		velocity = Vector2.ZERO
		visual.position.y = sin(Time.get_ticks_msec() * 0.006) * 6.0
		if tapped:
			flap_ready = true
			visual.position.y = 0.0
		else:
			_update_anim(false)
			return
	velocity.x = float(p["run_speed"]) * speed_mult * Mods.tune("speed") * (1.35 if speed_left > 0.0 else 1.0)
	if tapped:
		velocity.y = -float(p["flap_impulse"]) * Mods.tune("jump")
		Juice.squash(visual, Vector2(0.8, 1.2))
		jumped.emit()
	velocity.y = minf(velocity.y + float(p["flap_gravity"]) * Mods.tune("gravity") * delta, float(p["flap_max_fall"]))
	## 23 - Se inclina segun sube o baja (como un pajaro).
	visual.rotation = lerpf(visual.rotation, clampf(velocity.y / 1400.0, -0.35, 0.6), 1.0 - exp(-12.0 * delta))
	if can_shoot:
		_shoot_cd = maxf(_shoot_cd - delta, 0.0)
		if Input.is_action_pressed("shoot") and _shoot_cd <= 0.0:
			_shoot_cd = float(p["shoot_cooldown"])
			shot.emit(global_position + Vector2(float(p["width"]) * 0.6, -float(p["height"]) * 0.55), 1.0)
	move_and_slide()
	if get_slide_collision_count() > 0 and star_left <= 0.0:
		kill("crash")
	_update_anim(false)


## 13 - Elige la animacion segun el estado: quieto, corriendo, subiendo o cayendo.
func _update_anim(on_floor: bool) -> void:
	if anim_sprite == null:
		return
	var want: String = "idle"
	if hurt_lock_left > 0.0 and anim_sprite.sprite_frames.has_animation("hurt"):
		want = "hurt"
	elif not on_floor:
		want = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > 30.0:
		want = "run"
	if anim_sprite.sprite_frames.has_animation(want) and anim_sprite.animation != want:
		anim_sprite.play(want)


func _tick_powers(delta: float) -> void:
	var before: bool = speed_left > 0.0 or star_left > 0.0 or magnet_left > 0.0
	speed_left = maxf(speed_left - delta, 0.0)
	magnet_left = maxf(magnet_left - delta, 0.0)
	if star_left > 0.0:
		star_left = maxf(star_left - delta, 0.0)
		## 20 - Estrella: arcoiris rapido; parpadea el ultimo segundo para avisar.
		var hue: float = fmod(star_left * 2.5, 1.0)
		body.modulate = Color.from_hsv(hue, 0.45, 1.25) if star_left > 1.0 or int(star_left * 10.0) % 2 == 0 else Color.WHITE
		if star_left == 0.0:
			body.modulate = Color.WHITE
	var after: bool = speed_left > 0.0 or star_left > 0.0 or magnet_left > 0.0
	if before != after:
		power_changed.emit()


func _do_jump() -> void:
	velocity.y = jump_velocity * Mods.tune("jump")
	jumping = true
	coyote_left = 0.0
	buffer_left = 0.0
	Juice.squash(visual, Vector2(0.78, 1.22))
	Juice.dust(get_parent(), global_position, Color(1, 1, 1, 0.7), 5)
	jumped.emit()


func _on_landed(speed: float) -> void:
	if speed < 120.0:
		return
	var k: float = clampf(speed / float(p["max_fall_speed"]), 0.0, 1.0)
	Juice.squash(visual, Vector2(1.0 + 0.3 * k, 1.0 - 0.25 * k))
	Juice.dust(get_parent(), global_position, Color(1, 1, 1, 0.75), 4 + int(8.0 * k), 0.8 + k)
	if k > 0.6:
		Juice.shake(0.12 * k)
	landed.emit(speed)

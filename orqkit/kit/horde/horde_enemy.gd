class_name HordeEnemy
extends Node2D
## Enemigo de las hordas (vista desde arriba). Sin fisica: persigue al jugador, rodea las
## rocas probando cada eje por separado y se empuja un poco con los vecinos.
## 1 - walker: normal. spiky: lento y duro (pega 2). flyer: rapido y fragil, vuela sobre rocas.
## 2 - boss: grande, mucha vida y embiste cada pocos segundos (se para y avisa antes).

const STATS: Dictionary = {
	"walker": {"speed": 95.0, "hp": 2.0, "damage": 1, "radius": 26.0, "size": 80.0, "xp": 1},
	"spiky": {"speed": 62.0, "hp": 7.0, "damage": 2, "radius": 30.0, "size": 90.0, "xp": 3},
	"flyer": {"speed": 150.0, "hp": 1.5, "damage": 1, "radius": 22.0, "size": 70.0, "xp": 1},
	"boss": {"speed": 82.0, "hp": 70.0, "damage": 2, "radius": 64.0, "size": 180.0, "xp": 30},
}

var kind: String = "walker"
var hp: float = 3.0
var max_hp: float = 3.0
var speed: float = 95.0
var damage: int = 1
var radius: float = 26.0
var xp: int = 1
var alive: bool = true
var flies: bool = false
var visual: Node2D
var _flash_left: float = 0.0
var _dash_timer: float = 0.0
var _dash_left: float = 0.0
var _windup_left: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO


func setup(enemy_kind: String, hp_mult: float, speed_mult: float, over: Dictionary = {}) -> void:
	kind = enemy_kind
	var s: Dictionary = (STATS.get(kind, STATS["walker"]) as Dictionary).duplicate()
	## Cambios del catalogo del juego (vida, velocidad, dano, tamano, experiencia).
	for k: String in over:
		if s.has(k):
			s[k] = over[k]
	max_hp = float(s["hp"]) * hp_mult
	hp = max_hp
	speed = float(s["speed"]) * speed_mult
	damage = int(s["damage"])
	radius = float(s["radius"])
	xp = int(s["xp"])
	## El jefe pasa por encima de las rocas: nunca se queda atascado en una esquina.
	flies = kind == "flyer" or kind == "boss"
	_dash_timer = 3.5
	visual = Node2D.new()
	add_child(visual)
	var art_id: String = str(Kit.param("art.enemies." + kind, ""))
	var entry: Dictionary = Kit.sprite_entry(art_id) if art_id != "" else {}
	if entry.is_empty() and kind != "boss":
		entry = Kit.sprite_by_role("enemigo")
	if not entry.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(entry, float(s["size"]), "run", false)
		visual.add_child(spr)
	else:
		var body: Polygon2D = Polygon2D.new()
		body.color = Kit.color("enemy", Color("#d9774a")) if kind != "boss" else Kit.color("danger", Color("#ff6b5b"))
		body.polygon = LevelBuilder._circle(radius, 18)
		visual.add_child(body)
		var eye: Polygon2D = Polygon2D.new()
		eye.color = Color(1, 1, 1, 0.9)
		eye.polygon = LevelBuilder._circle(radius * 0.28, 10)
		eye.position = Vector2(radius * 0.35, -radius * 0.2)
		visual.add_child(eye)


## 3 - Movimiento hacia el objetivo. solid(p) dice si una posicion esta dentro de una roca.
func step(delta: float, target: Vector2, solid: Callable) -> void:
	if not alive:
		return
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			visual.modulate = Color.WHITE
	var dir: Vector2 = (target - global_position).normalized()
	var v: float = speed * Mods.tune("enemy_speed")
	if kind == "boss":
		v = _boss_speed(delta, dir)
		if _dash_left > 0.0:
			dir = _dash_dir
	if absf(dir.x) > 0.1:
		visual.scale.x = signf(dir.x)
	var move: Vector2 = dir * v * delta
	## Si algo lo ha metido dentro de una roca, sale sin chocar.
	if flies or bool(solid.call(global_position, radius * 0.7)):
		global_position += move
		return
	var nx: Vector2 = global_position + Vector2(move.x, 0.0)
	if not bool(solid.call(nx, radius * 0.7)):
		global_position = nx
	var ny: Vector2 = global_position + Vector2(0.0, move.y)
	if not bool(solid.call(ny, radius * 0.7)):
		global_position = ny


## 4 - Jefe: cada 3,5 s se agacha (aviso de 0,6 s) y embiste en linea recta.
func _boss_speed(delta: float, dir: Vector2) -> float:
	if _windup_left > 0.0:
		_windup_left -= delta
		visual.scale.y = 0.85
		if _windup_left <= 0.0:
			visual.scale.y = 1.0
			_dash_left = 0.55
			_dash_dir = dir
		return 0.0
	if _dash_left > 0.0:
		_dash_left -= delta
		return speed * 4.2
	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_dash_timer = 3.5
		_windup_left = 0.6
	return speed


## 5 - Golpe. Devuelve true si muere.
func hit(amount: float) -> bool:
	if not alive:
		return false
	hp -= amount
	visual.modulate = Color(3, 3, 3, 1)
	_flash_left = 0.06
	if hp <= 0.0:
		alive = false
		return true
	return false

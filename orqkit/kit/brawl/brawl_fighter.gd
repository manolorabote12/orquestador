class_name BrawlFighter
extends Node2D
## Un luchador de la arena (el jugador o un rival). Solo guarda su estado y se dibuja:
## sombra, barra de vida con numero, cubos de poder y (el jugador) la municion.
## La logica (moverse, disparar, IA) la lleva el juego.

const RADIUS: float = 34.0
const AMMO_MAX: int = 3

var is_player: bool = false
var fighter_name: String = ""
var max_hp: float = 3000.0
var hp: float = 3000.0
var damage: float = 400.0
var power: int = 0
var ammo: float = 3.0
var reload_time: float = 1.1
var super_charge: float = 0.0
var speed: float = 320.0
var alive: bool = true
var in_bush: bool = false
## Segundos que sigue visible tras disparar o recibir dano estando en un arbusto.
var reveal: float = 0.0
## Segundos desde el ultimo golpe dado o recibido (a los 3 s se cura).
var calm: float = 0.0
var facing: Vector2 = Vector2.UP
var velocity: Vector2 = Vector2.ZERO
var bar_color: Color = Color("#5fd35f")
var sprite: AnimatedSprite2D = null
var body: Polygon2D = null
## Nodo que envuelve el dibujo (se estira y aplasta sin tocar la escala del sprite).
var rig: Node2D = null
## Memoria de la IA de los rivales.
var ai: Dictionary = {}
## Arena en directo: id en la red, si lo mueve otro dispositivo, a donde va y cuando se supo de el.
var net_id: String = ""
var remote: bool = false
## Equipo (cooperativo): 0 los jugadores, 1 los bots. -1 = todos contra todos.
var team: int = -1
var net_pos: Vector2 = Vector2.ZERO
var last_seen: float = 0.0


func setup(entry: Dictionary, col: Color, size_px: float) -> void:
	rig = Node2D.new()
	rig.name = "Rig"
	add_child(rig)
	if not entry.is_empty():
		sprite = SpriteKit.animado(entry, size_px, "idle", true)
		rig.add_child(sprite)
	else:
		body = Polygon2D.new()
		body.color = col
		body.polygon = LevelBuilder._circle(RADIUS, 24)
		body.position = Vector2(0.0, -RADIUS * 0.6)
		rig.add_child(body)


func hit(amount: float) -> bool:
	if not alive:
		return false
	hp -= amount
	calm = 0.0
	reveal = maxf(reveal, 1.0)
	queue_redraw()
	if hp <= 0.0:
		hp = 0.0
		alive = false
		return true
	return false


func add_power() -> void:
	power += 1
	var k: float = 1.0 + 0.1 * float(power)
	var ratio: float = hp / max_hp
	max_hp = float(ai.get("base_hp", max_hp)) * k
	hp = minf(max_hp, max_hp * ratio + max_hp * 0.1)
	damage = float(ai.get("base_dmg", damage)) * k
	queue_redraw()


func remember_base() -> void:
	ai["base_hp"] = max_hp
	ai["base_dmg"] = damage


func animate(moving: bool) -> void:
	if sprite == null:
		return
	var want: String = "run" if moving and sprite.sprite_frames.has_animation("run") else "idle"
	if sprite.sprite_frames.has_animation(want) and sprite.animation != want:
		sprite.play(want)
	if absf(facing.x) > 0.2:
		sprite.flip_h = facing.x < 0.0


func _draw() -> void:
	if not alive:
		return
	## Sombra.
	draw_set_transform(Vector2(0.0, 6.0), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, RADIUS * 1.05, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	## Aro de equipo bajo los pies (verde el jugador, rojo los rivales).
	draw_set_transform(Vector2(0.0, 4.0), 0.0, Vector2(1.0, 0.42))
	draw_arc(Vector2.ZERO, RADIUS * 1.1, 0.0, TAU, 32, Color(bar_color, 0.85), 5.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Barra de vida con numero, cubos y municion: la dibuja el juego en la capa de efectos
## (por encima de los arbustos), en la posicion del luchador.
func draw_overlay(n: CanvasItem) -> void:
	if not alive or modulate.a < 0.1:
		return
	var o: Vector2 = position
	var w: float = 96.0
	var top: float = -RADIUS * 2.9
	## Nombre (en la arena en directo) encima de la barra.
	if fighter_name != "" and UI.font != null:
		var nw: float = UI.font.get_string_size(fighter_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		n.draw_string_outline(UI.font, o + Vector2(-nw * 0.5, top - 30.0), fighter_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0.05, 0.05, 0.08))
		n.draw_string(UI.font, o + Vector2(-nw * 0.5, top - 30.0), fighter_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, bar_color.lightened(0.4))
	var r: Rect2 = Rect2(o + Vector2(-w * 0.5, top), Vector2(w, 16.0))
	n.draw_rect(r.grow(3.0), Color(0.05, 0.05, 0.08, 0.85))
	n.draw_rect(Rect2(r.position, Vector2(w * clampf(hp / max_hp, 0.0, 1.0), 16.0)), bar_color)
	n.draw_rect(Rect2(r.position, Vector2(w * clampf(hp / max_hp, 0.0, 1.0), 5.0)), Color(1, 1, 1, 0.3))
	var f: Font = UI.font
	if f != null:
		var txt: String = str(int(ceil(hp)))
		var tw: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		n.draw_string_outline(f, o + Vector2(-tw * 0.5, top - 4.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0.05, 0.05, 0.08))
		n.draw_string(f, o + Vector2(-tw * 0.5, top - 4.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		if power > 0:
			var ptxt: String = str(power)
			n.draw_rect(Rect2(o + Vector2(w * 0.5 + 4.0, top - 6.0), Vector2(26.0, 26.0)), Color("#b05cff"))
			n.draw_string(f, o + Vector2(w * 0.5 + 10.0, top + 14.0), ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	## Municion del jugador: tres tramos bajo la vida.
	if is_player:
		var seg: float = (w - 8.0) / float(AMMO_MAX)
		for i: int in AMMO_MAX:
			var fill: float = clampf(ammo - float(i), 0.0, 1.0)
			var sr: Rect2 = Rect2(o + Vector2(-w * 0.5 + float(i) * (seg + 4.0), top + 21.0), Vector2(seg, 8.0))
			n.draw_rect(sr, Color(0.05, 0.05, 0.08, 0.85))
			n.draw_rect(Rect2(sr.position, Vector2(seg * fill, 8.0)), Color("#ffb627") if fill >= 1.0 else Color("#a57a2a"))

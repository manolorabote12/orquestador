class_name GhostRunner
extends Node2D
## Fantasma: la carrera de otro jugador (su mejor marca) como una sombra que corre a la vez que tu.
## Recorrido: puntos [x, y] cada 0,1 s; se mueve con el reloj del nivel (time_in_level del juego).

const STEP: float = 0.1

var points: PackedVector2Array = PackedVector2Array()
var game: Node = null
var alias: String = ""
var _label: Label


static func make(data: Dictionary, host_game: Node, art: Dictionary, height: float) -> GhostRunner:
	var g: GhostRunner = GhostRunner.new()
	g.name = "Ghost"
	g.game = host_game
	g.alias = str(data.get("alias", ""))
	for p: Variant in data.get("datos", []):
		if p is Array and (p as Array).size() == 2:
			g.points.append(Vector2(float(p[0]), float(p[1])))
	if not art.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(art, height, "run" if (art.get("animaciones", {}) as Dictionary).has("run") else "idle", true)
		spr.modulate = Color(0.55, 0.8, 1.0, 0.45)
		g.add_child(spr)
	g._label = Label.new()
	g._label.text = g.alias
	g._label.add_theme_font_size_override("font_size", 22)
	g._label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0, 0.8))
	g._label.position = Vector2(-60, -height - 34)
	g._label.size = Vector2(120, 30)
	g._label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.add_child(g._label)
	g.z_index = 4
	if not g.points.is_empty():
		g.position = g.points[0]
	return g


func _physics_process(_delta: float) -> void:
	if points.size() < 2 or game == null or not is_instance_valid(game):
		return
	var t: float = float(game.get("time_in_level")) / STEP
	var i: int = clampi(int(t), 0, points.size() - 1)
	var j: int = mini(i + 1, points.size() - 1)
	var np: Vector2 = points[i].lerp(points[j], clampf(t - float(i), 0.0, 1.0))
	var spr: Node = get_child(0)
	if spr is AnimatedSprite2D and absf(np.x - position.x) > 0.5:
		(spr as AnimatedSprite2D).flip_h = np.x < position.x
	position = np
	## Al acabar su recorrido se desvanece.
	visible = i < points.size() - 1

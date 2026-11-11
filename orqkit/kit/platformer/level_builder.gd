class_name LevelBuilder
extends RefCounted
## Construye un nivel a partir de un mapa de texto (lo que generara la IA en game.json).
## Leyenda:  #  bloque solido    P  salida del jugador    G  meta
##           C  moneda           ^  pinchos              .  vacio
##           E  enemigo que patrulla   K  enemigo con pinchos   F  enemigo volador
##           B  jefe final (la meta se abre al vencerlo)   R  punto de control
##           =  plataforma movil (los = seguidos forman una)
##           Poderes: H corazon  J doble salto  M iman  V velocidad  I estrella invencible
## Los bloques seguidos de una fila se unen en una sola colision (menos nodos, sin enganchones).

const SOLID: String = "#"
const PLAYER: String = "P"
const GOAL: String = "G"
const COIN: String = "C"
const SPIKE: String = "^"
const CHECKPOINT: String = "R"
const MOVING: String = "="
const PICKUPS: Dictionary = {"H": "corazon", "J": "doble_salto", "M": "iman", "V": "velocidad", "I": "estrella"}


static func normalize(map: Array) -> Array[String]:
	var rows: Array[String] = []
	var width: int = 0
	for row: Variant in map:
		width = maxi(width, str(row).length())
	for row: Variant in map:
		rows.append(str(row).rpad(width, "."))
	return rows


## 1 - Devuelve: spawn, goal, size, bottom, coins (Array[Area2D]), spikes, goal_area,
## enemy_spawns (Array de {kind, pos}: el juego crea los enemigos con sus parametros).
static func build(parent: Node2D, map: Array, tile: float, palette: Dictionary, art: Dictionary = {}) -> Dictionary:
	var rows: Array[String] = normalize(map)
	var h: int = rows.size()
	var w: int = rows[0].length() if h > 0 else 0
	var result: Dictionary = {
		"spawn": Vector2(tile * 1.5, tile * 2.0),
		"goal": Vector2.ZERO,
		"size": Vector2(w * tile, h * tile),
		"bottom": h * tile,
		"coins": [] as Array[Area2D],
		"spikes": [] as Array[Area2D],
		"goal_area": null,
		"enemy_spawns": [],
		"pickups": [],
		"checkpoints": [] as Array[Area2D],
		"platforms": [] as Array[MovingPlatform],
	}

	var solids: StaticBody2D = StaticBody2D.new()
	solids.name = "Solids"
	parent.add_child(solids)

	var c_solid: Color = palette.get("solid", Color.WHITE)
	var c_top: Color = c_solid.lightened(0.35)
	var c_danger: Color = palette.get("danger", Color.RED)
	var c_coin: Color = palette.get("coin", Color.YELLOW)
	var c_accent: Color = palette.get("accent", Color.ORANGE)
	var tile_tex: Texture2D = art.get("tile", null)
	var coin_art: Dictionary = art.get("coin", {})

	for y: int in h:
		var x: int = 0
		while x < w:
			var ch: String = rows[y][x]
			if ch == SOLID:
				## Cada tramo es todo «con aire encima» o todo «tapado»: el borde de arriba y la sombra
				## del relleno salen exactos casilla a casilla.
				var start: int = x
				var open_top: bool = y == 0 or rows[y - 1][x] != SOLID
				while x < w and rows[y][x] == SOLID and (y == 0 or rows[y - 1][x] != SOLID) == open_top:
					x += 1
				_add_solid_run(solids, start, x - start, y, tile, c_solid, c_top, open_top, tile_tex)
				continue
			if ch == MOVING:
				var start_m: int = x
				while x < w and rows[y][x] == MOVING:
					x += 1
				var count: int = x - start_m
				var mp: MovingPlatform = MovingPlatform.new()
				mp.name = "Moving"
				parent.add_child(mp)
				var amp: float = tile * maxf(float(_free_span(rows, start_m, x, y)) - 0.25, 0.0)
				mp.setup(Vector2((start_m + count * 0.5) * tile, (y + 0.5) * tile), count * tile, tile, amp, c_solid.lightened(0.15), tile_tex)
				(result["platforms"] as Array[MovingPlatform]).append(mp)
				continue
			var center: Vector2 = Vector2((x + 0.5) * tile, (y + 0.5) * tile)
			if ch == PLAYER:
				result["spawn"] = Vector2((x + 0.5) * tile, (y + 1.0) * tile)
			elif ch == GOAL:
				result["goal"] = center
				result["goal_area"] = _add_goal(parent, center, tile, c_accent)
			elif ch == COIN:
				(result["coins"] as Array[Area2D]).append(_add_coin(parent, center, tile, c_coin, coin_art))
			elif ch == SPIKE:
				(result["spikes"] as Array[Area2D]).append(_add_spike(parent, center, tile, c_danger))
			elif PICKUPS.has(ch):
				(result["pickups"] as Array).append({"area": _add_pickup(parent, center, tile, str(PICKUPS[ch])), "kind": str(PICKUPS[ch])})
			elif ch == CHECKPOINT:
				(result["checkpoints"] as Array[Area2D]).append(_add_checkpoint(parent, Vector2(center.x, (y + 1.0) * tile), tile, c_accent))
			elif Enemy.KINDS.has(ch):
				var kind: String = str(Enemy.KINDS[ch])
				var at: Vector2 = center if kind == "flyer" else Vector2(center.x, (y + 1.0) * tile)
				(result["enemy_spawns"] as Array).append({"kind": kind, "pos": at})
			x += 1
	return result


static func _add_solid_run(solids: StaticBody2D, x0: int, count: int, y: int, tile: float, col: Color, top: Color, exposed: bool, tex: Texture2D = null) -> void:
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(count * tile, tile)
	shape.shape = rect
	shape.position = Vector2((x0 + count * 0.5) * tile, (y + 0.5) * tile)
	solids.add_child(shape)
	var poly: Polygon2D = Polygon2D.new()
	poly.color = col
	poly.polygon = _rect(Vector2(x0 * tile, y * tile), Vector2(count * tile, tile))
	## 4 - Con tile de la fabrica: textura repetida, un tile de la imagen por casilla.
	if tex != null:
		poly.texture = tex
		## El relleno (sin aire encima) va mas oscuro: el suelo deja de ser una losa plana y se lee
		## donde se pisa.
		poly.color = Color.WHITE if exposed else Color(0.62, 0.62, 0.68)
		poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		if float(tex.get_width()) > tile:
			poly.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var k: float = float(tex.get_width()) / tile
		var uv: PackedVector2Array = PackedVector2Array()
		for v: Vector2 in poly.polygon:
			uv.append(v * k)
		poly.uv = uv
	solids.add_child(poly)
	if exposed:
		var lip: Polygon2D = Polygon2D.new()
		lip.color = top if tex == null else Color(top.r, top.g, top.b, 0.78)
		lip.polygon = _rect(Vector2(x0 * tile, y * tile), Vector2(count * tile, tile * 0.16))
		solids.add_child(lip)
		if tex != null:
			## Linea de sombra bajo el borde: separa «donde se pisa» del cuerpo del bloque.
			var edge: Polygon2D = Polygon2D.new()
			edge.color = Color(0.0, 0.0, 0.05, 0.3)
			edge.polygon = _rect(Vector2(x0 * tile, (y + 0.16) * tile), Vector2(count * tile, tile * 0.05))
			solids.add_child(edge)


static func _add_coin(parent: Node2D, center: Vector2, tile: float, col: Color, art: Dictionary = {}) -> Area2D:
	var area: Area2D = _area(parent, center, "coin")
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = tile * 0.28
	shape.shape = circle
	area.add_child(shape)
	var poly: Node2D
	if art.is_empty():
		var shape_poly: Polygon2D = Polygon2D.new()
		shape_poly.color = col
		shape_poly.polygon = _circle(tile * 0.22, 14)
		poly = shape_poly
	else:
		poly = SpriteKit.animado(art, tile * 0.5, "spin", false)
	poly.name = "Look"
	area.add_child(poly)
	## 2 - Flotan un poco, desfasadas por posicion para que no se muevan todas a la vez.
	var tween: Tween = area.create_tween().set_loops()
	tween.tween_property(poly, "position:y", -6.0, 0.6 + fmod(center.x, 0.3)).set_trans(Tween.TRANS_SINE)
	tween.tween_property(poly, "position:y", 0.0, 0.6 + fmod(center.x, 0.3)).set_trans(Tween.TRANS_SINE)
	return area


static func _add_spike(parent: Node2D, center: Vector2, tile: float, col: Color) -> Area2D:
	var area: Area2D = _area(parent, center, "spike")
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	## 3 - La caja de dano es mas pequena que el dibujo: el jugador perdona, no frustra.
	rect.size = Vector2(tile * 0.7, tile * 0.38)
	shape.shape = rect
	shape.position = Vector2(0, tile * 0.28)
	area.add_child(shape)
	var poly: Polygon2D = Polygon2D.new()
	poly.color = col
	var half: float = tile * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-half, half), Vector2(-half * 0.5, 0), Vector2(0, half),
		Vector2(half * 0.5, 0), Vector2(half, half),
	])
	area.add_child(poly)
	return area


## 6 - Recorrido de una plataforma movil: casillas libres al lado mas corto. Llega casi hasta
## los bordes (a un cuarto de casilla) para que se pueda subir y bajar andando.
static func _free_span(rows: Array[String], x0: int, x1: int, y: int) -> int:
	var left: int = 0
	while x0 - left - 1 >= 0 and rows[y][x0 - left - 1] == "." and left < 6:
		left += 1
	var right: int = 0
	while x1 + right < rows[y].length() and rows[y][x1 + right] == "." and right < 6:
		right += 1
	return mini(left, right)


## 7 - Poderes: icono reconocible con un halo que late.
static func _add_pickup(parent: Node2D, center: Vector2, tile: float, kind: String) -> Area2D:
	var area: Area2D = _area(parent, center, "pickup")
	area.set_meta("kind", kind)
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = tile * 0.34
	shape.shape = circle
	area.add_child(shape)
	var cols: Dictionary = {"corazon": Color("#ff6b7a"), "doble_salto": Color("#6fe0ff"), "iman": Color("#ff8a5c"),
		"velocidad": Color("#ffe066"), "estrella": Color("#fff2a8")}
	var col: Color = cols.get(kind, Color.WHITE)
	var look: Node2D = Node2D.new()
	look.name = "Look"
	area.add_child(look)
	var halo: Polygon2D = Polygon2D.new()
	halo.color = Color(col.r, col.g, col.b, 0.25)
	halo.polygon = _circle(tile * 0.4, 20)
	look.add_child(halo)
	var r: float = tile * 0.24
	var icon: Polygon2D = Polygon2D.new()
	icon.color = col
	match kind:
		"corazon":
			var pts: PackedVector2Array = PackedVector2Array()
			for i: int in 24:
				var t: float = TAU * float(i) / 24.0
				pts.append(Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * (r / 15.0))
			icon.polygon = pts
		"doble_salto":
			icon.polygon = PackedVector2Array([Vector2(-r, 0), Vector2(0, -r), Vector2(r, 0), Vector2(r * 0.6, r * 0.25), Vector2(0, -r * 0.45),
				Vector2(-r * 0.6, r * 0.25)])
			var second: Polygon2D = icon.duplicate() as Polygon2D
			second.position = Vector2(0, r * 0.75)
			look.add_child(second)
		"iman":
			icon.polygon = PackedVector2Array([Vector2(-r, -r), Vector2(-r * 0.45, -r), Vector2(-r * 0.45, r * 0.2), Vector2(r * 0.45, r * 0.2),
				Vector2(r * 0.45, -r), Vector2(r, -r), Vector2(r, r * 0.6), Vector2(-r, r * 0.6)])
		"velocidad":
			icon.polygon = PackedVector2Array([Vector2(r * 0.2, -r * 1.1), Vector2(-r * 0.6, r * 0.1), Vector2(-r * 0.05, r * 0.1),
				Vector2(-r * 0.3, r * 1.1), Vector2(r * 0.6, -r * 0.15), Vector2(r * 0.05, -r * 0.15)])
		_:
			var star: PackedVector2Array = PackedVector2Array()
			for i: int in 10:
				var a: float = -PI * 0.5 + PI * float(i) / 5.0
				star.append(Vector2(cos(a), sin(a)) * (r * 1.15 if i % 2 == 0 else r * 0.5))
			icon.polygon = star
	look.add_child(icon)
	var tw: Tween = area.create_tween().set_loops()
	tw.tween_property(halo, "scale", Vector2(1.25, 1.25), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(halo, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	var bob: Tween = area.create_tween().set_loops()
	bob.tween_property(look, "position:y", -7.0, 0.7).set_trans(Tween.TRANS_SINE)
	bob.tween_property(look, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	return area


## 8 - Punto de control: banderin bajado que se iza al pasar.
static func _add_checkpoint(parent: Node2D, feet: Vector2, tile: float, col: Color) -> Area2D:
	var area: Area2D = _area(parent, feet + Vector2(0.0, -tile * 0.5), "checkpoint")
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(tile * 0.6, tile)
	shape.shape = rect
	area.add_child(shape)
	var pole: Polygon2D = Polygon2D.new()
	pole.color = Color(0.85, 0.88, 0.95)
	pole.polygon = _rect(Vector2(-3.0, -tile * 0.5), Vector2(6.0, tile))
	area.add_child(pole)
	var flag: Polygon2D = Polygon2D.new()
	flag.name = "Flag"
	flag.color = col.darkened(0.45)
	flag.polygon = PackedVector2Array([Vector2(3.0, 0.0), Vector2(tile * 0.42, tile * 0.12), Vector2(3.0, tile * 0.26)])
	area.add_child(flag)
	return area


static func _add_goal(parent: Node2D, center: Vector2, tile: float, col: Color) -> Area2D:
	var area: Area2D = _area(parent, center, "goal")
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(tile * 0.8, tile)
	shape.shape = rect
	area.add_child(shape)
	var pole: Polygon2D = Polygon2D.new()
	pole.color = col.lightened(0.4)
	pole.polygon = _rect(Vector2(-tile * 0.06, -tile * 0.5), Vector2(tile * 0.12, tile))
	area.add_child(pole)
	var flag: Polygon2D = Polygon2D.new()
	flag.name = "Flag"
	flag.color = col
	flag.polygon = PackedVector2Array([
		Vector2(tile * 0.06, -tile * 0.5), Vector2(tile * 0.46, -tile * 0.36), Vector2(tile * 0.06, -tile * 0.2),
	])
	area.add_child(flag)
	return area


static func _area(parent: Node2D, center: Vector2, group: String) -> Area2D:
	var area: Area2D = Area2D.new()
	area.position = center
	area.monitorable = false
	## 5 - Detecta la capa del mundo (1) y la del jugador (2).
	area.collision_mask = 3
	area.add_to_group(group)
	parent.add_child(area)
	return area


static func _rect(pos: Vector2, size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([pos, pos + Vector2(size.x, 0), pos + size, pos + Vector2(0, size.y)])


static func _circle(radius: float, points: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i: int in points:
		var a: float = TAU * float(i) / float(points)
		arr.append(Vector2(cos(a), sin(a)) * radius)
	return arr

class_name QaBot
extends RefCounted
## Bot "corredor" que comparten las pruebas y el validador de la fabrica. Decide en cada frame:
## 1 - Correr a la derecha y saltar ante muros, huecos, pinchos y enemigos.
## 2 - Bajar andando las bajadas con suelo firme (saltar ahi seria peor).
## 3 - Plataformas moviles: esperar a que se acerque, subirse quieto y bajar al llegar.
## 4 - Disparar si el juego tiene disparo y hay un enemigo delante.
## 5 - Jefe: ir a por el y saltarle encima cuando esta cerca y no aturdido.
## 6 - Si el juego desaparece a mitad, suelta los controles y termina.
## 7 - Runner: mira mas lejos cuanto mas rapido corre.
## 8 - Volador: apunta al centro del hueco de la siguiente tuberia y toca cuando va por debajo.
## Si completa un nivel con la fisica real, el nivel es jugable de verdad.


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	## Las hordas (vista desde arriba) tienen su propio bot.
	if game.has_method("horde_bot_step"):
		return await HordeBot.run(tree, game, max_frames)
	if game.has_method("match3_bot_step"):
		return await Match3Bot.run(tree, game, max_frames)
	if game.has_method("tower_bot_step"):
		return await TowerBot.run(tree, game, max_frames)
	if game.has_method("race_bot_step"):
		return await RaceBot.run(tree, game, max_frames)
	## Generos nuevos: la escena dice que bot la juega (script con static run(tree, game, max_frames)).
	if game.has_method("bot_script"):
		var s: GDScript = load(str(game.call("bot_script")))
		return await s.call("run", tree, game, max_frames)
	var player: PlayerPlatformer = game.get("player")
	var rows: Array[String] = game.get("rows")
	var tile: float = float(Kit.param("tile_size", 64.0))
	var half_w: float = float(player.p["width"]) * 0.5
	var hold: int = 0
	var last_target: float = float(rows.size()) * tile * 0.45
	for f: int in max_frames:
		await tree.physics_frame
		## 6 - Si el juego se cierra mientras corre (capturas, salir al menu), el bot para.
		if not is_instance_valid(game) or not is_instance_valid(player):
			release_all()
			return false
		if bool(game.get("finished")):
			release_all()
			return true
		var feet: Vector2 = player.global_position
		if player.flap:
			## Un toque = pulsar un frame y soltar el siguiente.
			if Input.is_action_pressed("jump"):
				Input.action_release("jump")
				continue
			var target: float = flap_target(rows, feet.x - half_w, tile, last_target)
			last_target = target
			var center_y: float = feet.y - float(player.p["height"]) * 0.5
			## Cada toque sube "rise" px: se toca media subida por debajo del centro del hueco,
			## asi el vaiven queda centrado en el hueco.
			var imp: float = float(player.p["flap_impulse"])
			var rise: float = imp * imp / (2.0 * float(player.p["flap_gravity"]))
			var vx: float = float(player.p["run_speed"]) * player.speed_mult
			## Busca una secuencia de toques que no choque en los proximos 0,8 s (probando antes
			## lo que sugiere el hueco) y hace el primer paso.
			var first: int = 1 if center_y > target + rise * 0.5 and player.velocity.y > -60.0 else 0
			var tap_now: bool = flap_plan(rows, feet, player.velocity.y, vx, player.p, tile, 8, first, rise)
			if not player.flap_ready or tap_now:
				Input.action_press("jump")
			continue
		## 4 - Disparo: mantener pulsado si hay enemigo delante a tiro.
		if player.can_shoot and enemy_ahead(game, feet, tile, 6.0, player.facing):
			Input.action_press("shoot")
		else:
			Input.action_release("shoot")
		var dir: float = 1.0
		var boss_dx: float = boss_offset(game, feet, tile)
		if boss_dx != 0.0:
			dir = signf(boss_dx)
		if hold > 0:
			hold -= 1
			if hold == 0:
				Input.action_release("jump")
			_move(dir)
			continue
		if not player.is_on_floor():
			_move(dir)
			continue
		var row: int = int(floor((feet.y - 2.0) / tile))
		## 3 - Encima de una plataforma movil: quieto hasta que llegue al otro lado.
		var plat: MovingPlatform = platform_under(game, feet)
		if plat != null:
			var far_x: float = far_ledge(rows, int(floor(plat.right() / tile)), row, tile)
			_move(1.0 if plat.right() >= far_x - 30.0 else 0.0)
			continue
		## 7 - Runner: a mas velocidad hay que ver los pinchos y muros antes.
		var look: float = half_w + 10.0 + (absf(player.velocity.x) * 0.12 if player.auto_run else 0.0)
		var front: int = int(floor((feet.x + dir * look) / tile))
		var under_front: int = int(floor((feet.x + dir * (half_w + 2.0)) / tile))
		var wall: bool = LevelAnalyzer.is_solid(rows, front, row) or LevelAnalyzer.is_solid(rows, front, row - 1)
		var gap: bool = not LevelAnalyzer.is_solid(rows, under_front, row + 1) and not step_down(rows, under_front, row)
		var spike: bool = cell(rows, front, row) == "^"
		## 3 - Hueco con plataforma movil: esperar a que este pegada al borde y subir andando.
		if gap and dir > 0.0:
			var bridge: MovingPlatform = platform_in_gap(game, feet, tile)
			if bridge != null:
				_move(1.0 if bridge.left() <= feet.x + half_w + 18.0 else 0.0)
				continue
		var boss_close: bool = boss_dx != 0.0 and absf(boss_dx) < tile * 2.6
		if wall or gap or spike or enemy_ahead(game, feet, tile, 2.3, dir) or boss_close:
			Input.action_press("jump")
			hold = 22
		_move(dir)
	release_all()
	return false


## 8 - Centro (en px) del hueco de la primera tuberia por delante; si no hay, el ultimo objetivo.
static func flap_target(rows: Array[String], x: float, tile: float, fallback: float) -> float:
	var h: int = rows.size()
	var cx: int = int(floor(x / tile))
	for col: int in range(cx, mini(cx + 7, rows[0].length() - 1)):
		var pipe: bool = false
		for y: int in range(1, h - 2):
			if LevelAnalyzer.is_solid(rows, col, y):
				pipe = true
				break
		if not pipe:
			continue
		var best_top: int = -1
		var best_len: int = 0
		var cur: int = 0
		var cur_top: int = 0
		for y: int in h:
			if LevelAnalyzer.is_solid(rows, col, y):
				cur = 0
				continue
			if cur == 0:
				cur_top = y
			cur += 1
			if cur > best_len:
				best_len = cur
				best_top = cur_top
		return (float(best_top) + float(best_len) * 0.5) * tile
	return fallback


## 8 - Planificador del volador: tramos de 6 frames, en cada uno toca o no. Devuelve si tocar ya.
static func flap_plan(rows: Array[String], feet: Vector2, vy: float, vx: float, p: Dictionary, tile: float,
		depth: int, first: int, rise: float) -> bool:
	for a: int in [first, 1 - first]:
		if _flap_survives(rows, feet, vy, vx, p, tile, depth, a, rise):
			return a == 1
	return first == 1


static func _flap_survives(rows: Array[String], feet: Vector2, vy: float, vx: float, p: Dictionary, tile: float,
		depth: int, tap: int, rise: float) -> bool:
	var dt: float = 1.0 / 60.0
	var pos: Vector2 = feet
	var v: float = -float(p["flap_impulse"]) if tap == 1 else vy
	var hw: float = float(p["width"]) * 0.42
	var hh: float = float(p["height"]) * 0.92
	for i: int in 6:
		v = minf(v + float(p["flap_gravity"]) * dt, float(p["flap_max_fall"]))
		pos += Vector2(vx, v) * dt
		pos.y = maxf(pos.y, tile * 1.2)
		for corner: Vector2 in [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(-hw, -1.0), Vector2(hw, -1.0), Vector2(hw, -hh * 0.5)]:
			var c: Vector2 = pos + corner
			if LevelAnalyzer.is_solid(rows, int(floor(c.x / tile)), int(floor(c.y / tile))):
				return false
	if depth <= 1:
		return true
	var target: float = flap_target(rows, pos.x - hw, tile, pos.y)
	var nxt: int = 1 if pos.y - float(p["height"]) * 0.5 > target + rise * 0.5 and v > -60.0 else 0
	for a: int in [nxt, 1 - nxt]:
		if _flap_survives(rows, pos, v, vx, p, tile, depth - 1, a, rise):
			return true
	return false


static func _move(dir: float) -> void:
	if dir > 0.0:
		Input.action_release("move_left")
		Input.action_press("move_right")
	elif dir < 0.0:
		Input.action_release("move_right")
		Input.action_press("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")


static func release_all() -> void:
	for action: String in ["move_left", "move_right", "jump", "shoot"]:
		Input.action_release(action)


## El bot salta a un enemigo que tiene delante a su altura (sobre los pisables cae encima).
static func enemy_ahead(game: Node, feet: Vector2, tile: float, reach: float = 2.3, dir: float = 1.0) -> bool:
	for v: Variant in game.get("enemies"):
		if not is_instance_valid(v):
			continue
		var e: Enemy = v as Enemy
		if not e.alive or e.kind == "boss":
			continue
		var r: Rect2 = e.hitbox()
		var dx: float = (r.position.x - feet.x) if dir > 0.0 else (feet.x - r.end.x)
		if dx > -tile * 0.2 and dx < tile * reach and r.end.y > feet.y - tile * 1.6 and r.position.y < feet.y:
			return true
	return false


## 5 - Distancia horizontal al jefe si esta vivo y cerca (0 si no hay pelea).
static func boss_offset(game: Node, feet: Vector2, tile: float) -> float:
	var b: Variant = game.get("boss")
	if b == null or not is_instance_valid(b):
		return 0.0
	var e: Enemy = b as Enemy
	if not e.alive:
		return 0.0
	var dx: float = e.global_position.x - feet.x
	if absf(dx) > tile * 10.0:
		return 0.0
	## Aturdido no hace dano: mejor pasar de largo hacia la derecha.
	if not e.harmful():
		return 0.0
	return dx if absf(dx) > 4.0 else 1.0


static func platform_under(game: Node, feet: Vector2) -> MovingPlatform:
	for v: Variant in game.get("platforms"):
		var mp: MovingPlatform = v as MovingPlatform
		if absf(feet.y - mp.top()) < 8.0 and feet.x >= mp.left() - 6.0 and feet.x <= mp.right() + 6.0:
			return mp
	return null


static func platform_in_gap(game: Node, feet: Vector2, tile: float) -> MovingPlatform:
	for v: Variant in game.get("platforms"):
		var mp: MovingPlatform = v as MovingPlatform
		if absf(mp.top() - feet.y) < tile * 0.6 and mp.origin.x > feet.x and mp.origin.x < feet.x + tile * 8.0:
			return mp
	return null


static func far_ledge(rows: Array[String], from_x: int, row: int, tile: float) -> float:
	for cx: int in range(from_x, mini(from_x + 10, rows[0].length())):
		if LevelAnalyzer.is_solid(rows, cx, row + 1):
			return float(cx) * tile
	return 1.0e9


## Una bajada se baja andando (saltar ahi es peor), pero solo si hay suelo firme y sin pinchos
## en las 3 columnas donde caeras con la inercia.
static func step_down(rows: Array[String], x: int, row: int) -> bool:
	for cx: int in range(x, x + 3):
		var found: bool = false
		for dy: int in range(2, 6):
			if LevelAnalyzer.is_solid(rows, cx, row + dy):
				if cell(rows, cx, row + dy - 1) == LevelBuilder.SPIKE:
					return false
				found = true
				break
		if not found:
			return false
	return true


static func cell(rows: Array[String], x: int, y: int) -> String:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[0].length():
		return ""
	return rows[y][x]

extends RefCounted
## Bot del rompebloques. Cada 2 fotogramas:
## 1 - Predice donde caera la pelota que antes llegue a la pala (rebotes en paredes y techo).
## 2 - Elige con que parte de la pala golpearla para mandarla hacia la columna con mas
##     ladrillos (como hace una persona que apunta con el borde).
## 3 - Si ninguna pelota baja pronto, va a por monedas y mejoras que caen.
## Si gana con la fisica real, el nivel es jugable.


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 3:
			return false
		if f % 2 == 0:
			game.set("bot_x", target_x(game))
	return false


## Donde cruza la pelota la linea de la pala (o INF si no llega) y en cuanto tiempo.
static func landing(game: Node, p: Vector2, v: Vector2) -> Vector3:
	var consts: Dictionary = (game.get_script() as Script).get_script_constant_map()
	var w: float = consts["W"]
	var r: float = consts["BALL_R"]
	var line: float = float(consts["PADDLE_Y"]) - float(consts["PADDLE_H"]) * 0.5 - r
	var t: float = 0.0
	for i: int in 400:
		if v.y > 0.0 and p.y >= line:
			return Vector3(p.x, t, 1.0)
		var dt: float = 1.0 / 120.0
		p += v * dt
		t += dt
		if p.x < r:
			p.x = r
			v.x = absf(v.x)
		elif p.x > w - r:
			p.x = w - r
			v.x = -absf(v.x)
		if p.y < 150.0 + r:
			p.y = 150.0 + r
			v.y = absf(v.y)
	return Vector3(INF, INF, 0.0)


static func target_x(game: Node) -> float:
	var consts: Dictionary = (game.get_script() as Script).get_script_constant_map()
	var w: float = consts["W"]
	var px: float = game.get("paddle_x")
	var pw: float = game.get("paddle_w")
	var best_land: Vector3 = Vector3(INF, INF, 0.0)
	## best_land = (x donde cae, segundos hasta caer, y de la linea de la pala)
	for b: Dictionary in game.get("balls"):
		var v: Vector2 = b["vel"]
		if v == Vector2.ZERO:
			continue
		var l: Vector3 = landing(game, b["pos"], v)
		if l.y < best_land.y:
			best_land = l
	## 3 - Nada baja pronto: a por lo que cae.
	if best_land.y > 0.9 or best_land.x == INF:
		var best_d: float = INF
		var go: float = INF
		for d: Dictionary in game.get("drops"):
			var dp: Vector2 = d["pos"]
			if dp.y > 700.0 and absf(dp.x - px) < best_d:
				best_d = absf(dp.x - px)
				go = dp.x
		if go != INF:
			return go
		if best_land.x == INF:
			return px
	## 2 - Apuntar: simular el tiro con cada parte de la pala (paredes, acero y ladrillos de
	##     verdad) y quedarse con el que rompe un ladrillo antes.
	var speed: float = 0.0
	for b: Dictionary in game.get("balls"):
		speed = maxf(speed, (b["vel"] as Vector2).length())
	var best_off: float = 0.0
	var best_score: float = -INF
	for k: int in range(-8, 9):
		var off: float = float(k) / 10.0
		var t: float = first_break(game, Vector2(best_land.x, best_land.z), off, maxf(speed, 500.0))
		## Si ningun tiro rompe nada pronto, cambia de angulo en cada golpe (explora).
		var score: float = -t - absf(off) * 0.05 + (0.01 * float((k + int(game.get("broken")) * 7 + int(game.get("time_in_level"))) % 17) if t >= 3.0 else 0.0)
		if score > best_score:
			best_score = score
			best_off = off
	return clampf(best_land.x - best_off * pw * 0.5, pw * 0.5, w - pw * 0.5)


## Segundos hasta romper un ladrillo si la pala golpea con 'off' (-1 borde izq, 1 borde der).
static func first_break(game: Node, at: Vector2, off: float, speed: float) -> float:
	var consts: Dictionary = (game.get_script() as Script).get_script_constant_map()
	var w: float = consts["W"]
	var r: float = consts["BALL_R"]
	var a: float = off * 1.05
	var v: Vector2 = Vector2(sin(a), -cos(a)) * speed
	var p: Vector2 = Vector2(at.x, float(consts["PADDLE_Y"]) - float(consts["PADDLE_H"]) * 0.5 - r)
	var bricks: Array = game.get("bricks")
	var t: float = 0.0
	var dt: float = 1.0 / 90.0
	while t < 5.0:
		p += v * dt
		t += dt
		if p.x < r or p.x > w - r:
			v.x = -v.x
		if p.y < 150.0 + r:
			v.y = absf(v.y)
		if v.y > 0.0 and p.y > float(consts["PADDLE_Y"]) - 40.0:
			return 3.0 + t
		for br: Dictionary in bricks:
			var rc: Rect2 = br["rect"]
			var q: Vector2 = Vector2(clampf(p.x, rc.position.x, rc.end.x), clampf(p.y, rc.position.y, rc.end.y))
			if q.distance_to(p) > r:
				continue
			if br["kind"] != "#":
				return t
			## Acero: rebota y sigue.
			if absf(p.x - rc.get_center().x) / rc.size.x > absf(p.y - rc.get_center().y) / rc.size.y:
				v.x = -v.x
			else:
				v.y = -v.y
			break
	return 4.0

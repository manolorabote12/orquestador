class_name HordeBot
extends RefCounted
## Bot de las hordas: esquiva, rodea y recoge gemas. Si sobrevive al tiempo del nivel (y al
## jefe) con las armas automaticas, el nivel es superable por una persona normal.
## 1 - Huye de la suma de amenazas cercanas (el jefe pesa el triple) y gira alrededor de ellas.
## 2 - Va a por la gema mas cercana cuando no hay mucho peligro.
## 3 - Se mantiene lejos de los bordes y rodea las rocas.
## 4 - Al subir de nivel elige por prioridad (armas de area y vida primero).
## 5 - Acabado el tiempo, se acerca al jefe lo justo para que las armas le alcancen.


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_pick", true)
	var seconds: float = float(game.get("seconds"))
	var frames: int = maxi(max_frames, int((seconds + 90.0) * 60.0))
	for f: int in frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			game.set("bot_dir", Vector2.ZERO)
			return true
		game.set("bot_dir", decide(game))
	game.set("bot_dir", Vector2.ZERO)
	return false


static func decide(game: Node) -> Vector2:
	var player: Node2D = game.get("player")
	var pos: Vector2 = player.position
	var arena: Vector2 = game.get("arena")
	var threat: Vector2 = Vector2.ZERO
	for v: Variant in game.get("enemies"):
		var e: HordeEnemy = v as HordeEnemy
		if e == null or not e.alive:
			continue
		var d: Vector2 = pos - e.position
		var dist: float = d.length()
		var reach: float = 380.0 + e.radius
		if dist < reach and dist > 0.01:
			var w: float = pow(1.0 - dist / reach, 2.0) * (3.0 if e.kind == "boss" else 1.0) * float(e.damage)
			threat += d / dist * w
	var dir: Vector2 = threat * 2.2
	## 1 - Componente tangencial: rodear en vez de huir en linea recta hacia una pared.
	dir += threat.orthogonal() * 0.9
	var danger: float = threat.length()
	var best: Vector2 = Vector2.ZERO
	var best_d: float = 520.0
	for g: Dictionary in game.call("gems"):
		var node: Node2D = g["node"]
		var dd: float = node.position.distance_to(pos)
		if dd < best_d:
			best_d = dd
			best = node.position
	if best != Vector2.ZERO:
		dir += (best - pos).normalized() * 0.8 / (1.0 + danger * 3.0)
	## 5 - Sin tiempo y con el jefe vivo: acercarse hasta tenerlo a tiro (sin pegarse).
	var b: Variant = game.get("boss")
	if float(game.get("time_left")) <= 0.0 and b != null and is_instance_valid(b) and (b as HordeEnemy).alive:
		var to_boss: Vector2 = (b as HordeEnemy).position - pos
		if to_boss.length() > 480.0:
			dir += to_boss.normalized() * 1.2
	var center: Vector2 = arena * 0.5
	var off: Vector2 = (pos - center) / (arena * 0.5)
	dir += (center - pos).normalized() * pow(maxf(absf(off.x), absf(off.y)), 3.0) * 1.6
	if dir.length() < 0.05:
		dir = (center - pos).normalized() * 0.3
	dir = dir.normalized()
	## 3 - Rocas: prueba girando hasta encontrar paso.
	for a: float in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8, PI]:
		var t: Vector2 = dir.rotated(a)
		if not bool(game.call("solid_at", pos + t * 54.0, 22.0)):
			return t
	return dir

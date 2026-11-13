extends RefCounted
## Bot de la arena: juega como una persona normal.
## 1 - Va a por el rival mas cercano, se queda a media distancia y se mueve de lado.
## 2 - Dispara con el boton de ataque (que apunta solo) como mucho 4 veces por segundo.
## 3 - Usa el super cuando lo tiene y el rival esta cerca.
## 4 - Con poca vida se aleja hasta curarse; huye del gas; recoge cubos y abre cajas si no hay nadie.
## 5 - En los modos de equipo (supervivencia, balon, torretas) deja que el juego le mueva con la
##     misma IA que sus companeros (piloto automatico), que sabe jugar a cada modo.

const TAP_GAP: float = 0.25


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	if str(game.get("mode")) != "showdown":
		game.set("autopilot", true)
		for f: int in max_frames:
			await tree.physics_frame
			if not is_instance_valid(game):
				return false
			if bool(game.get("finished")):
				return true
			if int(game.get("deaths")) >= 2:
				return false
		return false
	var tap: float = 0.0
	var think: float = 0.0
	var flip: float = 1.2
	var side: float = 1.0
	var retreat: bool = false
	var goal: Vector2 = Vector2.ZERO
	var dt: float = 1.0 / 60.0
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			game.set("move_input", Vector2.ZERO)
			return true
		if int(game.get("deaths")) >= 2:
			game.set("move_input", Vector2.ZERO)
			return false
		var me: BrawlFighter = game.get("player")
		if me == null or not me.alive or bool(game.get("failed")):
			continue
		tap -= dt
		think -= dt
		flip -= dt
		if flip <= 0.0:
			flip = 1.2
			side = -side
		var target: BrawlFighter = _nearest_rival(game, me)
		## Se retira a curarse si va perdiendo el duelo (o esta muy tocado).
		if me.hp < me.max_hp * 0.3 or (target != null and me.hp < me.max_hp * 0.5 and target.hp > me.hp * 1.2):
			retreat = true
		elif me.hp > me.max_hp * 0.85:
			retreat = false
		if think <= 0.0 or goal == Vector2.ZERO:
			think = 0.2
			goal = _goal(game, me, target, retreat, side)
		var step: Vector2 = game.call("next_step", me.position, goal)
		var to: Vector2 = step - me.position
		game.set("move_input", to.normalized() if to.length() > 10.0 else Vector2(0.001, 0.0))
		## Disparo y super.
		var aim: BrawlFighter = game.get("aim_target")
		if aim != null and aim.alive:
			var d: float = me.position.distance_to(aim.position)
			if me.super_charge >= 1.0 and d < 360.0:
				game.call("use_super")
			elif tap <= 0.0 and me.ammo >= 1.0 and d < 520.0:
				game.call("attack")
				tap = TAP_GAP
		elif tap <= 0.0 and me.ammo >= 2.0 and (target == null or me.position.distance_to(target.position) > 520.0):
			var bc: Vector2i = game.call("box_in_range", me)
			if bc.x >= 0:
				game.call("attack")
				tap = TAP_GAP
	return false


static func _nearest_rival(game: Node, me: BrawlFighter) -> BrawlFighter:
	var best: BrawlFighter = null
	var best_d: float = 1e9
	for o: BrawlFighter in game.get("fighters"):
		if o == me or not o.alive or not bool(game.call("foes", me, o)):
			continue
		var d: float = o.position.distance_to(me.position)
		if d < best_d:
			best_d = d
			best = o
	return best


static func _goal(game: Node, me: BrawlFighter, target: BrawlFighter, retreat: bool, side: float) -> Vector2:
	var tile: float = 96.0
	var center: Vector2 = game.get("gas_center")
	var t: float = float(game.get("time_in_level"))
	if t >= float(game.get("gas_start")) - 3.0 and me.position.distance_to(center) > float(game.get("gas_radius")) - tile * 2.0:
		return center
	if retreat and target != null and target.position.distance_to(me.position) < 650.0:
		var away: Vector2 = me.position + (me.position - target.position).normalized() * 300.0
		if not bool(game.call("free_at", away, 30.0)):
			away = me.position + (me.position - target.position).normalized().rotated(side * 1.2) * 240.0
		## Nunca hacia el gas.
		if away.distance_to(center) > float(game.get("gas_radius")) - tile:
			away = center
		return away
	## Cubos cerca y nadie encima.
	var cubes: Array = game.get("cubes")
	var td: float = target.position.distance_to(me.position) if target != null else 1e9
	for c: Dictionary in cubes:
		var p: Vector2 = c["pos"]
		if p.distance_to(me.position) < 420.0 and td > 480.0:
			return p
	## Al principio, como una persona: abre cajas para hacerse fuerte si nadie esta cerca.
	var boxes: Dictionary = game.get("boxes")
	if t < 14.0 and td > 520.0 and not boxes.is_empty():
		var best: Vector2 = Vector2.ZERO
		var best_d: float = 1e9
		for c: Vector2i in boxes.keys():
			var p: Vector2 = game.call("center_of", c)
			if p.distance_to(me.position) < best_d:
				best_d = p.distance_to(me.position)
				best = p
		return best + (me.position - best).normalized() * 260.0
	if target != null:
		var dir: Vector2 = (target.position - me.position).normalized()
		if td > 420.0 or not bool(game.call("line_clear", me.position, target.position, 0.0)):
			return target.position
		if td < 250.0:
			return me.position - dir * 160.0
		return me.position + dir.orthogonal() * 150.0 * side
	return center

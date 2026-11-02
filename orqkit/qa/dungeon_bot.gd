extends RefCounted
## Bot de las mazmorras: juega como una persona con dedo rapido.
## 1 - Con monstruos: esquiva las balas que vienen, se aleja de los que pegan cuerpo a cuerpo (y
##     del golpe avisado del golem) y si no hay peligro se queda quieto para disparar.
## 2 - Sala limpia: abre el cofre si lo hay, limpia el resto de salas (experiencia y cofres) y luego el jefe.
## 3 - Habilidades: flecha doble, cadencia, dano, diagonales, robo de vida, vida... en ese orden.

const MapRules = preload("res://kit/dungeon/dungeon_map.gd")
const PRIORITY: Array[String] = ["multi", "cadencia", "dano", "diagonal", "robo", "vida", "rebote", "escudo", "rapido"]


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")) and not bool(game.get("failed")):
			return true
		if not bool(game.call("can_act")):
			continue
		step(game)
	return false


static func step(g: Node) -> void:
	var choices: Array = g.get("choices")
	if not choices.is_empty():
		var best: int = 0
		var bp: int = 99
		for i: int in choices.size():
			var p: int = PRIORITY.find(str(choices[i]))
			if p < bp:
				bp = p
				best = i
		g.call("choose_skill", best)
		return
	var hero: Dictionary = g.get("hero")
	var hp: Vector2 = hero["pos"]
	var room: Vector2 = Vector2(MapRules.ROOM_W, MapRules.ROOM_H) * MapRules.TILE
	var center: Vector2 = room * 0.5
	if not bool(g.call("room_clear")):
		## Amenazas: monstruos cerca (cuanto alcanzan) y balas que vienen.
		var threats: Array = []
		for e: Dictionary in g.get("enemies"):
			if not e["alive"]:
				continue
			var kind: String = str(e["kind"])
			var reach: float = 0.0
			match kind:
				"slime":
					reach = 95.0
				"bat":
					## Los murcielagos se van solos: solo se esquivan con poca vida.
					reach = 70.0 if float(hero["hp"]) < float(g.call("max_hp")) * 0.4 else 0.0
				"golem":
					reach = 190.0 if float(e["tele"]) > 0.0 else 100.0
				"boss":
					reach = 240.0 if float(e["dash_t"]) > 0.0 else 150.0
			if reach > 0.0:
				threats.append([e["pos"], reach])
		for bl: Dictionary in g.get("bullets"):
			var to: Vector2 = hp - (bl["pos"] as Vector2)
			if to.length() < 200.0 and (bl["vel"] as Vector2).dot(to) > 0.0:
				## La bala se trata como una amenaza un poco por delante de donde esta.
				threats.append([(bl["pos"] as Vector2) + (bl["vel"] as Vector2).normalized() * minf(to.length(), 60.0), 70.0])
		var danger: bool = false
		for th: Array in threats:
			if hp.distance_to(th[0]) < float(th[1]):
				danger = true
		if danger:
			## Prueba 16 direcciones y se queda con la que mas aleja de todo sin chocar.
			var best: Vector2 = Vector2.ZERO
			var bs: float = -INF
			for k: int in 16:
				var d: Vector2 = Vector2.RIGHT.rotated(TAU * float(k) / 16.0)
				var p2: Vector2 = hp + d * 70.0
				if bool(g.call("_hits", hp + d * 30.0, 22.0, false)):
					continue
				var sc: float = 0.0
				for th: Array in threats:
					sc += minf(p2.distance_to(th[0]) - float(th[1]), 0.0) * 3.0 + p2.distance_to(th[0]) * 0.2
				sc -= p2.distance_to(center) * 0.15
				if bool(g.call("_hits", p2, 22.0, false)):
					sc -= 120.0
				if sc > bs:
					bs = sc
					best = d
			g.set("move_dir", best)
			return
		## Si el monstruo mas cercano esta detras de una columna, se busca un hueco para verle.
		var tgt: Dictionary = g.call("_target")
		if not tgt.is_empty() and not bool(g.call("line_clear", hp, tgt["pos"])):
			g.set("move_dir", g.call("path_to_tile", Vector2i((tgt["pos"] as Vector2) / MapRules.TILE)))
			return
		g.set("move_dir", Vector2.ZERO)
		return
	## Sala limpia: cofre, tesoros cercanos y luego el jefe.
	var cell: Vector2i = g.get("cell")
	var chests: Dictionary = g.get("chests")
	if chests.has(cell) and not bool(chests[cell]):
		var cp: Vector2 = g.call("chest_pos")
		g.set("move_dir", (cp - hp).normalized() if not _blocked(g, hp, cp) else g.call("path_to_tile", Vector2i(cp / MapRules.TILE)))
		return
	## Se explora todo antes del jefe (experiencia y cofres): la sala sin limpiar mas cercana.
	var rooms: Dictionary = g.get("rooms")
	var boss: Vector2i = g.get("boss_cell")
	var cleared: Dictionary = g.get("cleared")
	var target: Vector2i = boss
	var dist: Dictionary = MapRules.room_dist(rooms, cell)
	var best_d: int = 999
	for c: Variant in rooms:
		var v: Vector2i = c
		if v == boss:
			continue
		var todo: bool = not cleared.has(v) or (chests.has(v) and not bool(chests[v])) or (str(rooms[v]) == "T" and not chests.has(v))
		if todo and int(dist.get(v, 999)) < best_d:
			best_d = int(dist.get(v, 999))
			target = v
	var nxt: Vector2i = MapRules.next_room(rooms, cell, target)
	if nxt == cell:
		g.set("move_dir", Vector2.ZERO)
		return
	var side: int = MapRules.DIRS.find(nxt - cell)
	var door: Vector2i = MapRules.door_tile(side)
	var dp: Vector2 = (Vector2(door) + Vector2(0.5, 0.5)) * MapRules.TILE
	if hp.distance_to(dp) < MapRules.TILE * 1.2:
		## Pegado a la puerta: apunta mas alla de su centro para entrar recto por el hueco.
		g.set("move_dir", (dp + Vector2(MapRules.DIRS[side]) * MapRules.TILE - hp).normalized())
	else:
		g.set("move_dir", g.call("path_to_tile", door))


static func _blocked(g: Node, a: Vector2, b: Vector2) -> bool:
	return not bool(g.call("line_clear", a, b))

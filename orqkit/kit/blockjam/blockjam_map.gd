extends RefCounted
## Bloques de colores (tipo Color Block Jam): bloques de colores en un tablero; arrastra cada uno
## por los huecos hasta una puerta de su color en el borde. Sale si cabe por ella (su ancho no pasa
## del de la puerta). Se gana vaciando el tablero; con "moves" > 0 hay pasos contados.
## Nivel: "w", "h", "walls" ([[x, y]]), "colors" (["#hex"]), "blocks" ([{"c": color, "x", "y",
## "cells": [[dx, dy], ...]}]), "doors" ([{"side": "t"|"b"|"l"|"r", "at": primera casilla, "len",
## "c": color}]) y "moves". Sacar un bloque solo deja mas hueco, asi que si se puede sacar uno
## cualquiera que tenga camino y repetir, el tablero tiene solucion (el analizador hace eso).

const Rules = preload("res://kit/rules.gd")
const DIRS: Dictionary = {"u": Vector2i(0, -1), "d": Vector2i(0, 1), "l": Vector2i(-1, 0), "r": Vector2i(1, 0)}
const EXIT_DIR: Dictionary = {"t": "u", "b": "d", "l": "l", "r": "r"}


static func new_state(level: Dictionary) -> Dictionary:
	var blocks: Array = []
	for b: Variant in level.get("blocks", []):
		var cells: Array = []
		for c: Variant in (b as Dictionary).get("cells", [[0, 0]]):
			cells.append(Vector2i(int(c[0]), int(c[1])))
		blocks.append({"c": int(b.get("c", 0)), "p": Vector2i(int(b.get("x", 0)), int(b.get("y", 0))), "cells": cells, "out": false})
	var walls: Dictionary = {}
	for w: Variant in level.get("walls", []):
		walls[Vector2i(int(w[0]), int(w[1]))] = true
	var st: Dictionary = {"w": clampi(int(level.get("w", 6)), 3, 12), "h": clampi(int(level.get("h", 8)), 3, 14), "walls": walls,
		"blocks": blocks, "doors": level.get("doors", []), "moves": 0, "max_moves": maxi(0, int(level.get("moves", 0))),
		"left": blocks.size(), "won": blocks.is_empty(), "lost": false, "rng": RandomNumberGenerator.new()}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func cells_at(b: Dictionary, p: Vector2i) -> Array:
	var out: Array = []
	for c: Variant in b["cells"]:
		out.append(p + (c as Vector2i))
	return out


## Casillas ocupadas por los bloques (sin el bloque skip): {Vector2i: indice}.
static func occupancy(st: Dictionary, skip: int = -1) -> Dictionary:
	var occ: Dictionary = {}
	for i: int in (st["blocks"] as Array).size():
		var b: Dictionary = st["blocks"][i]
		if i == skip or bool(b["out"]):
			continue
		for c: Variant in cells_at(b, b["p"]):
			occ[c] = i
	return occ


static func _free(st: Dictionary, cells: Array, occ: Dictionary) -> bool:
	for c: Variant in cells:
		var v: Vector2i = c
		if v.x < 0 or v.y < 0 or v.x >= int(st["w"]) or v.y >= int(st["h"]) or (st["walls"] as Dictionary).has(v) or occ.has(v):
			return false
	return true


## Puerta por la que el bloque i, en p, sale moviendose hacia dir ({} si no hay).
static func exit_door(st: Dictionary, i: int, p: Vector2i, dir: String) -> Dictionary:
	var b: Dictionary = st["blocks"][i]
	var cells: Array = cells_at(b, p)
	for d: Variant in st["doors"]:
		var door: Dictionary = d
		if EXIT_DIR.get(str(door.get("side", "")), "") != dir or int(door.get("c", -1)) != int(b["c"]):
			continue
		var a0: int = int(door.get("at", 0))
		var a1: int = a0 + int(door.get("len", 1))
		var ok: bool = true
		var touches: bool = false
		for c: Variant in cells:
			var v: Vector2i = c
			var along: int = v.x if dir == "u" or dir == "d" else v.y
			if along < a0 or along >= a1:
				ok = false
				break
			match dir:
				"u":
					touches = touches or v.y == 0
				"d":
					touches = touches or v.y == int(st["h"]) - 1
				"l":
					touches = touches or v.x == 0
				"r":
					touches = touches or v.x == int(st["w"]) - 1
		if ok and touches:
			return door
	return {}


## Mueve el bloque i una casilla hacia dir. Devuelve "move", "out" (sale por su puerta) o "" (no puede).
static func step(st: Dictionary, i: int, dir: String) -> String:
	if bool(st["won"]) or bool(st["lost"]) or i < 0 or i >= (st["blocks"] as Array).size() or not DIRS.has(dir):
		return ""
	var b: Dictionary = st["blocks"][i]
	if bool(b["out"]):
		return ""
	if not exit_door(st, i, b["p"], dir).is_empty():
		b["out"] = true
		st["left"] = int(st["left"]) - 1
		st["moves"] = int(st["moves"]) + 1
		Rules.hook(st, "on_exit", [i])
		if int(st["left"]) <= 0:
			st["won"] = true
		return "out"
	var np: Vector2i = (b["p"] as Vector2i) + DIRS[dir]
	if not _free(st, cells_at(b, np), occupancy(st, i)):
		return ""
	b["p"] = np
	st["moves"] = int(st["moves"]) + 1
	Rules.hook(st, "on_move", [i, dir])
	if int(st["max_moves"]) > 0 and int(st["moves"]) >= int(st["max_moves"]) and not bool(st["won"]):
		st["lost"] = true
	return "move"


## Camino mas corto del bloque i hasta salir: lista de direcciones (la ultima, la de salida). [] si no hay.
static func path_out(st: Dictionary, i: int) -> Array:
	var b: Dictionary = st["blocks"][i]
	if bool(b["out"]):
		return []
	var occ: Dictionary = occupancy(st, i)
	var start: Vector2i = b["p"]
	var prev: Dictionary = {start: null}
	var queue: Array = [start]
	var head: int = 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for dname: String in ["u", "d", "l", "r"]:
			if not exit_door(st, i, p, dname).is_empty():
				var out: Array = [dname]
				var cur: Vector2i = p
				while prev[cur] != null:
					var pr: Array = prev[cur]
					out.push_front(str(pr[1]))
					cur = pr[0]
				return out
			var np: Vector2i = p + DIRS[dname]
			if prev.has(np) or not _free(st, cells_at(b, np), occ):
				continue
			prev[np] = [p, dname]
			queue.append(np)
	return []


## Bot: el primer bloque con camino a su puerta, y su primer paso. [] si ninguno.
static func bot_move(st: Dictionary) -> Array:
	## Sigue con el bloque que ya estaba sacando (asi cuenta los mismos pasos que la fabrica).
	var cur: int = int(st.get("bot_block", -1))
	if cur >= 0 and cur < (st["blocks"] as Array).size() and not bool(st["blocks"][cur]["out"]):
		var p0: Array = path_out(st, cur)
		if not p0.is_empty():
			return [cur, str(p0[0])]
	for i: int in (st["blocks"] as Array).size():
		var pth: Array = path_out(st, i)
		if not pth.is_empty():
			st["bot_block"] = i
			return [i, str(pth[0])]
	return []


## Pasos minimos de una solucion por orden (el del bot): cota para el limite de pasos.
static func solve_steps(level: Dictionary) -> int:
	var st: Dictionary = new_state(level)
	st["max_moves"] = 0
	var guard: int = 0
	while not bool(st["won"]) and guard < 4000:
		guard += 1
		var m: Array = bot_move(st)
		if m.is_empty():
			return -1
		step(st, int(m[0]), str(m[1]))
	return int(st["moves"]) if bool(st["won"]) else -1


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	var seen: Dictionary = {}
	for i: int in (st["blocks"] as Array).size():
		var b: Dictionary = st["blocks"][i]
		for c: Variant in cells_at(b, b["p"]):
			var v: Vector2i = c
			if v.x < 0 or v.y < 0 or v.x >= int(st["w"]) or v.y >= int(st["h"]) or (st["walls"] as Dictionary).has(v) or seen.has(v):
				issues.append("jam_overlap")
			seen[v] = true
	var n: int = (st["blocks"] as Array).size()
	if n < 3:
		issues.append("jam_few")
	var colors_needed: Dictionary = {}
	for b2: Variant in st["blocks"]:
		colors_needed[int(b2["c"])] = true
	for c2: Variant in colors_needed:
		var has: bool = false
		for d: Variant in st["doors"]:
			has = has or int(d.get("c", -1)) == int(c2)
		if not has:
			issues.append("jam_no_door")
	var need: int = -1
	if issues.is_empty():
		need = solve_steps(level)
		if need < 0:
			issues.append("jam_stuck")
		elif int(level.get("moves", 0)) > 0 and int(level.get("moves", 0)) < need:
			issues.append("jam_moves_tight")
		else:
			var free0: int = 0
			for i2: int in n:
				var stt: Dictionary = new_state(level)
				free0 += 1 if not path_out(stt, i2).is_empty() else 0
			if free0 == n and n > 4:
				issues.append("jam_too_easy")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": n, "enemies": 0, "enemy_problems": [], "steps": need}

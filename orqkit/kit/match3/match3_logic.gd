class_name Match3Logic
extends RefCounted
## Logica pura del puzle de combinar 3 (sin dibujo): la usan el juego, el bot y las pruebas.
## Mapa del tablero: "." casilla, "#" hueco (solo en los bordes de cada columna), "I" casilla con hielo.
## 1 - Cambiar dos piezas vecinas solo vale si forma una linea de 3 o mas (o si mueves una especial).
## 2 - Linea de 4: pieza RAYO que, al romperse, limpia su fila (si la linea era horizontal) o su columna.
## 3 - Linea de 5: BOMBA de color; cambiada con una pieza, borra todas las de ese color.
## 4 - Forma de L o T: pieza ONDA que explota en 3x3.
## 5 - Caen las piezas, entran nuevas por arriba y las cascadas multiplican los puntos (combo).
## 6 - El hielo se rompe al combinar encima. Si no quedan jugadas, el tablero se baraja.

const HOLE: int = -2
const EMPTY: int = -1
const NONE: int = 0
const ROW: int = 1
const COL: int = 2
const WRAP: int = 3
const BOMB: int = 4
const POINTS_TILE: int = 20
const POINTS_SPECIAL: int = 60

var w: int = 7
var h: int = 9
var colors: int = 5
var color: PackedInt32Array = PackedInt32Array()
var special: PackedInt32Array = PackedInt32Array()
var ice: PackedByteArray = PackedByteArray()
var score: int = 0
var ice_left: int = 0
var ice_total: int = 0
var specials_made: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(map: Array, n_colors: int, seed_value: int) -> void:
	var rows: Array[String] = LevelBuilder.normalize(map)
	h = rows.size()
	w = rows[0].length()
	colors = clampi(n_colors, 3, 6)
	rng.seed = seed_value
	color.resize(w * h)
	special.resize(w * h)
	ice.resize(w * h)
	ice_left = 0
	for y: int in h:
		for x: int in w:
			var i: int = y * w + x
			var ch: String = rows[y][x]
			color[i] = HOLE if ch == "#" else EMPTY
			special[i] = NONE
			ice[i] = 1 if ch == "I" else 0
			if ch == "I":
				ice_left += 1
	ice_total = ice_left
	score = 0
	fill_without_matches()


func idx(c: Vector2i) -> int:
	return c.y * w + c.x


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func playable(c: Vector2i) -> bool:
	return inside(c) and color[idx(c)] != HOLE


func at(c: Vector2i) -> int:
	return color[idx(c)] if inside(c) else HOLE


func fill_without_matches() -> void:
	for tries: int in 60:
		for y: int in h:
			for x: int in w:
				var c: Vector2i = Vector2i(x, y)
				if color[idx(c)] == HOLE:
					continue
				special[idx(c)] = NONE
				var options: Array[int] = []
				for k: int in colors:
					var left2: bool = at(c + Vector2i(-1, 0)) == k and at(c + Vector2i(-2, 0)) == k
					var up2: bool = at(c + Vector2i(0, -1)) == k and at(c + Vector2i(0, -2)) == k
					if not left2 and not up2:
						options.append(k)
				color[idx(c)] = options[rng.randi() % options.size()] if not options.is_empty() else rng.randi() % colors
		if has_move():
			return


# ------------------------------------------------------------------ jugadas

func adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func swap_ok(a: Vector2i, b: Vector2i) -> bool:
	if not adjacent(a, b) or not playable(a) or not playable(b):
		return false
	if color[idx(a)] < 0 or color[idx(b)] < 0:
		return false
	if special[idx(a)] != NONE or special[idx(b)] != NONE:
		return true
	_swap(a, b)
	var ok: bool = _line_at(a) or _line_at(b)
	_swap(a, b)
	return ok


func has_move() -> bool:
	return not all_moves().is_empty()


func all_moves() -> Array[Array]:
	var out: Array[Array] = []
	for y: int in h:
		for x: int in w:
			var a: Vector2i = Vector2i(x, y)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				if swap_ok(a, a + d):
					out.append([a, a + d])
	return out


func _swap(a: Vector2i, b: Vector2i) -> void:
	var ia: int = idx(a)
	var ib: int = idx(b)
	var c: int = color[ia]
	color[ia] = color[ib]
	color[ib] = c
	var s: int = special[ia]
	special[ia] = special[ib]
	special[ib] = s


func _line_at(c: Vector2i) -> bool:
	var k: int = at(c)
	if k < 0:
		return false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var n: int = 1
		var p: Vector2i = c + d
		while at(p) == k:
			n += 1
			p += d
		p = c - d
		while at(p) == k:
			n += 1
			p -= d
		if n >= 3:
			return true
	return false


## Hace el cambio y resuelve todo. Devuelve las fases para animar:
## {swap, cleared, created [{cell, kind, color}], moved [{from, to}], spawned [{cell, color, drop}], combo, points}
func apply_swap(a: Vector2i, b: Vector2i) -> Array[Dictionary]:
	var phases: Array[Dictionary] = []
	if not swap_ok(a, b):
		return phases
	var sa: int = special[idx(a)]
	var sb: int = special[idx(b)]
	_swap(a, b)
	var forced: Dictionary = {}
	## 3 - Bomba: borra todas las piezas del color con el que se cambia (dos bombas: todo).
	if sa == BOMB or sb == BOMB:
		var bomb_cell: Vector2i = b if sa == BOMB else a
		var other: Vector2i = a if sa == BOMB else b
		forced[bomb_cell] = true
		special[idx(bomb_cell)] = NONE
		var target: int = color[idx(other)]
		for y: int in h:
			for x: int in w:
				var c: Vector2i = Vector2i(x, y)
				if color[idx(c)] >= 0 and (color[idx(c)] == target or special[idx(other)] == BOMB):
					forced[c] = true
	elif not (_line_at(a) or _line_at(b)):
		## Especial movida sin linea: se dispara donde queda.
		if sa != NONE:
			forced[b] = true
		if sb != NONE:
			forced[a] = true
	return _resolve([a, b], forced)


func _resolve(pivots: Array[Vector2i], forced: Dictionary) -> Array[Dictionary]:
	var phases: Array[Dictionary] = []
	var combo: int = 1
	var first: bool = true
	while true:
		var runs: Array[Dictionary] = _runs()
		if runs.is_empty() and forced.is_empty():
			break
		var clear: Dictionary = forced.duplicate()
		forced = {}
		var created: Array[Dictionary] = []
		var in_h: Dictionary = {}
		var in_v: Dictionary = {}
		for r: Dictionary in runs:
			for c: Vector2i in r["cells"]:
				clear[c] = true
				if bool(r["horizontal"]):
					in_h[c] = true
				else:
					in_v[c] = true
		## 2/3/4 - Especiales nuevas: BOMBA con 5, ONDA con L/T, RAYO con 4.
		var used: Dictionary = {}
		for r: Dictionary in runs:
			var cells: Array = r["cells"]
			var pivot: Vector2i = _pivot(cells, pivots if first else [])
			var kind: int = NONE
			if cells.size() >= 5:
				kind = BOMB
			else:
				for c: Vector2i in cells:
					if in_h.has(c) and in_v.has(c):
						kind = WRAP
						pivot = c
						break
				if kind == NONE and cells.size() == 4:
					kind = ROW if bool(r["horizontal"]) else COL
			if kind != NONE and not used.has(pivot):
				used[pivot] = true
				created.append({"cell": pivot, "kind": kind, "color": color[idx(pivot)]})
		## 7 - Las especiales que se rompen disparan su efecto (en cadena).
		var queue: Array = clear.keys()
		while not queue.is_empty():
			var c: Vector2i = queue.pop_back()
			var s: int = special[idx(c)]
			if s == NONE or used.has(c):
				continue
			special[idx(c)] = NONE
			for e: Vector2i in _effect(c, s):
				if playable(e) and color[idx(e)] >= 0 and not clear.has(e):
					clear[e] = true
					queue.append(e)
		var cleared: Array[Vector2i] = []
		for c: Vector2i in clear.keys():
			if not playable(c) or color[idx(c)] < 0:
				continue
			if ice[idx(c)] == 1:
				ice[idx(c)] = 0
				ice_left -= 1
			if used.has(c):
				continue
			cleared.append(c)
			color[idx(c)] = EMPTY
			special[idx(c)] = NONE
		for cr: Dictionary in created:
			special[idx(cr["cell"])] = int(cr["kind"])
			specials_made += 1
		var points: int = (cleared.size() + created.size()) * POINTS_TILE * mini(combo, 3) + created.size() * POINTS_SPECIAL
		score += points
		var fall: Dictionary = _gravity()
		phases.append({"cleared": cleared, "created": created, "moved": fall["moved"], "spawned": fall["spawned"],
			"combo": combo, "points": points})
		combo += 1
		first = false
	return phases


func _pivot(cells: Array, pivots: Array) -> Vector2i:
	for p: Vector2i in pivots:
		if cells.has(p):
			return p
	return cells[cells.size() >> 1]


func _effect(c: Vector2i, s: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	match s:
		ROW:
			for x: int in w:
				out.append(Vector2i(x, c.y))
		COL:
			for y: int in h:
				out.append(Vector2i(c.x, y))
		WRAP:
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					out.append(c + Vector2i(dx, dy))
		BOMB:
			## Bomba rota sin cambiarla: se lleva el color mas comun.
			var counts: Dictionary = {}
			for i: int in color.size():
				if color[i] >= 0:
					counts[color[i]] = int(counts.get(color[i], 0)) + 1
			var best: int = 0
			for k: Variant in counts.keys():
				if int(counts[k]) > int(counts.get(best, 0)):
					best = int(k)
			for y: int in h:
				for x: int in w:
					if color[y * w + x] == best:
						out.append(Vector2i(x, y))
	return out


func _runs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for horizontal: bool in [true, false]:
		var outer: int = h if horizontal else w
		var inner: int = w if horizontal else h
		for o: int in outer:
			var start: int = 0
			while start < inner:
				var c0: Vector2i = Vector2i(start, o) if horizontal else Vector2i(o, start)
				var k: int = at(c0)
				var end: int = start + 1
				while end < inner and k >= 0 and at(Vector2i(end, o) if horizontal else Vector2i(o, end)) == k:
					end += 1
				if k >= 0 and end - start >= 3:
					var cells: Array[Vector2i] = []
					for t: int in range(start, end):
						cells.append(Vector2i(t, o) if horizontal else Vector2i(o, t))
					out.append({"cells": cells, "horizontal": horizontal})
				start = end
	return out


## 5 - Caida por columnas (cada columna es un tramo seguido de casillas) y relleno por arriba.
func _gravity() -> Dictionary:
	var moved: Array[Dictionary] = []
	var spawned: Array[Dictionary] = []
	for x: int in w:
		var cells: Array[int] = []
		for y: int in h:
			if color[y * w + x] != HOLE:
				cells.append(y)
		if cells.is_empty():
			continue
		var write: int = cells.size() - 1
		for r: int in range(cells.size() - 1, -1, -1):
			var y: int = cells[r]
			if color[y * w + x] >= 0:
				var ty: int = cells[write]
				if ty != y:
					color[ty * w + x] = color[y * w + x]
					special[ty * w + x] = special[y * w + x]
					color[y * w + x] = EMPTY
					special[y * w + x] = NONE
					moved.append({"from": Vector2i(x, y), "to": Vector2i(x, ty)})
				write -= 1
		var drop: int = write + 1
		for r: int in range(write, -1, -1):
			var y2: int = cells[r]
			color[y2 * w + x] = rng.randi() % colors
			special[y2 * w + x] = NONE
			spawned.append({"cell": Vector2i(x, y2), "color": color[y2 * w + x], "drop": drop})
	return {"moved": moved, "spawned": spawned}


## 6 - Baraja las piezas normales hasta que no haya lineas y si haya jugada.
func shuffle() -> void:
	var pool: Array[int] = []
	for i: int in color.size():
		if color[i] >= 0 and special[i] == NONE:
			pool.append(color[i])
	for tries: int in 80:
		var bag: Array[int] = pool.duplicate()
		for i: int in color.size():
			if color[i] >= 0 and special[i] == NONE:
				color[i] = bag.pop_at(rng.randi() % bag.size())
		if _runs().is_empty() and has_move():
			return
	fill_without_matches()


func clone() -> Match3Logic:
	var c: Match3Logic = Match3Logic.new()
	c.w = w
	c.h = h
	c.colors = colors
	c.color = color.duplicate()
	c.special = special.duplicate()
	c.ice = ice.duplicate()
	c.score = score
	c.ice_left = ice_left
	c.ice_total = ice_total
	c.rng.seed = rng.randi()
	return c


## Analizador de tableros: forma valida para que caigan y entren piezas.
static func analyze(map: Array) -> Dictionary:
	var rows: Array[String] = LevelBuilder.normalize(map)
	var issues: Array[String] = []
	var h0: int = rows.size()
	var w0: int = rows[0].length() if h0 > 0 else 0
	var cells: int = 0
	var ice_n: int = 0
	if w0 < 5 or w0 > 9 or h0 < 6 or h0 > 11:
		issues.append("match3_size")
	for x: int in w0:
		## Los huecos solo arriba o abajo de cada columna: en medio cortarian la caida.
		var seen_cell: bool = false
		var gap_after: bool = false
		for y: int in h0:
			var ch: String = rows[y][x]
			if ch == "#":
				if seen_cell:
					gap_after = true
			else:
				cells += 1
				if ch == "I":
					ice_n += 1
				if gap_after:
					if not issues.has("match3_hole_inside"):
						issues.append("match3_hole_inside")
				seen_cell = true
	if cells < 35:
		issues.append("match3_small")
	if ice_n > (cells >> 1):
		issues.append("match3_too_much_ice")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [], "cells": cells, "ice": ice_n}

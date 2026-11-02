extends RefCounted
## Nonograma (Picross / Pixel art logico): reglas, pistas, resolutor por lineas, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): el dibujo escondido, "#" pintada y "." vacia.
## 2 - Las pistas de cada fila y columna dicen los tramos seguidos de casillas pintadas.
## 3 - Tocar pinta (o marca con X en modo cruz). Pintar una casilla vacia es un fallo (se marca
##     sola con X); con "lives" fallos se pierde. Se gana al pintar todo el dibujo.
## Analizador: tamano 4-12, dibujo con algo pintado y que se resuelva solo con logica de lineas
## (sin adivinar), que es lo que hace un buen nonograma.

static func parse(level: Dictionary) -> Array:
	var out: Array = []
	for r: Variant in level.get("map", []):
		var row: Array = []
		var s: String = str(r)
		for i: int in s.length():
			row.append(s[i] == "#")
		out.append(row)
	return out


static func runs(line: Array) -> Array:
	var out: Array = []
	var k: int = 0
	for v: Variant in line:
		if v:
			k += 1
		elif k > 0:
			out.append(k)
			k = 0
	if k > 0:
		out.append(k)
	return out


static func clues(sol: Array) -> Dictionary:
	var rows: Array = []
	var cols: Array = []
	var h: int = sol.size()
	var w: int = (sol[0] as Array).size() if h > 0 else 0
	for y: int in h:
		rows.append(runs(sol[y]))
	for x: int in w:
		var col: Array = []
		for y: int in h:
			col.append(sol[y][x])
		cols.append(runs(col))
	return {"rows": rows, "cols": cols}


## Todas las colocaciones de los tramos en una linea de largo n compatibles con lo sabido
## (1 pintada, 0 vacia, -1 desconocida). Devuelve lo comun: 1/0 fijos, -1 si varia, o null si nada encaja.
static func line_solve(known: Array, clue: Array) -> Variant:
	var n: int = known.size()
	var acc: Array = []
	acc.resize(n)
	acc.fill(-2)
	var cur: Array = []
	cur.resize(n)
	cur.fill(0)
	var found: Array = [false]
	_place(known, clue, 0, 0, cur, acc, found)
	if not found[0]:
		return null
	return acc


static func _place(known: Array, clue: Array, ci: int, start: int, cur: Array, acc: Array, found: Array) -> void:
	var n: int = known.size()
	if ci == clue.size():
		for i: int in range(start, n):
			if int(known[i]) == 1:
				return
		found[0] = true
		for i: int in n:
			var v: int = int(cur[i]) if i < start else 0
			if int(acc[i]) == -2:
				acc[i] = v
			elif int(acc[i]) != v:
				acc[i] = -1
		return
	var len_c: int = int(clue[ci])
	var rest: int = 0
	for k: int in range(ci + 1, clue.size()):
		rest += int(clue[k]) + 1
	for s: int in range(start, n - len_c - rest + 1):
		## Lo que queda entre start y s tiene que poder ser vacio.
		var ok: bool = true
		for i: int in range(start, s):
			if int(known[i]) == 1:
				ok = false
				break
		if not ok:
			break
		for i: int in range(s, s + len_c):
			if int(known[i]) == 0:
				ok = false
				break
		if ok and s + len_c < n and int(known[s + len_c]) == 1:
			ok = false
		if not ok:
			continue
		for i: int in range(start, s):
			cur[i] = 0
		for i: int in range(s, s + len_c):
			cur[i] = 1
		var nxt: int = s + len_c
		if nxt < n:
			cur[nxt] = 0
			nxt += 1
		_place(known, clue, ci + 1, nxt, cur, acc, found)


## Resuelve por lineas: devuelve la rejilla sabida (1/0/-1) cuando ya no avanza.
static func logic_solve(cl: Dictionary, w: int, h: int) -> Array:
	var g: Array = []
	for y: int in h:
		var row: Array = []
		row.resize(w)
		row.fill(-1)
		g.append(row)
	var changed: bool = true
	var guard: int = 0
	while changed and guard < 200:
		changed = false
		guard += 1
		for y: int in h:
			var r: Variant = line_solve(g[y], cl["rows"][y])
			if r == null:
				return []
			for x: int in w:
				if int(g[y][x]) == -1 and int(r[x]) != -1:
					g[y][x] = int(r[x])
					changed = true
		for x: int in w:
			var col: Array = []
			for y: int in h:
				col.append(g[y][x])
			var c: Variant = line_solve(col, cl["cols"][x])
			if c == null:
				return []
			for y: int in h:
				if int(g[y][x]) == -1 and int(c[y]) != -1:
					g[y][x] = int(c[y])
					changed = true
	return g


static func new_state(level: Dictionary) -> Dictionary:
	var sol: Array = parse(level)
	var h: int = sol.size()
	var w: int = (sol[0] as Array).size() if h > 0 else 0
	var cells: Array = []
	for y: int in h:
		var row: Array = []
		row.resize(w)
		row.fill(0)
		cells.append(row)
	var total: int = 0
	for y: int in h:
		for x: int in w:
			if sol[y][x]:
				total += 1
	## cells: 0 sin tocar, 1 pintada, 2 cruz.
	return {"sol": sol, "w": w, "h": h, "cells": cells, "clues": clues(sol), "mistakes": 0, "lives": int(level.get("lives", 3)),
		"painted": 0, "total": total}


## Pinta (mode 1) o marca con cruz (mode 2). Devuelve "ok", "mistake" o "" si no hizo nada.
static func mark(st: Dictionary, x: int, y: int, mode: int) -> String:
	if x < 0 or y < 0 or x >= int(st["w"]) or y >= int(st["h"]) or int(st["cells"][y][x]) != 0:
		return ""
	var filled: bool = bool(st["sol"][y][x])
	if mode == 1:
		if filled:
			st["cells"][y][x] = 1
			st["painted"] = int(st["painted"]) + 1
			return "ok"
		st["cells"][y][x] = 2
		st["mistakes"] = int(st["mistakes"]) + 1
		return "mistake"
	if filled:
		st["cells"][y][x] = 1
		st["painted"] = int(st["painted"]) + 1
		st["mistakes"] = int(st["mistakes"]) + 1
		return "mistake"
	st["cells"][y][x] = 2
	return "ok"


static func won(st: Dictionary) -> bool:
	return int(st["total"]) > 0 and int(st["painted"]) >= int(st["total"])


static func lost(st: Dictionary) -> bool:
	return int(st["lives"]) > 0 and int(st["mistakes"]) >= int(st["lives"])


## Si una fila o columna ya tiene todo lo suyo pintado, el resto se marca con cruz (ayuda).
static func auto_cross(st: Dictionary) -> void:
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	for y: int in h:
		var done: bool = true
		for x: int in w:
			if bool(st["sol"][y][x]) and int(st["cells"][y][x]) != 1:
				done = false
				break
		if done:
			for x: int in w:
				if int(st["cells"][y][x]) == 0:
					st["cells"][y][x] = 2
	for x: int in w:
		var done2: bool = true
		for y: int in h:
			if bool(st["sol"][y][x]) and int(st["cells"][y][x]) != 1:
				done2 = false
				break
		if done2:
			for y: int in h:
				if int(st["cells"][y][x]) == 0:
					st["cells"][y][x] = 2


## Siguiente casilla del bot: la primera pintada de la solucion sin pintar. [x, y] o [].
static func next_move(st: Dictionary) -> Array:
	for y: int in int(st["h"]):
		for x: int in int(st["w"]):
			if bool(st["sol"][y][x]) and int(st["cells"][y][x]) == 0:
				return [x, y]
	return []


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var sol: Array = parse(level)
	var h: int = sol.size()
	var w: int = (sol[0] as Array).size() if h > 0 else 0
	if h < 4 or w < 4 or h > 12 or w > 12:
		issues.append("nonogram_size")
	for r: Variant in sol:
		if (r as Array).size() != w:
			issues.append("nonogram_ragged")
			break
	var total: int = 0
	if issues.is_empty():
		for y: int in h:
			for x: int in w:
				if sol[y][x]:
					total += 1
		if total < 4 or total == w * h:
			issues.append("nonogram_empty")
	if issues.is_empty():
		var g: Array = logic_solve(clues(sol), w, h)
		if g.is_empty():
			issues.append("nonogram_contradiction")
		else:
			for y: int in h:
				for x: int in w:
					if int(g[y][x]) != (1 if sol[y][x] else 0):
						if not issues.has("nonogram_guess"):
							issues.append("nonogram_guess")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": total, "enemies": 0, "enemy_problems": [],
		"par": 10 + w * h}

extends RefCounted
## Tuberias: un tablero de piezas de tuberia giradas; toca una pieza para girarla 90 grados. Gana
## cuando el agua del grifo llega a todas las piezas sin que ninguna tuberia quede abierta.
## Nivel: "w", "h", "src" ([x, y] del grifo), "tiles" (mascara de cada casilla en su giro actual:
## 1 arriba, 2 derecha, 4 abajo, 8 izquierda), "sol" (las mascaras resueltas, para el bot) y "taps"
## (toques maximos; 0 = sin limite). La fabrica parte de un arbol que llena el tablero (siempre
## tiene solucion) y gira las piezas al azar.

const Rules = preload("res://kit/rules.gd")
const UP: int = 1
const RIGHT: int = 2
const DOWN: int = 4
const LEFT: int = 8


static func rot(m: int) -> int:
	return ((m << 1) | (m >> 3)) & 15


static func new_state(level: Dictionary) -> Dictionary:
	var tiles: Array = []
	for t: Variant in level.get("tiles", []):
		tiles.append(int(t) & 15)
	var w: int = clampi(int(level.get("w", 4)), 2, 10)
	var h: int = clampi(int(level.get("h", 4)), 2, 12)
	tiles.resize(w * h)
	var src: Array = level.get("src", [0, 0])
	var st: Dictionary = {"w": w, "h": h, "tiles": tiles, "src": Vector2i(int(src[0]), int(src[1])), "taps": 0,
		"max_taps": maxi(0, int(level.get("taps", 0))), "wet": {}, "won": false, "lost": false, "rng": RandomNumberGenerator.new()}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	flow(st)
	return st


static func _dir(m: int) -> Vector2i:
	match m:
		UP:
			return Vector2i(0, -1)
		RIGHT:
			return Vector2i(1, 0)
		DOWN:
			return Vector2i(0, 1)
	return Vector2i(-1, 0)


static func _opp(m: int) -> int:
	return {UP: DOWN, DOWN: UP, LEFT: RIGHT, RIGHT: LEFT}[m]


## Llena st["wet"] con las casillas a las que llega el agua; devuelve si esta resuelto.
static func flow(st: Dictionary) -> bool:
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	var tiles: Array = st["tiles"]
	var wet: Dictionary = {}
	var leaks: int = 0
	var q: Array = [st["src"]]
	wet[st["src"]] = true
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		var m: int = int(tiles[c.y * w + c.x])
		for b: int in [UP, RIGHT, DOWN, LEFT]:
			if m & b == 0:
				continue
			var n: Vector2i = c + _dir(b)
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or int(tiles[n.y * w + n.x]) & _opp(b) == 0:
				leaks += 1
				continue
			if not wet.has(n):
				wet[n] = true
				q.append(n)
	st["wet"] = wet
	var done: bool = leaks == 0 and wet.size() == w * h
	if done:
		st["won"] = true
	return done


## Toca la casilla c: gira su pieza 90 grados.
static func tap(st: Dictionary, c: Vector2i) -> bool:
	if bool(st["won"]) or bool(st["lost"]) or c.x < 0 or c.y < 0 or c.x >= int(st["w"]) or c.y >= int(st["h"]):
		return false
	var i: int = c.y * int(st["w"]) + c.x
	st["tiles"][i] = rot(int(st["tiles"][i]))
	st["taps"] = int(st["taps"]) + 1
	Rules.hook(st, "on_tap", [c])
	if not flow(st) and int(st["max_taps"]) > 0 and int(st["taps"]) >= int(st["max_taps"]):
		st["lost"] = true
	return true


## Giros que faltan para que la mascara m sea igual a la de la solucion s (0-3).
static func turns_to(m: int, s: int) -> int:
	var x: int = m
	for k: int in 4:
		if x == s:
			return k
		x = rot(x)
	return -1


static func min_taps(level: Dictionary) -> int:
	var tiles: Array = level.get("tiles", [])
	var sol: Array = level.get("sol", [])
	if tiles.size() != sol.size():
		return -1
	var n: int = 0
	for i: int in tiles.size():
		var k: int = turns_to(int(tiles[i]) & 15, int(sol[i]) & 15)
		if k < 0:
			return -1
		n += k
	return n


## Bot: la primera pieza que no esta como en la solucion.
static func bot_move(st: Dictionary, sol: Array) -> Vector2i:
	var w: int = int(st["w"])
	for i: int in (st["tiles"] as Array).size():
		if i < sol.size() and int(st["tiles"][i]) != int(sol[i]):
			return Vector2i(i % w, i / w)
	return Vector2i(-1, -1)


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var w: int = int(level.get("w", 0))
	var h: int = int(level.get("h", 0))
	var tiles: Array = level.get("tiles", [])
	var sol: Array = level.get("sol", [])
	if w < 2 or h < 2 or tiles.size() != w * h or sol.size() != w * h:
		issues.append("pipe_size")
	var need: int = -1
	if issues.is_empty():
		var ok: Dictionary = new_state(level.merged({"tiles": sol}, true))
		if not bool(ok["won"]):
			issues.append("pipe_bad_solution")
		need = min_taps(level)
		if need < 0:
			issues.append("pipe_bad_tile")
		elif need < 3:
			issues.append("pipe_too_easy")
		elif int(level.get("taps", 0)) > 0 and int(level.get("taps", 0)) < need + 2:
			issues.append("pipe_taps_tight")
		if bool(new_state(level)["won"]):
			issues.append("pipe_already_done")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": tiles.size(), "enemies": 0, "enemy_problems": [], "min_taps": need}

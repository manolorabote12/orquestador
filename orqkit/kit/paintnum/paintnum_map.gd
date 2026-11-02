extends RefCounted
## Pintar por numeros: un dibujo de cuadritos con un numero en cada uno; elige un color de la paleta
## y toca (o arrastra) los cuadritos de ese numero. Pintar con el color equivocado es un fallo (no se
## pierde: los fallos solo quitan estrellas). Se gana con el dibujo entero pintado.
## Nivel: "cells" (filas de texto: "." fondo, "1"-"9" color de la paleta), "palette" (["#rrggbb", ...]),
## "fills" (cubos: pintan de golpe todo un color) y "from_art" (el dibujo sale del heroe del juego,
## con "art_size" cuadritos de lado y "art_colors" colores; si no hay arte, se usa "cells").

const Rules = preload("res://kit/rules.gd")


static func new_state(level: Dictionary) -> Dictionary:
	var rows: Array = level.get("cells", [])
	var h: int = rows.size()
	var w: int = 0
	for r: Variant in rows:
		w = maxi(w, str(r).length())
	var cells: PackedByteArray = PackedByteArray()
	cells.resize(w * h)
	for y: int in h:
		var row: String = str(rows[y])
		for x: int in w:
			var ch: String = row[x] if x < row.length() else "."
			cells[y * w + x] = int(ch) if ch.is_valid_int() else 0
	var painted: PackedByteArray = PackedByteArray()
	painted.resize(w * h)
	var st: Dictionary = {"w": w, "h": h, "cells": cells, "painted": painted, "palette": level.get("palette", []), "sel": 1,
		"mistakes": 0, "fills": clampi(int(level.get("fills", 2)), 0, 9), "left": 0, "won": false, "lost": false, "rng": RandomNumberGenerator.new()}
	var left: int = 0
	for v: int in cells:
		left += 1 if v > 0 else 0
	st["left"] = left
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


## Cuadritos sin pintar de un color.
static func remaining(st: Dictionary, c: int) -> int:
	var n: int = 0
	var cells: PackedByteArray = st["cells"]
	var painted: PackedByteArray = st["painted"]
	for i: int in cells.size():
		n += 1 if cells[i] == c and painted[i] == 0 else 0
	return n


static func select(st: Dictionary, c: int) -> bool:
	if c < 1 or c > (st["palette"] as Array).size():
		return false
	st["sel"] = c
	return true


## Pinta el cuadrito (x, y) con el color elegido. 1 pintado, 0 nada que hacer (fondo, ya pintado o
## fuera) y -1 color equivocado (fallo si count_miss).
static func paint(st: Dictionary, x: int, y: int, count_miss: bool = true) -> int:
	if bool(st["won"]) or x < 0 or y < 0 or x >= int(st["w"]) or y >= int(st["h"]):
		return 0
	var i: int = y * int(st["w"]) + x
	var cells: PackedByteArray = st["cells"]
	var painted: PackedByteArray = st["painted"]
	if cells[i] == 0 or painted[i] == 1:
		return 0
	var out: int = 1
	if cells[i] != int(st["sel"]):
		out = -1
		if count_miss:
			st["mistakes"] = int(st["mistakes"]) + 1
	else:
		painted[i] = 1
		st["painted"] = painted
		st["left"] = int(st["left"]) - 1
		if int(st["left"]) <= 0:
			st["won"] = true
	Rules.hook(st, "on_paint", [x, y, out])
	return out


## Cubo: pinta de golpe todo lo que queda del color elegido. Devuelve cuantos ha pintado.
static func fill(st: Dictionary) -> int:
	if int(st["fills"]) <= 0 or bool(st["won"]):
		return 0
	var c: int = int(st["sel"])
	var n: int = 0
	for i: int in (st["cells"] as PackedByteArray).size():
		if (st["cells"] as PackedByteArray)[i] == c and (st["painted"] as PackedByteArray)[i] == 0:
			paint(st, i % int(st["w"]), i / int(st["w"]), false)
			n += 1
	if n > 0:
		st["fills"] = int(st["fills"]) - 1
	return n


## Jugada del bot: [color, x, y] del primer cuadrito sin pintar (o [] si no queda ninguno).
static func bot_move(st: Dictionary) -> Array:
	var cells: PackedByteArray = st["cells"]
	var painted: PackedByteArray = st["painted"]
	var sel: int = int(st["sel"])
	var first: int = -1
	for i: int in cells.size():
		if cells[i] > 0 and painted[i] == 0:
			if cells[i] == sel:
				return [sel, i % int(st["w"]), i / int(st["w"])]
			if first < 0:
				first = i
	if first < 0:
		return []
	return [int(cells[first]), first % int(st["w"]), first / int(st["w"])]


## El dibujo de una imagen (el heroe): recorta lo transparente, la reduce a size cuadritos de lado
## (sin deformarla) y deja como mucho k colores (los mas usados, juntando los parecidos).
static func from_image(img: Image, size: int, k: int) -> Dictionary:
	if img == null or img.is_empty():
		return {}
	if img.is_compressed():
		img.decompress()
	var used: Rect2i = img.get_used_rect()
	if used.size.x < 4 or used.size.y < 4:
		return {}
	var side: float = float(maxi(used.size.x, used.size.y)) / float(clampi(size, 6, 24))
	var w: int = clampi(int(ceil(float(used.size.x) / side)), 1, 24)
	var h: int = clampi(int(ceil(float(used.size.y) / side)), 1, 24)
	var px: Array = []
	for y: int in h:
		for x: int in w:
			var sx: int = mini(used.end.x - 1, used.position.x + int((float(x) + 0.5) * side))
			var sy: int = mini(used.end.y - 1, used.position.y + int((float(y) + 0.5) * side))
			var c: Color = img.get_pixel(sx, sy)
			px.append(c if c.a > 0.5 else Color(0, 0, 0, 0))
	## Colores iniciales: los mas frecuentes (redondeados) y luego 6 vueltas de k-medias.
	var freq: Dictionary = {}
	for c2: Color in px:
		if c2.a > 0.0:
			var key: Color = Color(snappedf(c2.r, 0.2), snappedf(c2.g, 0.2), snappedf(c2.b, 0.2))
			freq[key] = int(freq.get(key, 0)) + 1
	var keys: Array = freq.keys()
	keys.sort_custom(func(a: Color, b: Color) -> bool: return int(freq[a]) > int(freq[b]))
	var cent: Array = keys.slice(0, clampi(k, 2, 9))
	if cent.size() < 2:
		return {}
	var asg: Array = []
	asg.resize(px.size())
	for it: int in 6:
		var sum: Array = []
		var cnt: Array = []
		for j: int in cent.size():
			sum.append(Vector3.ZERO)
			cnt.append(0)
		for i: int in px.size():
			var c3: Color = px[i]
			asg[i] = -1
			if c3.a <= 0.0:
				continue
			var best: int = 0
			var bd: float = 99.0
			for j2: int in cent.size():
				var cc: Color = cent[j2]
				var d: float = Vector3(c3.r - cc.r, c3.g - cc.g, c3.b - cc.b).length_squared()
				if d < bd:
					bd = d
					best = j2
			asg[i] = best
			sum[best] += Vector3(c3.r, c3.g, c3.b)
			cnt[best] += 1
		for j3: int in cent.size():
			if int(cnt[j3]) > 0:
				var v: Vector3 = sum[j3] / float(cnt[j3])
				cent[j3] = Color(v.x, v.y, v.z)
	## Numeros por uso (el 1, el color que mas sale); los que no se usan desaparecen.
	var count: Dictionary = {}
	for a2: Variant in asg:
		if int(a2) >= 0:
			count[int(a2)] = int(count.get(int(a2), 0)) + 1
	var order: Array = count.keys()
	order.sort_custom(func(a: int, b: int) -> bool: return int(count[a]) > int(count[b]))
	var num: Dictionary = {}
	var palette: Array = []
	for j4: int in order.size():
		num[int(order[j4])] = j4 + 1
		palette.append("#" + (cent[int(order[j4])] as Color).to_html(false))
	var rows: Array = []
	for y2: int in h:
		var row: String = ""
		for x2: int in w:
			var a3: int = int(asg[y2 * w + x2])
			row += "." if a3 < 0 else str(num[a3])
		rows.append(row)
	return {"cells": rows, "palette": palette}


## Analizador: tamano jugable, paleta de 2 a 9 colores distintos y todos usados, y bastante que pintar.
static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var rows: Array = level.get("cells", [])
	var pal: Array = level.get("palette", [])
	if rows.size() < 4 or rows.size() > 24:
		issues.append("paint_size")
	var w: int = 0
	for r: Variant in rows:
		w = maxi(w, str(r).length())
	if w < 4 or w > 24:
		issues.append("paint_size")
	if pal.size() < 2 or pal.size() > 9:
		issues.append("paint_palette")
	var used: Dictionary = {}
	var total: int = 0
	for r2: Variant in rows:
		for ch: String in str(r2):
			if ch == ".":
				continue
			if not ch.is_valid_int() or int(ch) < 1 or int(ch) > pal.size():
				issues.append("paint_bad_cell")
				break
			used[int(ch)] = true
			total += 1
	if used.size() != pal.size():
		issues.append("paint_unused_color")
	if total < 20:
		issues.append("paint_too_small")
	for a: int in pal.size():
		for b: int in range(a + 1, pal.size()):
			var ca: Color = Color(str(pal[a]))
			var cb: Color = Color(str(pal[b]))
			if Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b).length() < 0.08:
				issues.append("paint_similar_colors")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": total, "enemies": 0, "enemy_problems": []}

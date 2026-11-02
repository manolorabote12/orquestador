extends RefCounted
## Aventura (historia con decisiones, estilo novela visual / Choices): reglas, recorrido y
## analizador. Cada nivel es un capitulo escrito por la directora.
## Nivel (game.json -> levels[i]): "title", "scenes" y "endings".
##   scenes: [{"id", "who" (narrador|heroe|rival|jefe|aliado), "text",
##             "options": [{"text", "to" (id de escena o FIN_BUENO|FIN_REGULAR|FIN_MALO),
##                          "fx": {"valor"|"amistad"|"oro": n, "objeto": "llave"},
##                          "need": {"stat": "valor"|"amistad"|"oro", "min": n} o {"objeto": "llave"}}]}]
##   endings: {"bueno", "regular", "malo"}: el texto de cada final.
## La primera escena es el principio. Las estadisticas y los objetos siguen de un capitulo al
## siguiente (se guardan); en el primero empiezan a cero.
## Analizador:
## 1 - Ids unicos, todas las escenas con 1 a 3 opciones y destinos que existen.
## 2 - Todas las escenas se alcanzan desde la primera.
## 3 - Se llega al final bueno empezando a cero (respetando lo que pide cada opcion).
## 4 - Ninguna escena es un callejon sin salida (desde cada una se llega a algun final).

const STATS: Array[String] = ["valor", "amistad", "oro"]
const ENDS: Dictionary = {"FIN_BUENO": "bueno", "FIN_REGULAR": "regular", "FIN_MALO": "malo"}
const MAX_STATES: int = 20000


static func scenes_by_id(level: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for s: Variant in level.get("scenes", []):
		if s is Dictionary:
			out[str((s as Dictionary).get("id", ""))] = s
	return out


static func first_id(level: Dictionary) -> String:
	var sc: Array = level.get("scenes", [])
	return str((sc[0] as Dictionary).get("id", "")) if not sc.is_empty() and sc[0] is Dictionary else ""


## Se puede elegir esta opcion con estas estadisticas y objetos?
static func allowed(opt: Dictionary, stats: Dictionary, items: Array) -> bool:
	var need: Variant = opt.get("need", {})
	if not need is Dictionary or (need as Dictionary).is_empty():
		return true
	var n: Dictionary = need
	if n.has("objeto"):
		return items.has(str(n["objeto"]))
	if n.has("stat"):
		return int(stats.get(str(n["stat"]), 0)) >= int(n.get("min", 0))
	return true


## Aplica los efectos de una opcion (copia nueva de estadisticas y objetos).
static func apply(opt: Dictionary, stats: Dictionary, items: Array) -> Array:
	var s: Dictionary = stats.duplicate()
	var it: Array = items.duplicate()
	var fx: Variant = opt.get("fx", {})
	if fx is Dictionary:
		for k: Variant in fx:
			if str(k) == "objeto":
				if not it.has(str(fx[k])):
					it.append(str(fx[k]))
			elif STATS.has(str(k)):
				s[k] = int(s.get(k, 0)) + int(fx[k])
	return [s, it]


static func _key(id: String, stats: Dictionary, items: Array) -> String:
	var it: Array = items.duplicate()
	it.sort()
	return "%s|%d|%d|%d|%s" % [id, int(stats.get("valor", 0)), int(stats.get("amistad", 0)), mini(int(stats.get("oro", 0)), 50), ",".join(it)]


## Camino (indices de opcion) hasta el final pedido, o [] si no hay. Busca en anchura.
static func path_to(level: Dictionary, end: String, stats: Dictionary = {}, items: Array = []) -> Array:
	var by_id: Dictionary = scenes_by_id(level)
	var start: String = first_id(level)
	if start == "":
		return []
	var q: Array = [[start, stats, items, []]]
	var seen: Dictionary = {_key(start, stats, items): true}
	var head: int = 0
	while head < q.size() and seen.size() < MAX_STATES:
		var node: Array = q[head]
		head += 1
		var sc: Dictionary = by_id.get(node[0], {})
		var opts: Array = sc.get("options", [])
		for i: int in opts.size():
			var o: Dictionary = opts[i]
			if not allowed(o, node[1], node[2]):
				continue
			var to: String = str(o.get("to", ""))
			var nx: Array = apply(o, node[1], node[2])
			var path: Array = (node[3] as Array).duplicate()
			path.append(i)
			if ENDS.has(to):
				if ENDS[to] == end:
					return path
				continue
			var k: String = _key(to, nx[0], nx[1])
			if by_id.has(to) and not seen.has(k):
				seen[k] = true
				q.append([to, nx[0], nx[1], path])
	return []


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var scenes: Array = level.get("scenes", [])
	var by_id: Dictionary = scenes_by_id(level)
	if scenes.size() < 3 or scenes.size() > 30:
		issues.append("tale_scenes")
	if by_id.size() != scenes.size():
		issues.append("tale_ids")
	var edges: Dictionary = {}
	for s: Variant in scenes:
		var sc: Dictionary = s if s is Dictionary else {}
		var opts: Array = sc.get("options", [])
		if opts.is_empty() or opts.size() > 3:
			issues.append("tale_options")
			break
		if str(sc.get("text", "")).strip_edges() == "":
			issues.append("tale_text")
			break
		edges[str(sc.get("id", ""))] = []
		for o: Variant in opts:
			var to: String = str((o as Dictionary).get("to", "")) if o is Dictionary else ""
			if not ENDS.has(to) and not by_id.has(to):
				issues.append("tale_target")
				break
			(edges[str(sc.get("id", ""))] as Array).append(to)
	var endings: Dictionary = level.get("endings", {})
	for e: String in ["bueno", "regular", "malo"]:
		if str(endings.get(e, "")).strip_edges() == "":
			issues.append("tale_endings")
			break
	if issues.is_empty():
		## 2 - Todo alcanzable desde el principio.
		var seen: Dictionary = {first_id(level): true}
		var q: Array = [first_id(level)]
		while not q.is_empty():
			var c: String = q.pop_back()
			for to: Variant in edges.get(c, []):
				if by_id.has(to) and not seen.has(to):
					seen[to] = true
					q.append(to)
		if seen.size() != by_id.size():
			issues.append("tale_unreachable")
		## 4 - Desde cada escena se llega a algun final (sin mirar requisitos).
		for id: Variant in by_id:
			if not _reaches_end(str(id), edges):
				issues.append("tale_dead_end")
				break
		## 3 - El final bueno se alcanza empezando de cero.
		if path_to(level, "bueno").is_empty():
			issues.append("tale_no_good_end")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 3, "enemies": 0, "enemy_problems": [],
		"par": path_to(level, "bueno").size() if issues.is_empty() else 0}


static func _reaches_end(start: String, edges: Dictionary) -> bool:
	var seen: Dictionary = {start: true}
	var q: Array = [start]
	while not q.is_empty():
		var c: String = q.pop_back()
		for to: Variant in edges.get(c, []):
			if ENDS.has(to):
				return true
			if not seen.has(to):
				seen[to] = true
				q.append(to)
	return false

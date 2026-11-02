extends RefCounted
## Bot del imperio: juega como una persona que sabe (orden de construccion clasico de los juegos
## de estrategia) con las mismas acciones que los botones: entrenar, construir, subir de edad,
## repartir aldeanos y atacar.
## 1 - Aldeanos sin parar hasta 14 (20 en la Edad II, 24 en la III) y casas antes de llenarse.
## 2 - Cuartel con 7 aldeanos, almacen junto al bosque y granjas cuando se acaban las bayas.
## 3 - Edad II con 10 aldeanos; arqueria y establo; Edad III y taller de arietes.
## 4 - Ejercito mezclado (lanceros, arqueros, jinetes y arietes) y ataque con 10 tropas o mas;
##     si el ataque se queda en casi nada, vuelve a casa a juntarse.

static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	var think: int = 0
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")) and not bool(game.get("failed")):
			return true
		if not bool(game.call("can_act")):
			continue
		## Sin prisa (capturas, a x4) se piensa cada 0,15 s; con prisa, cada fotograma (0,6 s de juego).
		think += 1
		if not bool(game.get("fast")) and think % 10 != 0:
			continue
		step(game)
	return false


static func _build(g: Node, kind: String) -> bool:
	var c: Vector2i = g.call("find_spot", kind)
	return c.x >= 0 and bool(g.call("place", kind, c))


static func step(g: Node) -> void:
	var st: Dictionary = (g.get("stock") as Array)[0]
	var age: int = (g.get("age") as Array)[0]
	var aging: bool = float(g.get("aging")) > 0.0
	var vill: int = int(g.call("count_units", "aldeano", 0)) + int(g.call("queued", "aldeano"))
	var pop: int = int(g.call("pop", 0))
	var cap: int = int(g.call("pop_cap", 0))
	var queued_all: int = 0
	for k: String in ["aldeano", "lancero", "arquero", "jinete", "ariete"]:
		queued_all += int(g.call("queued", k))
	var want_v: int = [0, 14, 20, 24][age]
	## 1 - Casas antes de llenarse.
	if cap - pop - queued_all <= 3 and cap < 60 and not bool(g.call("building_pending", "casa")):
		_build(g, "casa")
	if vill < want_v and int(g.call("queued", "aldeano")) < 2:
		g.call("train", "aldeano")
	## 2 - Edificios basicos.
	if vill >= 7 and int(g.call("count_buildings", "cuartel", 0)) == 0:
		_build(g, "cuartel")
	if vill >= 9 and float(st["madera"]) >= 140.0 and int(g.call("count_buildings", "almacen", 0)) < 4 \
			and not bool(g.call("building_pending", "almacen")) and bool(g.call("needs_store")):
		_build(g, "almacen")
	var food_v: int = int(g.call("workers", "comida"))
	var farms: int = int(g.call("count_buildings", "granja", 0))
	if float(g.call("food_left")) < 150.0 * float(maxi(food_v, 1)) and farms < 3 + age and food_v > 0:
		_build(g, "granja")
	## 3 - Edades (se guarda para subir antes que para el ejercito).
	var saving: bool = false
	if age < 3 and not aging:
		var need_v: int = 10 if age == 1 else 18
		var army0: int = int(g.call("army_count", 0))
		if vill >= need_v and (age == 1 or (army0 >= 6 and int(g.call("attacking", 0)) == 0)):
			saving = true
			var cost: Dictionary = [{}, {}, {"comida": 300, "oro": 80}, {"comida": 500, "oro": 250}][age + 1]
			if float(st["comida"]) >= float(cost["comida"]) and float(st["oro"]) >= float(cost["oro"]):
				g.call("age_up")
	if age >= 2:
		if int(g.call("count_buildings", "arqueria", 0)) == 0:
			_build(g, "arqueria")
		if int(g.call("count_buildings", "establo", 0)) == 0:
			_build(g, "establo")
	if age >= 3 and int(g.call("count_buildings", "taller", 0)) == 0:
		_build(g, "taller")
	if age >= 2 and int(g.call("count_buildings", "cuartel", 0)) == 0:
		_build(g, "cuartel")
	## Mercado: si falta oro y sobra otra cosa, se cambia.
	if age >= 2 and float(st["oro"]) < 80.0:
		for r: String in ["comida", "madera"]:
			if float(st[r]) >= 350.0:
				g.call("trade", r)
				break
	## Reparto de aldeanos: un minimo por recurso segun la edad y, si un recurso se amontona y
	## otro falta, se mueve gente del que sobra al que falta.
	var mix: Dictionary = {"comida": 0.45, "madera": 0.4, "oro": 0.1} if age == 1 else {"comida": 0.35, "madera": 0.35, "oro": 0.2}
	var total: int = int(g.call("count_units", "aldeano", 0))
	var avail: Array[String] = []
	for r: String in ["comida", "madera", "oro"]:
		if r == "comida" or float(g.call("res_left", r)) > 0.0:
			avail.append(r)
	var moved: bool = false
	for r: String in avail:
		if float(int(g.call("workers", r))) < float(total) * float(mix[r]) - 1.0:
			g.call("assign", r)
			moved = true
			break
	if not moved and avail.size() > 1:
		var lo: String = avail[0]
		var hi: String = avail[0]
		for r: String in avail:
			if float(st[r]) < float(st[lo]):
				lo = r
			if float(st[r]) > float(st[hi]):
				hi = r
		if float(st[hi]) - float(st[lo]) > 250.0 and float(int(g.call("workers", hi))) > float(total) * float(mix[hi]):
			g.call("assign", lo, hi)
	## 4 - Ejercito.
	## El ejercito no se come la economia: primero los aldeanos de la edad (o casi).
	if vill >= want_v - 2 and (not saving or float(st["comida"]) > 700.0):
		var order: Array[String] = ["ariete", "jinete", "arquero", "lancero"]
		for kind: String in order:
			if int(g.call("queued", kind)) < 2:
				if kind == "ariete" and int(g.call("count_units", "ariete", 0)) >= 3:
					continue
				g.call("train", kind)
	var army: int = int(g.call("army_count", 0))
	var going: int = int(g.call("attacking", 0))
	## Se ataca con ventaja: mas tropas que las del rival y dos mas por cada torre.
	var towers: int = int(g.call("count_buildings", "torre", 1))
	var need: int = clampi(maxi(10 if age < 3 else 12, int(float(int(g.call("army_count", 1))) * 1.4) + 2 * towers), 10, 26)
	if going == 0 and army >= need:
		g.call("attack")
	elif going > 0 and going < 3 and army - going < 6:
		g.call("recall")
	elif going > 0 and army - going >= 6:
		## Refuerzos: lo que se ha quedado en casa se une al ataque.
		g.call("attack")

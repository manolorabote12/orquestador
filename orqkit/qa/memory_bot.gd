extends RefCounted
## Bot de memoria: juega como una persona con muy buena memoria (solo recuerda las cartas que
## ha visto destapadas, no hace trampas):
## 1 - Si conoce una pareja sin hacer, la destapa.
## 2 - Si no, destapa una carta nueva; si ya habia visto su pareja, la destapa despues.
## 3 - Si no la conocia, destapa otra carta nueva (y la recuerda).


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	var seen: Dictionary = {}
	var deaths_seen: int = 0
	var swaps_seen: int = 0
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 3:
			return false
		## Repetir el nivel baraja igual: lo visto sigue valiendo.
		if int(game.get("deaths")) != deaths_seen:
			deaths_seen = int(game.get("deaths"))
			## Con barajar, al repetir las cartas vuelven a su sitio de salida: se olvida lo cambiado.
			if bool(game.get("shuffle")):
				seen.clear()
				swaps_seen = 0
		## Sin prisa (fotos): una carta cada 0.4 s.
		if not bool(game.get("fast")) and f % 24 != 0:
			continue
		## Barajar: el cambio se ve; el bot cambia tambien lo que recordaba de esas dos cartas.
		if int(game.get("swaps")) != swaps_seen:
			swaps_seen = int(game.get("swaps"))
			var sw: Vector2i = game.get("last_swap")
			var fa: Variant = seen.get(sw.x)
			var fb: Variant = seen.get(sw.y)
			seen.erase(sw.x)
			seen.erase(sw.y)
			if fb != null:
				seen[sw.x] = fb
			if fa != null:
				seen[sw.y] = fa
		var cards: Array = game.get("cards")
		var i: int = choose(game, cards, seen)
		if i >= 0 and bool(game.call("flip", i)):
			seen[i] = int(cards[i]["face"])
	return false


static func choose(game: Node, cards: Array, seen: Dictionary) -> int:
	var first: int = game.get("first")
	if float(game.get("busy")) > 0.0:
		return -1
	if first < 0:
		## 1 - Pareja conocida.
		var by_face: Dictionary = {}
		for i: Variant in seen.keys():
			var k: int = int(i)
			if bool(cards[k]["done"]):
				continue
			var f: int = int(seen[k])
			if by_face.has(f):
				return int(by_face[f])
			by_face[f] = k
		return _unseen(cards, seen, -1)
	## 2 - Ya hay una destapada: su pareja si la conoce.
	var face: int = int(cards[first]["face"])
	for i2: Variant in seen.keys():
		var k2: int = int(i2)
		if k2 != first and not bool(cards[k2]["done"]) and int(seen[k2]) == face:
			return k2
	var u: int = _unseen(cards, seen, first)
	if u >= 0:
		return u
	for k3: int in cards.size():
		if k3 != first and not bool(cards[k3]["done"]):
			return k3
	return -1


static func _unseen(cards: Array, seen: Dictionary, skip: int) -> int:
	for k: int in cards.size():
		if k != skip and not seen.has(k) and not bool(cards[k]["done"]):
			return k
	return -1

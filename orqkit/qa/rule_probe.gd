extends "res://kit/rule_base.gd"
## Regla de prueba: apunta cada gancho que se llama (st["probe"]) y en la multitud regala uno por puerta.


func _mark(st: Dictionary, k: String) -> void:
	if not st.has("probe"):
		st["probe"] = {}
	st["probe"][k] = int((st["probe"] as Dictionary).get(k, 0)) + 1


func on_start(st: Dictionary) -> void:
	_mark(st, "on_start")


func on_step(st: Dictionary, _dt: float) -> void:
	_mark(st, "on_step")


func on_cycle(st: Dictionary, _id: String, _got: float) -> void:
	_mark(st, "on_cycle")


func on_buy(st: Dictionary, _id: String, _n: int) -> void:
	_mark(st, "on_buy")


func on_spin(st: Dictionary, _r: Dictionary) -> void:
	_mark(st, "on_spin")


func on_build(st: Dictionary, _i: int) -> void:
	_mark(st, "on_build")


func on_upgrade(st: Dictionary, _b: String) -> void:
	_mark(st, "on_upgrade")


func on_battle(st: Dictionary, _r: Dictionary) -> void:
	_mark(st, "on_battle")


func on_event(st: Dictionary, info: Dictionary) -> void:
	_mark(st, "on_event")
	if str(info["e"].get("t", "")) == "gate":
		st["n"] = int(st["n"]) + 1


func on_tap(st: Dictionary, _g: Vector2i, _c: Vector2i) -> void:
	_mark(st, "on_tap")


func on_merge(st: Dictionary, _c: Vector2i) -> void:
	_mark(st, "on_merge")


func on_deliver(st: Dictionary, _i: int) -> void:
	_mark(st, "on_deliver")


func on_guess(st: Dictionary, _g: String, _m: String) -> void:
	_mark(st, "on_guess")


func on_word(st: Dictionary, _w: String, _r: String) -> void:
	_mark(st, "on_word")

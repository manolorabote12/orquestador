extends RefCounted
## Carga las reglas de un juego y las llama desde la simulacion de cada genero.
## Las reglas salen de level["rules"] o, si no, de game.json -> "rules" (rutas res://mods/*.gd).
## Una regla que no carga o no hereda de rule_base.gd se ignora (el juego sigue como estaba).

const BASE: String = "res://kit/rule_base.gd"


static func load_rules(level: Dictionary) -> Array:
	var paths: Variant = level.get("rules", null)
	if not (paths is Array):
		paths = []
		var ml: MainLoop = Engine.get_main_loop()
		if ml is SceneTree and (ml as SceneTree).root != null:
			var kit: Node = (ml as SceneTree).root.get_node_or_null("Kit")
			if kit != null:
				var cfg: Variant = kit.get("config")
				if cfg is Dictionary:
					paths = (cfg as Dictionary).get("rules", [])
	var out: Array = []
	for p: Variant in paths as Array:
		var path: String = str(p)
		if not path.begins_with("res://mods/") and not path.begins_with("res://qa/"):
			continue
		var script: GDScript = load(path) as GDScript
		if script == null or not _extends_base(script):
			continue
		out.append(script.new())
	return out


static func _extends_base(script: Script) -> bool:
	var s: Script = script.get_base_script()
	while s != null:
		if s.resource_path == BASE:
			return true
		s = s.get_base_script()
	return false


## Llama un gancho en todas las reglas de la partida (si lo tienen).
static func hook(st: Dictionary, name: String, args: Array = []) -> void:
	var rules: Variant = st.get("rules", [])
	if not (rules is Array) or (rules as Array).is_empty():
		return
	for r: Object in rules as Array:
		if r.has_method(name):
			r.callv(name, [st] + args)


static func colors(st: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for r: Object in st.get("rules", []) as Array:
		out.merge(r.call("colors"), true)
	return out

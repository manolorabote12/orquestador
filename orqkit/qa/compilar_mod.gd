extends Node
## Comprueba que un mod compila con los autoloads del kit cargados (los usa la API de la base).
##     godot --headless --path <juego> res://qa/compilar_mod.tscn -- --mod=res://mods/x.gd  (o --rule=...)
## Escribe [MOD_OK] o [MOD_ERROR] y sale.


func _ready() -> void:
	var path: String = ""
	var rule: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--mod="):
			path = a.get_slice("=", 1)
		elif a.begins_with("--rule="):
			path = a.get_slice("=", 1)
			rule = true
	var script: GDScript = load(path) as GDScript if path != "" else null
	var ok: bool = script != null and script.can_instantiate()
	if ok and rule:
		## Regla: hereda de rule_base.gd y no es un nodo.
		var RulesLib: GDScript = load("res://kit/rules.gd")
		ok = RulesLib.call("_extends_base", script)
	elif ok:
		var inst: Object = script.new()
		ok = inst is Node and Mods.call("_extends_base", script)
		if inst is Node:
			(inst as Node).free()
	print("[MOD_OK]" if ok else "[MOD_ERROR] " + path)
	get_tree().quit(0 if ok else 1)

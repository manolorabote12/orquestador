extends SceneTree
## Niveles de un genero hecho a medida (kit/custom): llama a custom_map.generate y comprueba cada
## variante con su analizador. Lo usa la fabrica (genero_usuario.py):
##   godot --headless --path <proyecto> -s res://qa/generar_custom.gd -- --n=8 --d=0.5 --variantes=4 --out=/ruta.json
## Escribe {"levels": [[variante, ...] por nivel], "errors": [...]}.

func _init() -> void:
	var n: int = 8
	var d: float = 0.5
	var variants: int = 4
	var out: String = "user://custom_levels.json"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.get_slice("=", 1))
		elif a.begins_with("--d="):
			d = float(a.get_slice("=", 1))
		elif a.begins_with("--variantes="):
			variants = int(a.get_slice("=", 1))
		elif a.begins_with("--out="):
			out = a.get_slice("=", 1)
	var result: Dictionary = {"levels": [], "errors": []}
	var M: GDScript = load("res://kit/custom/custom_map.gd")
	if M == null or not M.has_method("generate"):
		result["errors"].append("custom_map.gd no carga o no tiene static func generate(i, n, d, seed)")
	else:
		for i: int in n:
			var ok: Array = []
			var dl: float = clampf(d * 0.5 + 0.5 * float(i) / float(maxi(1, n - 1)), 0.0, 1.0)
			for s: int in variants:
				var rows: Variant = M.call("generate", i, n, dl, s + 1)
				if not (rows is Array) or (rows as Array).is_empty():
					result["errors"].append("nivel %d semilla %d: generate no devuelve filas" % [i + 1, s + 1])
					continue
				var a2: Dictionary = M.call("analyze", {"map": rows})
				if bool(a2.get("completable", false)):
					ok.append(rows)
				else:
					result["errors"].append("nivel %d semilla %d: el analizador lo rechaza %s" % [i + 1, s + 1, str(a2.get("issues", []))])
			result["levels"].append(ok)
	var f: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(result))
		f.close()
	quit()

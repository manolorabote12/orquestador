class_name Prize
extends RefCounted
## Premio real (juegos para negocios): un cupon de verdad para quien supera el nivel N
## ("10 % en tu proxima compra"). Lo pone el autor desde la app y lo cambia cuando quiera.
## 1 - Con servidor: la portada lo pide (premio_actual) y lo guarda en "premio_info" para la
##     proxima vez; al ganarlo, premio_ganado da un codigo personal (PAN10-7F3A) y lo cuenta.
## 2 - Sin servidor: game.json -> "premio": {"texto", "codigo", "tras_nivel", "donde", "web",
##     "caduca"} (el codigo es el mismo para todos).
## 3 - Al superar el nivel N sale un boton en la pantalla de nivel superado; despues, la portada
##     tiene el boton "Premio" (antes de ganarlo dice que hay que hacer para conseguirlo).
## 4 - Caducado o quitado por el autor: deja de salir (el codigo ya ganado se sigue viendo).

const KEYS: Array[String] = ["texto", "tras_nivel", "donde", "web", "caduca"]


static func _clean(d: Variant) -> Dictionary:
	if not (d is Dictionary):
		return {}
	var src: Dictionary = d
	var texto: String = str(src.get("texto", "")).strip_edges()
	if texto.length() < 3:
		return {}
	var out: Dictionary = {"texto": texto.left(80), "tras_nivel": clampi(int(src.get("tras_nivel", 3)), 1, 50),
		"donde": str(src.get("donde", "")).left(80), "web": "", "caduca": str(src.get("caduca", "") if src.get("caduca") != null else "")}
	var web: String = str(src.get("web", ""))
	if web.begins_with("https://") and web.length() <= 208 and not (" " in web):
		out["web"] = web
	if src.has("codigo"):
		out["codigo"] = str(src["codigo"]).to_upper().left(16)
	return out


static func _expired(info: Dictionary) -> bool:
	var c: String = str(info.get("caduca", ""))
	return c.length() >= 10 and c.left(10) < Time.get_date_string_from_system()


## El premio que hay ahora (vacio si no hay): el del servidor si lo hay, si no el de game.json.
static func info() -> Dictionary:
	var d: Dictionary
	if Online.backend():
		d = _clean(Save.get_setting("premio_info", {}))
	else:
		d = _clean(Kit.config.get("premio", {}))
	if d.is_empty() or _expired(d):
		return {}
	return d


## Lo que contesta el servidor al arrancar (null = el autor lo quito).
static func store_remote(r: Variant) -> void:
	var d: Dictionary = _clean(r)
	Save.set_setting("premio_info", d)


static func won() -> Dictionary:
	var w: Variant = Save.get_setting("premio_ganado", {})
	return w if w is Dictionary else {}


static func has_won() -> bool:
	return str(won().get("codigo", "")) != ""


## Hay boton en la portada: premio ganado o premio por ganar.
static func visible() -> bool:
	return has_won() or not info().is_empty()


## Al superar un nivel: true si con este se gana el premio (y aun no se tenia).
static func earned_now(level_index: int) -> bool:
	if has_won() or Kit.is_extra() or Marathon.active():
		return false
	var d: Dictionary = info()
	return not d.is_empty() and level_index + 1 >= int(d["tras_nivel"])


## Cobra el premio: con servidor pide el codigo personal; sin el, el de game.json.
static func claim(level_index: int) -> Dictionary:
	var d: Dictionary = info()
	if d.is_empty():
		return {}
	var got: Dictionary = {}
	if Online.backend():
		got = _clean(await Online.claim_prize(level_index + 1))
	else:
		got = d
	if str(got.get("codigo", "")) == "":
		return {}
	Save.set_setting("premio_ganado", got)
	QA.log_event("prize_won", {"level": level_index + 1})
	return got


## Texto de lo que hay que hacer: "Supera el nivel 3 y consigue: 10 % en tu proxima compra".
static func goal_text() -> String:
	var d: Dictionary = info()
	if d.is_empty():
		return ""
	return Kit.text("prize_goal", "Supera el nivel {n} y consigue: {t}").format({"n": int(d["tras_nivel"]), "t": str(d["texto"])})


static func expiry_text(d: Dictionary) -> String:
	var c: String = str(d.get("caduca", ""))
	if c.length() < 10:
		return ""
	var p: PackedStringArray = c.left(10).split("-")
	return Kit.text("prize_until", "V\u00e1lido hasta el {d}").format({"d": "%s/%s/%s" % [p[2], p[1], p[0]]})

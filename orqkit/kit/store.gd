extends Node
## Compras dentro del juego (Google Play Billing). Autoload "Store".
## 1 - Productos fijos del kit (los crea la fabrica en la consola de Play del autor):
##     monedas_500, monedas_3000, pase_temporada (se consumen), sin_anuncios y pack_inicio
##     (una vez: 2000 monedas + sin anuncios, la oferta de bienvenida).
## 1b - Compras a medida (14 nov): game.json -> "store" las cambia por las del creador:
##     {"currency": {"name": "Perlas", "icon": "gem"}, "products": [{"id", "kind", "name", "price",
##     "coins"?, "plan"?, "bonus_pct"?, "daily"?, "no_ads"?}]}. kind: coins (pack de moneda),
##     no_ads, bundle (moneda + sin anuncios), pass (pase premium) y vip (suscripcion: sin anuncios,
##     +X % de moneda en cada partida y un regalo diario). Las mete la fabrica al publicar.
## 2 - En Android con el plugin GodotGooglePlayBilling: conecta, pide precios, compra; cada compra
##     pagada se comprueba en el servidor (funcion juego-compra, que tambien la consume o reconoce
##     en Google) y SOLO entonces se da lo comprado. Al arrancar recupera compras sin terminar, lo
##     que ya era tuyo y las suscripciones activas (si una caduca, se quita).
## 3 - En la web (galeria) aun no se cobra: la tienda se ve y "Comprar" apunta el intento en el
##     servidor (tienda_intento) para medir si la venta seria rentable. Sin plugin ni web, no hay
##     tienda. En las pruebas, fake = true: compras al momento.
## 4 - game.json -> "iap": false la apaga (por defecto esta encendida si hay servidor).

signal products_ready
signal purchased(product_id: String)
signal failed(product_id: String, reason: String)

const PLUGIN: String = "GodotGooglePlayBilling"
const PRODUCTS: Dictionary = {
	"monedas_500": {"kind": "coins", "coins": 500, "consumable": true, "price": "0,99 €"},
	"monedas_3000": {"kind": "coins", "coins": 3000, "consumable": true, "price": "4,99 €"},
	"pase_temporada": {"kind": "pass", "consumable": true, "price": "3,99 €"},
	"sin_anuncios": {"kind": "no_ads", "consumable": false, "price": "2,99 €"},
	"pack_inicio": {"kind": "bundle", "coins": 2000, "consumable": false, "price": "3,99 €"},
}
const KINDS: Array[String] = ["coins", "no_ads", "bundle", "pass", "vip"]
const MAX_PRODUCTS: int = 12
const PURCHASED_STATE: int = 1

var fake: bool = false
## Para las pruebas: lo que contesta el servidor al verificar (true = ok).
var fake_verify: Callable = Callable()
## Para las pruebas: simula la galeria web (la tienda se ve pero solo apunta intentos).
var fake_web: bool = false
var prices: Dictionary = {}
var _billing: Object = null
var _ready_products: bool = false
var _busy: Dictionary = {}
var _catalog: Dictionary = {}
## Planes base de las suscripciones (los da Google con los detalles).
var _plans: Dictionary = {}
## Que consulta de compras se espera: "inapp" y luego "subs" (para quitar el VIP caducado).
var _phase: String = ""
var _details_left: int = 0


func _ready() -> void:
	if not enabled():
		return
	if Engine.has_singleton(PLUGIN):
		_billing = Engine.get_singleton(PLUGIN)
		_billing.call("initPlugin")
		_billing.connect("connected", _on_connected)
		_billing.connect("query_product_details_response", _on_details)
		_billing.connect("query_purchases_response", _on_query)
		_billing.connect("on_purchase_updated", _on_purchases)
		_billing.call("startConnection")
	daily_gift()


func enabled() -> bool:
	return Kit.config.get("iap", true) != false and Kit.feature("tienda") and not Kit.kids()


## Hay tienda de verdad (o simulada en las pruebas).
func available() -> bool:
	return enabled() and (fake or (_billing != null and _ready_products))


## Galeria web: la tienda se ensena pero aun no cobra (apunta el intento).
func showcase() -> bool:
	return enabled() and not available() and (fake_web or (OS.has_feature("web") and Online.backend()))


# ------------------------------------------------------------------ catalogo

## Los productos del juego: los del creador (game.json -> "store") o los fijos del kit.
func products() -> Dictionary:
	if _catalog.is_empty():
		_catalog = custom_catalog(Kit.param("store", {}))
		if _catalog.is_empty():
			_catalog = PRODUCTS
	return _catalog


## Para las pruebas y al cambiar de juego.
func reset_catalog() -> void:
	_catalog = {}


func custom() -> bool:
	return products() != PRODUCTS


static func valid_id(id: String) -> bool:
	var re: RegEx = RegEx.create_from_string("^[a-z][a-z0-9_]{2,39}$")
	return re.search(id) != null


## Convierte la tienda del creador en el catalogo (ignora lo que no cumpla las reglas).
static func custom_catalog(st: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (st is Dictionary):
		return out
	var list: Variant = (st as Dictionary).get("products", [])
	if not (list is Array):
		return out
	for e: Variant in list:
		if not (e is Dictionary) or out.size() >= MAX_PRODUCTS:
			continue
		var d: Dictionary = e
		var id: String = str(d.get("id", ""))
		var kind: String = str(d.get("kind", ""))
		if not KINDS.has(kind) or not valid_id(id) or out.has(id):
			continue
		var p: Dictionary = {"kind": kind, "consumable": kind == "coins" or kind == "pass", "price": str(d.get("price", "")),
			"name": str(d.get("name", "")).left(40)}
		if kind == "coins" or kind == "bundle":
			p["coins"] = clampi(int(d.get("coins", 0)), 1, 1000000)
		if kind == "vip":
			p["sub"] = true
			p["plan"] = str(d.get("plan", "mes"))
			p["bonus_pct"] = clampi(int(d.get("bonus_pct", 0)), 0, 300)
			p["daily"] = clampi(int(d.get("daily", 0)), 0, 100000)
			p["no_ads"] = bool(d.get("no_ads", true))
		out[id] = p
	return out


## Nombre de la moneda del juego ("Perlas", "Gemas"...) o "monedas".
func currency_name() -> String:
	var st: Variant = Kit.param("store", {})
	if st is Dictionary and (st as Dictionary).get("currency") is Dictionary:
		var n: String = str(((st as Dictionary)["currency"] as Dictionary).get("name", "")).strip_edges()
		if n != "":
			return n.left(20)
	return Kit.text("ex_coins", "monedas")


func currency_icon() -> String:
	var st: Variant = Kit.param("store", {})
	if st is Dictionary and (st as Dictionary).get("currency") is Dictionary:
		var i: String = str(((st as Dictionary)["currency"] as Dictionary).get("icon", ""))
		if ["coin", "gem", "star", "heart", "trophy", "cube"].has(i):
			return i
	return "coin"


## El primer producto de un tipo (para la oferta de bienvenida, el pase...).
func first_of(kind: String) -> String:
	for id: String in products().keys():
		if str((products()[id] as Dictionary)["kind"]) == kind:
			return id
	return ""


## Texto para ensenar un producto en la tienda.
func label(id: String) -> String:
	var p: Dictionary = products().get(id, {})
	if str(p.get("name", "")) != "":
		return str(p["name"])
	match str(p.get("kind", "")):
		"coins":
			return "%d %s" % [int(p["coins"]), currency_name()]
		"no_ads":
			return Kit.text("iap_no_ads", "Sin anuncios")
		"bundle":
			return Kit.text("starter_short", "Pack de inicio: {n} monedas + sin anuncios").format({"n": int(p["coins"])})
		"pass":
			return Kit.text("pass_premium", "Pase premium")
		"vip":
			return Kit.text("iap_vip", "VIP")
	return id


func price(id: String) -> String:
	return str(prices.get(id, (products().get(id, {}) as Dictionary).get("price", "")))


## Productos de una vez ya comprados (el pack de inicio).
func owns(id: String) -> bool:
	return bool(Save.get_setting("own_" + id, false))


func no_ads() -> bool:
	if bool(Save.get_setting("no_ads", false)):
		return true
	for id: String in vip_active():
		if bool((products()[id] as Dictionary).get("no_ads", true)):
			return true
	return false


# ------------------------------------------------------------------ VIP (suscripcion)

## Suscripciones VIP activas en este movil.
func vip_active() -> Array[String]:
	var out: Array[String] = []
	for id: String in products().keys():
		if str((products()[id] as Dictionary)["kind"]) == "vip" and bool(Save.get_setting("vip_" + id, false)):
			out.append(id)
	return out


func vip() -> bool:
	return not vip_active().is_empty()


## Multiplicador de moneda por partida (VIP: +bonus_pct %).
func coin_bonus() -> float:
	var best: int = 0
	for id: String in vip_active():
		best = maxi(best, int((products()[id] as Dictionary).get("bonus_pct", 0)))
	return 1.0 + float(best) / 100.0


## Regalo diario del VIP (una vez al dia). Devuelve lo que da.
func daily_gift() -> int:
	var n: int = 0
	for id: String in vip_active():
		n = maxi(n, int((products()[id] as Dictionary).get("daily", 0)))
	var today: String = Time.get_date_string_from_system()
	if n <= 0 or str(Save.get_setting("vip_daily", "")) == today:
		return 0
	Save.set_setting("vip_daily", today)
	Save.add_wallet(n)
	QA.log_event("vip_daily", {"coins": n})
	return n


# ------------------------------------------------------------------ comprar

## Abre la compra de Google. El resultado llega por purchased / failed.
func buy(id: String) -> void:
	if not products().has(id):
		failed.emit(id, "unavailable")
		return
	if showcase():
		_intent(id)
		failed.emit(id, "soon")
		return
	if not available():
		failed.emit(id, "unavailable")
		return
	QA.log_event("iap_start", {"product": id})
	if fake:
		_verify_and_grant.call_deferred({"product_ids": [id], "purchase_token": "fake-%s-%d" % [id, Time.get_ticks_usec()], "purchase_state": PURCHASED_STATE})
		return
	var r: Variant
	if bool((products()[id] as Dictionary).get("sub", false)):
		r = _billing.call("purchaseSubscription", id, str(_plans.get(id, (products()[id] as Dictionary).get("plan", "mes"))), "", false)
	else:
		r = _billing.call("purchase", id, "", "", false)
	if r is Dictionary and int((r as Dictionary).get("response_code", -1)) != 0:
		failed.emit(id, "launch")


## Galeria web: apunta que alguien quiso comprar (sin cobrar) para medir la rentabilidad.
func _intent(id: String) -> void:
	QA.log_event("iap_intent", {"product": id})
	if fake_web or not Online.backend():
		return
	Online._rpc("tienda_intento", {"p_juego": str(Online.config().get("game", "")), "p_sesion": Online.device(),
		"p_producto": id, "p_precio": price(id)})


func _ids(subs: bool) -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in products().keys():
		if bool((products()[id] as Dictionary).get("sub", false)) == subs:
			out.append(id)
	return out


func _on_connected() -> void:
	_details_left = 0
	for subs: bool in [false, true]:
		if not _ids(subs).is_empty():
			_details_left += 1
			_billing.call("queryProductDetails", _ids(subs), "subs" if subs else "inapp")
	_phase = "inapp"
	_billing.call("queryPurchases", "inapp", false)


func _on_details(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != 0:
		return
	for d: Variant in r.get("product_details", []):
		if not (d is Dictionary):
			continue
		var dd: Dictionary = d
		var pid: String = str(dd.get("product_id", ""))
		var offers: Variant = dd.get("one_time_purchase_offer_details_list", null)
		if offers is Array and not (offers as Array).is_empty() and (offers as Array)[0] is Dictionary:
			prices[pid] = str(((offers as Array)[0] as Dictionary).get("formatted_price", ""))
		var subs: Variant = dd.get("subscription_offer_details", null)
		if subs is Array and not (subs as Array).is_empty() and (subs as Array)[0] is Dictionary:
			var o: Dictionary = (subs as Array)[0]
			_plans[pid] = str(o.get("base_plan_id", ""))
			var phases: Variant = o.get("pricing_phases", [])
			if phases is Array and not (phases as Array).is_empty() and (phases as Array)[-1] is Dictionary:
				prices[pid] = str(((phases as Array)[-1] as Dictionary).get("formatted_price", ""))
	_details_left -= 1
	if _details_left <= 0:
		_ready_products = true
		products_ready.emit()


## Respuesta a "que compras tengo": primero las de una vez y despues las suscripciones.
func _on_query(r: Dictionary) -> void:
	var phase: String = _phase
	_on_purchases(r)
	if phase == "inapp" and not _ids(true).is_empty():
		_phase = "subs"
		_billing.call("queryPurchases", "subs", false)
	elif phase == "subs" and int(r.get("response_code", -1)) == 0:
		_phase = ""
		sync_subs(Array(r.get("purchases", [])))


## Deja como VIP solo las suscripciones que Google dice que siguen activas.
func sync_subs(purchases: Array) -> void:
	var live: Array = []
	for p: Variant in purchases:
		if p is Dictionary and int((p as Dictionary).get("purchase_state", 0)) == PURCHASED_STATE:
			live.append_array(Array((p as Dictionary).get("product_ids", [])))
	for id: String in products().keys():
		if str((products()[id] as Dictionary)["kind"]) == "vip" and bool(Save.get_setting("vip_" + id, false)) and not live.has(id):
			Save.set_setting("vip_" + id, false)
			QA.log_event("vip_end", {"product": id})


func _on_purchases(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != 0:
		if int(r.get("response_code", -1)) == 1:
			failed.emit("", "canceled")
		return
	for p: Variant in r.get("purchases", []):
		if p is Dictionary:
			_verify_and_grant(p as Dictionary)


## Una compra pagada: el servidor la comprueba (y la cierra en Google); despues se da.
func _verify_and_grant(p: Dictionary) -> void:
	var ids: Array = Array(p.get("product_ids", []))
	if ids.is_empty() or int(p.get("purchase_state", 0)) != PURCHASED_STATE:
		return
	var id: String = str(ids[0])
	if not products().has(id):
		return
	var info: Dictionary = products()[id]
	var token: String = str(p.get("purchase_token", ""))
	## Lo de una vez (sin anuncios, pack, VIP) ya reconocido: solo hay que recordarlo (reinstalar
	## el juego), sin volver a dar la moneda del pack.
	if bool(p.get("is_acknowledged", false)) and not bool(info.get("consumable", false)):
		_restore(id)
		return
	if _busy.has(token):
		return
	_busy[token] = true
	var ok: bool = await _verify(id, token)
	_busy.erase(token)
	if not ok:
		failed.emit(id, "not_verified")
		return
	_grant(id)
	QA.log_event("iap_done", {"product": id})
	purchased.emit(id)


func _verify(id: String, token: String) -> bool:
	if fake_verify.is_valid():
		return bool(fake_verify.call(id, token))
	if fake:
		return true
	var c: Dictionary = Online.config()
	if str(c.get("url", "")) == "":
		return false
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 30.0
	add_child(http)
	var headers: PackedStringArray = ["Content-Type: application/json", "apikey: " + str(c.get("key", "")),
		"Authorization: Bearer " + str(c.get("key", ""))]
	var body: Dictionary = {"juego": str(c.get("game", "")), "sesion": Online.device(), "producto": id, "token": token}
	if http.request(str(c["url"]).trim_suffix("/") + "/functions/v1/juego-compra", headers, HTTPClient.METHOD_POST, JSON.stringify(body)) != OK:
		http.queue_free()
		return false
	var res: Array = await http.request_completed
	http.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		return false
	var d: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return d is Dictionary and bool((d as Dictionary).get("ok", false))


## Lo que ya era tuyo, sin volver a dar moneda.
func _restore(id: String) -> void:
	match str((products()[id] as Dictionary)["kind"]):
		"no_ads":
			Save.set_setting("no_ads", true)
		"bundle":
			Save.set_setting("no_ads", true)
			Save.set_setting("own_" + id, true)
		"vip":
			Save.set_setting("vip_" + id, true)


func _grant(id: String) -> void:
	var info: Dictionary = products()[id]
	match str(info["kind"]):
		"coins":
			Save.add_wallet(int(info["coins"]))
		"pass":
			Season.unlock_premium()
		"no_ads":
			Save.set_setting("no_ads", true)
		"bundle":
			Save.add_wallet(int(info["coins"]))
			Save.set_setting("no_ads", true)
			Save.set_setting("own_" + id, true)
		"vip":
			Save.set_setting("vip_" + id, true)
			daily_gift()

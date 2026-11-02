extends Node
## Compras dentro del juego (Google Play Billing). Autoload "Store".
## 1 - Productos fijos del kit (los crea la fabrica en la consola de Play del autor):
##     monedas_500, monedas_3000, pase_temporada (se consumen), sin_anuncios y pack_inicio
##     (una vez: 2000 monedas + sin anuncios, la oferta de bienvenida).
## 2 - En Android con el plugin GodotGooglePlayBilling: conecta, pide precios, compra; cada compra
##     pagada se comprueba en el servidor (funcion juego-compra, que tambien la consume o reconoce
##     en Google) y SOLO entonces se da lo comprado. Al arrancar recupera compras sin terminar y
##     "sin anuncios" si ya era tuyo.
## 3 - Sin plugin (web, PC) no hay tienda. En las pruebas, fake = true: compras al momento.
## 4 - game.json -> "iap": false la apaga (por defecto esta encendida si hay servidor).

signal products_ready
signal purchased(product_id: String)
signal failed(product_id: String, reason: String)

const PLUGIN: String = "GodotGooglePlayBilling"
const PRODUCTS: Dictionary = {
	"monedas_500": {"kind": "coins", "coins": 500, "consumable": true, "price": "0,99 \u20ac"},
	"monedas_3000": {"kind": "coins", "coins": 3000, "consumable": true, "price": "4,99 \u20ac"},
	"pase_temporada": {"kind": "pass", "consumable": true, "price": "3,99 \u20ac"},
	"sin_anuncios": {"kind": "no_ads", "consumable": false, "price": "2,99 \u20ac"},
	"pack_inicio": {"kind": "bundle", "coins": 2000, "consumable": false, "price": "3,99 \u20ac"},
}
const PURCHASED_STATE: int = 1

var fake: bool = false
## Para las pruebas: lo que contesta el servidor al verificar (true = ok).
var fake_verify: Callable = Callable()
var prices: Dictionary = {}
var _billing: Object = null
var _ready_products: bool = false
var _busy: Dictionary = {}


func _ready() -> void:
	if not enabled():
		return
	if Engine.has_singleton(PLUGIN):
		_billing = Engine.get_singleton(PLUGIN)
		_billing.call("initPlugin")
		_billing.connect("connected", _on_connected)
		_billing.connect("query_product_details_response", _on_details)
		_billing.connect("query_purchases_response", _on_purchases)
		_billing.connect("on_purchase_updated", _on_purchases)
		_billing.call("startConnection")


func enabled() -> bool:
	return Kit.config.get("iap", true) != false and Kit.feature("tienda") and not Kit.kids()


## Hay tienda de verdad (o simulada en las pruebas).
func available() -> bool:
	return enabled() and (fake or (_billing != null and _ready_products))


func price(id: String) -> String:
	return str(prices.get(id, (PRODUCTS.get(id, {}) as Dictionary).get("price", "")))


## Productos de una vez ya comprados (el pack de inicio).
func owns(id: String) -> bool:
	return bool(Save.get_setting("own_" + id, false))


func no_ads() -> bool:
	return bool(Save.get_setting("no_ads", false))


## Abre la compra de Google. El resultado llega por purchased / failed.
func buy(id: String) -> void:
	if not PRODUCTS.has(id) or not available():
		failed.emit(id, "unavailable")
		return
	QA.log_event("iap_start", {"product": id})
	if fake:
		_verify_and_grant.call_deferred({"product_ids": [id], "purchase_token": "fake-%s-%d" % [id, Time.get_ticks_usec()], "purchase_state": PURCHASED_STATE})
		return
	var r: Variant = _billing.call("purchase", id, "", "", false)
	if r is Dictionary and int((r as Dictionary).get("response_code", -1)) != 0:
		failed.emit(id, "launch")


func _on_connected() -> void:
	_billing.call("queryProductDetails", PackedStringArray(PRODUCTS.keys()), "inapp")
	_billing.call("queryPurchases", "inapp", false)


func _on_details(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != 0:
		return
	for d: Variant in r.get("product_details", []):
		if d is Dictionary:
			var dd: Dictionary = d
			var offers: Variant = dd.get("one_time_purchase_offer_details_list", null)
			if offers is Array and not (offers as Array).is_empty() and (offers as Array)[0] is Dictionary:
				prices[str(dd.get("product_id", ""))] = str(((offers as Array)[0] as Dictionary).get("formatted_price", ""))
	_ready_products = true
	products_ready.emit()


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
	var token: String = str(p.get("purchase_token", ""))
	## "sin anuncios" ya reconocido: solo hay que recordarlo (reinstalar el juego). El pack de
	## inicio tambien, pero sin volver a dar las monedas.
	if id == "sin_anuncios" and bool(p.get("is_acknowledged", false)):
		_grant(id)
		return
	if id == "pack_inicio" and bool(p.get("is_acknowledged", false)):
		Save.set_setting("no_ads", true)
		Save.set_setting("own_pack_inicio", true)
		return
	if _busy.has(token) or not PRODUCTS.has(id):
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


func _grant(id: String) -> void:
	var info: Dictionary = PRODUCTS[id]
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
			Save.set_setting("own_pack_inicio", true)

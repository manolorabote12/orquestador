extends Node
## Ads: capa de anuncios con las reglas que protegen la cuenta de AdMob y al jugador.
## Autoload "Ads". Con el plugin nativo de AdMob (Android/iOS, exportacion Gradle) muestra anuncios
## reales (kit/ads_admob.gd); en el PC, en las pruebas y en los APK de prueba es un simulador.
## Configuracion en game.json -> "ads": {"enabled", "android": {"interstitial", "rewarded"},
## "ios": {...}, "child_directed", "max_rating"}. Sin ids propios se usan los de prueba de Google.
##
## Reglas:
## 1 - Intersticial solo en pausas naturales (fin de nivel, derrota), nunca en mitad de la accion.
## 2 - Nunca en los primeros SESSION_GRACE segundos de sesion.
## 3 - Como minimo INTERSTITIAL_COOLDOWN segundos entre dos intersticiales.
## 4 - Maximo MAX_INTERSTITIALS por sesion.
## 5 - Bonificado solo cuando el jugador lo pide; el premio llega por la senal reward_earned.
## 6 - Cuantos y cada cuanto (y si hay banner o anuncio al volver) lo dice el perfil del juego
##     (kit/monetize.gd). Los valores de abajo son los de partida.
## 7 - Banner: abajo, en los menus y/o en la partida segun el perfil; la interfaz deja su hueco
##     (UI.safe_insets suma banner_space). "Sin anuncios" lo quita.

signal reward_earned(placement: String)
signal reward_cancelled(placement: String)
signal availability_changed
signal _real_done(ok: bool)

const SESSION_GRACE: float = 60.0
const INTERSTITIAL_COOLDOWN: float = 90.0
const MAX_INTERSTITIALS: int = 6
const NATURAL_BREAKS: Array[String] = ["level_end", "game_over", "menu_return"]

var enabled: bool = true
var simulate_seconds: float = 1.0

var _session_start_ms: int = 0
var _last_interstitial_ms: int = -1000000
var _interstitials_shown: int = 0
var _showing: bool = false
var _admob: RefCounted = null
## Pantalla actual para el banner: "menu", "game" o "" (UI.goto la pone al cambiar).
var banner_kind: String = "menu"
## El validador revisa la interfaz con el hueco del banner aunque este en modo prueba.
var audit_banner: bool = false
var _level_ends: int = 0
var _fake_banner: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_session_start_ms = Time.get_ticks_msec()
	var config: Dictionary = Kit.param("ads", {}) as Dictionary
	enabled = bool(config.get("enabled", true))
	if enabled and Engine.has_singleton("PoingGodotAdMob"):
		_admob = (load("res://kit/ads_admob.gd") as GDScript).new()
		_admob.connect("changed", func() -> void: availability_changed.emit())
		_admob.call("setup", self, config)


func is_real() -> bool:
	return _admob != null


## 8 - Hay un bonificado listo para ofrecer (en el simulador, siempre).
func rewarded_available() -> bool:
	if not enabled:
		return false
	if _admob != null:
		return bool(_admob.call("has_rewarded"))
	return true


## 9 - RGPD: si Google lo pide, los ajustes muestran "Privacidad de anuncios".
func privacy_options_required() -> bool:
	return _admob != null and bool(_admob.call("privacy_options_required"))


func show_privacy_options() -> void:
	if _admob != null:
		_admob.call("show_privacy_options")


func session_seconds() -> float:
	return float(Time.get_ticks_msec() - _session_start_ms) / 1000.0


func can_show_interstitial(placement: String) -> bool:
	if not enabled or _showing:
		return false
	## Compro "sin anuncios": nunca mas anuncios que salten solos (los de premio siguen siendo opcionales).
	## Un juego regalo tampoco los lleva.
	if Store.no_ads() or Gift.active():
		return false
	if not NATURAL_BREAKS.has(placement):
		return false
	var every: int = int(Monetize.p("inter_every"))
	if every <= 0:
		return false
	if session_seconds() < float(Monetize.p("inter_grace")):
		return false
	if float(Time.get_ticks_msec() - _last_interstitial_ms) / 1000.0 < float(Monetize.p("inter_cooldown")):
		return false
	## Cada cuantos finales de nivel (el primero que toca, el resto se saltan).
	if placement == "level_end" and _level_ends % every != 0:
		return false
	return _interstitials_shown < int(Monetize.p("inter_max"))


## 6 - Devuelve true si se mostro. El juego sigue igual si no toca anuncio.
func show_interstitial(placement: String) -> bool:
	if placement == "level_end":
		_level_ends += 1
	if not can_show_interstitial(placement):
		return false
	if _admob != null and not bool(_admob.call("has_interstitial")):
		return false
	_showing = true
	_last_interstitial_ms = Time.get_ticks_msec()
	_interstitials_shown += 1
	QA.log_event("ad_interstitial", {"placement": placement})
	var shown: bool = true
	if _admob != null:
		shown = await _real_show("show_interstitial")
	else:
		await get_tree().create_timer(simulate_seconds, true, false, true).timeout
	_showing = false
	return shown


func show_rewarded(placement: String) -> void:
	if not enabled or _showing:
		reward_cancelled.emit(placement)
		return
	_showing = true
	QA.log_event("ad_rewarded", {"placement": placement})
	var earned: bool = true
	if _admob != null:
		earned = await _real_show("show_rewarded")
	else:
		await get_tree().create_timer(simulate_seconds, true, false, true).timeout
	_showing = false
	if earned:
		reward_earned.emit(placement)
	else:
		reward_cancelled.emit(placement)


## 10 - Espera a que el anuncio real se cierre (el juego queda en pausa natural mientras tanto).
func _real_show(method: String) -> bool:
	_admob.call(method, func(ok: bool) -> void: _real_done.emit.call_deferred(ok))
	var ok: bool = await _real_done
	return ok


## 7 - Solo para pruebas: simula que la sesion lleva tiempo abierta.
func debug_shift_session(seconds: float) -> void:
	_session_start_ms -= int(seconds * 1000.0)
	_last_interstitial_ms -= int(seconds * 1000.0)


# ------------------------------------------------------------------ banner y vuelta a la app

## Hay banner en este tipo de pantalla ("menu" o "game") para este juego?
func banner_allowed(kind: String) -> bool:
	if not enabled or kind == "" or Store.no_ads() or Gift.active() or not has_unit("banner"):
		return false
	return bool(Monetize.p("banner_menu" if kind == "menu" else "banner_game"))


## Alto que la interfaz deja libre abajo para el banner (0 si no hay). En las pruebas y capturas
## no hay hueco, salvo en el validador (audit_banner) para comprobar que todo cabe con el.
func banner_space(vp: Viewport) -> float:
	if vp == null or not banner_allowed(banner_kind):
		return 0.0
	if UI.test_mode and not audit_banner:
		return 0.0
	return vp.get_visible_rect().size.x * BANNER_RATIO


const BANNER_RATIO: float = 0.16


## La version de tienda trae sus bloques: uno vacio ("banner": "") es que el autor no lo ha creado y
## ese formato no se usa. Sin bloques (PC, pruebas) vale el de prueba de Google.
func has_unit(kind: String) -> bool:
	var cfg: Dictionary = Kit.param("ads", {}) as Dictionary
	var ids: Variant = cfg.get(OS.get_name().to_lower(), cfg.get("android", {}))
	if not ids is Dictionary or not (ids as Dictionary).has(kind):
		return true
	return str((ids as Dictionary)[kind]) != ""


## La pone UI.goto antes de cambiar de pantalla: ensena u oculta el banner.
func set_banner(kind: String) -> void:
	banner_kind = kind
	var show_it: bool = banner_allowed(kind) and not UI.test_mode
	if _admob != null:
		_admob.call("banner", show_it)
	else:
		_simulated_banner(show_it)


## En el PC (y en la vista previa del autor): una franja que ensena donde ira el banner.
func _simulated_banner(show_it: bool) -> void:
	if not show_it:
		if _fake_banner != null:
			_fake_banner.visible = false
		return
	if _fake_banner == null:
		_fake_banner = CanvasLayer.new()
		_fake_banner.name = "FakeBanner"
		_fake_banner.layer = 90
		var r: ColorRect = ColorRect.new()
		r.name = "Bar"
		r.color = Color(0.1, 0.1, 0.12, 0.92)
		r.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fake_banner.add_child(r)
		var l: Label = Label.new()
		l.text = Kit.text("ad_banner", "Anuncio")
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		r.add_child(l)
		add_child(_fake_banner)
	var h: float = banner_space(get_viewport())
	var bar: ColorRect = _fake_banner.get_node("Bar")
	bar.offset_top = -h
	bar.offset_bottom = 0.0
	_fake_banner.visible = true


## Al volver a la app (juegos idle): anuncio de vuelta si toca y nadie ha pagado por quitarlos.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and enabled and not Store.no_ads() and bool(Monetize.p("app_open")) and has_unit("app_open"):
		if session_seconds() > float(Monetize.p("inter_grace")) and _admob != null and not _showing:
			QA.log_event("ad_app_open", {})
			_admob.call("show_app_open")

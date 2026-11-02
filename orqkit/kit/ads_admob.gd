extends RefCounted
## Puente con AdMob de verdad (plugin de Poing Studios, licencia MIT, en addons/admob).
## Solo lo carga Ads cuando existe el plugin nativo (Android/iOS con exportacion Gradle).
## En el PC, en las pruebas y en los APK de prueba, Ads sigue con su simulador.
## Orden obligatorio de Google:
## 1 - Consentimiento (UMP: RGPD en Europa). Sin respuesta, no se piden anuncios.
## 2 - Configuracion: juego para ninos -> anuncios aptos para ninos (politica de familias).
## 3 - Inicializar y precargar un intersticial y un bonificado (al cerrarse, se carga otro).

signal changed

const TEST_IDS: Dictionary = {
	"Android": {"interstitial": "ca-app-pub-3940256099942544/1033173712", "rewarded": "ca-app-pub-3940256099942544/5224354917",
		"banner": "ca-app-pub-3940256099942544/9214589741", "app_open": "ca-app-pub-3940256099942544/9257395921"},
	"iOS": {"interstitial": "ca-app-pub-3940256099942544/4411468910", "rewarded": "ca-app-pub-3940256099942544/1712485313",
		"banner": "ca-app-pub-3940256099942544/2435281174", "app_open": "ca-app-pub-3940256099942544/5575463023"},
}
const RETRY_SECONDS: Array[float] = [5.0, 15.0, 45.0, 120.0]

var initialized: bool = false
var units: Dictionary = {}
var child_directed: bool = false
var max_rating: String = "PG"

var _host: Node = null
var _interstitial: InterstitialAd = null
var _rewarded: RewardedAd = null
var _loading_interstitial: bool = false
var _loading_rewarded: bool = false
var _fails_interstitial: int = 0
var _fails_rewarded: int = 0
var _on_interstitial_done: Callable = Callable()
var _on_rewarded_done: Callable = Callable()
var _earned: bool = false
var _banner: AdView = null
var _banner_wanted: bool = false
var _app_open: AppOpenAd = null
var _loading_app_open: bool = false


func setup(host: Node, config: Dictionary) -> void:
	_host = host
	var os_name: String = OS.get_name()
	var defaults: Dictionary = TEST_IDS.get(os_name, TEST_IDS["Android"])
	var ids: Dictionary = config.get(os_name.to_lower(), {})
	units = {
		"interstitial": str(ids.get("interstitial", defaults["interstitial"])),
		"rewarded": str(ids.get("rewarded", defaults["rewarded"])),
		"banner": str(ids.get("banner", defaults["banner"])),
		"app_open": str(ids.get("app_open", defaults["app_open"])),
	}
	child_directed = bool(config.get("child_directed", false))
	max_rating = str(config.get("max_rating", "G" if child_directed else "PG"))
	_request_consent()


func _request_consent() -> void:
	var request: ConsentRequestParameters = ConsentRequestParameters.new()
	request.tag_for_under_age_of_consent = child_directed
	UserMessagingPlatform.consent_information.update(request, _on_consent_info, _on_consent_error)


func _on_consent_info() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_form_loaded, _on_form_error)
	else:
		_start()


func _on_consent_error(_error: FormError) -> void:
	## Sin red o error del formulario: se intenta igual; Google decide si puede servir anuncios.
	_start()


func _on_form_loaded(form: ConsentForm) -> void:
	var status: int = UserMessagingPlatform.consent_information.get_consent_status()
	if status == ConsentInformation.ConsentStatus.REQUIRED:
		form.show(_on_form_dismissed)
	else:
		_start()


func _on_form_error(_error: FormError) -> void:
	_start()


func _on_form_dismissed(_error: FormError) -> void:
	_start()


func privacy_options_required() -> bool:
	return UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


func show_privacy_options() -> void:
	UserMessagingPlatform.show_privacy_options_form(func(_e: FormError) -> void: changed.emit())


func _start() -> void:
	if initialized:
		return
	var rc: RequestConfiguration = RequestConfiguration.new()
	rc.max_ad_content_rating = max_rating
	if child_directed:
		rc.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.TRUE
		rc.tag_for_under_age_of_consent = RequestConfiguration.TagForUnderAgeOfConsent.TRUE
	MobileAds.set_request_configuration(rc)
	var listener: OnInitializationCompleteListener = OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_s: InitializationStatus) -> void:
		initialized = true
		QA.log_event("admob_ready", {"child": child_directed, "rating": max_rating})
		load_interstitial()
		load_rewarded()
		if bool(Monetize.p("app_open")):
			load_app_open()
		if _banner_wanted:
			banner(true)
	MobileAds.initialize(listener)


## 4 - Precarga. Si falla, reintenta cada vez mas tarde (no se insiste a Google).
func load_interstitial() -> void:
	if not initialized or _loading_interstitial or _interstitial != null:
		return
	_loading_interstitial = true
	var cb: InterstitialAdLoadCallback = InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_loading_interstitial = false
		_fails_interstitial = 0
		_interstitial = ad
		changed.emit()
	cb.on_ad_failed_to_load = func(err: LoadAdError) -> void:
		_loading_interstitial = false
		QA.log_event("admob_load_failed", {"format": "interstitial", "code": err.code})
		_retry(load_interstitial, _fails_interstitial)
		_fails_interstitial += 1
	InterstitialAdLoader.new().load(str(units["interstitial"]), AdRequest.new(), cb)


func load_rewarded() -> void:
	if not initialized or _loading_rewarded or _rewarded != null:
		return
	_loading_rewarded = true
	var cb: RewardedAdLoadCallback = RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_loading_rewarded = false
		_fails_rewarded = 0
		_rewarded = ad
		changed.emit()
	cb.on_ad_failed_to_load = func(err: LoadAdError) -> void:
		_loading_rewarded = false
		QA.log_event("admob_load_failed", {"format": "rewarded", "code": err.code})
		_retry(load_rewarded, _fails_rewarded)
		_fails_rewarded += 1
	RewardedAdLoader.new().load(str(units["rewarded"]), AdRequest.new(), cb)


func _retry(what: Callable, fails: int) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	var wait: float = RETRY_SECONDS[mini(fails, RETRY_SECONDS.size() - 1)]
	_host.get_tree().create_timer(wait, true, false, true).timeout.connect(what)


func has_interstitial() -> bool:
	return _interstitial != null


func has_rewarded() -> bool:
	return _rewarded != null


## 5 - Muestra y llama a done(mostrado) al cerrarse. El juego espera en pausa natural.
func show_interstitial(done: Callable) -> void:
	if _interstitial == null:
		done.call(false)
		return
	var ad: InterstitialAd = _interstitial
	_interstitial = null
	_on_interstitial_done = done
	var cc: FullScreenContentCallback = FullScreenContentCallback.new()
	cc.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_finish_interstitial(true)
	cc.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void:
		ad.destroy()
		_finish_interstitial(false)
	ad.full_screen_content_callback = cc
	ad.show()


func _finish_interstitial(shown: bool) -> void:
	var done: Callable = _on_interstitial_done
	_on_interstitial_done = Callable()
	load_interstitial()
	if done.is_valid():
		done.call(shown)


func show_rewarded(done: Callable) -> void:
	if _rewarded == null:
		done.call(false)
		return
	var ad: RewardedAd = _rewarded
	_rewarded = null
	_earned = false
	_on_rewarded_done = done
	var cc: FullScreenContentCallback = FullScreenContentCallback.new()
	cc.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_finish_rewarded()
	cc.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void:
		ad.destroy()
		_finish_rewarded()
	ad.full_screen_content_callback = cc
	var listener: OnUserEarnedRewardListener = OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		_earned = true
	ad.show(listener)


func _finish_rewarded() -> void:
	var done: Callable = _on_rewarded_done
	_on_rewarded_done = Callable()
	load_rewarded()
	if done.is_valid():
		done.call(_earned)


## 6 - Banner adaptable abajo (lo pide Ads segun la pantalla y el perfil del juego).
func banner(show_it: bool) -> void:
	_banner_wanted = show_it
	if not initialized or str(units.get("banner", "")) == "":
		return
	if show_it:
		if _banner == null:
			var size: AdSize = AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
			if size.width <= 0:
				size = AdSize.BANNER
			_banner = AdView.new(str(units["banner"]), size, AdPosition.BOTTOM)
			_banner.load_ad(AdRequest.new())
		_banner.show()
	elif _banner != null:
		_banner.hide()


## 7 - Anuncio al volver a la app (juegos idle): se precarga y se ensena al volver.
func load_app_open() -> void:
	if not initialized or _loading_app_open or _app_open != null or str(units.get("app_open", "")) == "":
		return
	_loading_app_open = true
	var cb: AppOpenAdLoadCallback = AppOpenAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: AppOpenAd) -> void:
		_loading_app_open = false
		_app_open = ad
	cb.on_ad_failed_to_load = func(err: LoadAdError) -> void:
		_loading_app_open = false
		QA.log_event("admob_load_failed", {"format": "app_open", "code": err.code})
	AppOpenAdLoader.new().load(str(units["app_open"]), AdRequest.new(), cb)


func has_app_open() -> bool:
	return _app_open != null


func show_app_open() -> void:
	if _app_open == null:
		load_app_open()
		return
	var ad: AppOpenAd = _app_open
	_app_open = null
	var cc: FullScreenContentCallback = FullScreenContentCallback.new()
	cc.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		load_app_open()
	cc.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void:
		ad.destroy()
		load_app_open()
	ad.full_screen_content_callback = cc
	ad.show()

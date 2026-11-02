class_name Expert
extends RefCounted
## Modo experto (todos los generos con giros seguros): rejuega los niveles superados con un giro
## dificil fijo por nivel (de los "daily_twists" que la fabrica prueba con los bots, asi nunca
## hace un nivel imposible). Superarlo da la medalla de experto del nivel y el doble de monedas.
## 1 - Interruptor "Experto" en el selector de niveles (con 2+ niveles abiertos); no a la vez que
##     el contrarreloj. La portada lo apaga.
## 2 - En cada level_start, Twist pone el giro del nivel (prepare).

const BONUS: int = 2


static func available() -> bool:
	return not Twist.daily_options().is_empty() and Kit.level_count() > 0 and Save.unlocked_count() >= 2 and not Kit.kids()


static func active() -> bool:
	return Kit.expert


static func start() -> void:
	Kit.expert = true
	TimeAttack.stop()
	QA.log_event("expert", {"on": true})


static func stop() -> void:
	if Kit.expert:
		Kit.expert = false
		if not Twist.daily_active:
			Twist.forced.clear()


static func twist_for(i: int) -> String:
	var opts: Array[String] = Twist.daily_options()
	return "" if opts.is_empty() else opts[(i * 7 + 3) % opts.size()]


## Antes de empezar un nivel en modo experto: su giro.
static func prepare(i: int) -> void:
	if not Kit.expert or Twist.daily_active or Kit.is_extra() or Marathon.active():
		return
	var t: String = twist_for(i)
	Twist.forced.clear()
	if t != "":
		Twist.forced.append(t)


static func has_medal(i: int) -> bool:
	return bool(Save.get_setting("experto_%d" % i, false))


static func medals() -> int:
	var c: int = 0
	for i: int in Kit.level_count():
		if has_medal(i):
			c += 1
	return c


## Nivel superado en experto: medalla (la primera vez) y monedas extra.
static func on_win(i: int, earned: int) -> Dictionary:
	var first: bool = not has_medal(i)
	Save.set_setting("experto_%d" % i, true)
	var extra: int = earned * (BONUS - 1)
	Save.add_wallet(extra)
	return {"first": first, "extra": extra, "twist": twist_for(i)}


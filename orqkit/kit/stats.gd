class_name Stats
extends RefCounted
## Estadisticas del jugador (todos los generos): partidas, victorias, derrotas, mejor racha,
## tiempo jugado y dias jugando. Se cuentan con los eventos del juego (level_start,
## level_complete, death) que ya manda cada genero; Twist se los pasa a on_event.
## Las ensena StatsPanel (Ajustes -> Estadisticas). Los niveles extra tambien cuentan.

static var _started_ms: int = -1


static func n(key: String) -> int:
	return int(Save.get_setting("st_" + key, 0))


static func _add(key: String, v: int = 1) -> void:
	Save.set_setting("st_" + key, n(key) + v)


static func _close_time() -> void:
	if _started_ms >= 0:
		_add("secs", clampi(int((Time.get_ticks_msec() - _started_ms) / 1000), 0, 3600))
		_started_ms = -1


static func on_event(entry: Dictionary) -> void:
	match str(entry.get("event", "")):
		"level_start":
			_close_time()
			_started_ms = Time.get_ticks_msec()
			_add("plays")
			var today: int = Save.today()
			if int(Save.get_setting("st_last_day", -1)) != today:
				Save.set_setting("st_last_day", today)
				_add("days")
		"level_complete":
			_close_time()
			_add("wins")
			_add("streak")
			if n("streak") > n("best_streak"):
				Save.set_setting("st_best_streak", n("streak"))
		"death":
			_add("deaths")
			_add("dl_%d" % Kit.level_index)
			Save.set_setting("st_streak", 0)


## Veces que se ha perdido en un nivel (para el modo clase: donde se atasca).
static func deaths_at(i: int) -> int:
	return n("dl_%d" % i)


static func win_rate() -> int:
	var tries: int = n("wins") + n("deaths")
	return 0 if tries == 0 else int(round(100.0 * float(n("wins")) / float(tries)))


static func time_text() -> String:
	var s: int = n("secs")
	if s < 3600:
		return Kit.text("stat_min", "{m} min").format({"m": s / 60})
	return Kit.text("stat_hours", "{h} h {m} min").format({"h": s / 3600, "m": (s % 3600) / 60})


static func stars() -> int:
	var t: int = 0
	for i: int in Kit.level_count():
		t += Save.stars_for(str(i))
	return t


## Filas para el panel: [nombre, valor].
static func rows() -> Array:
	var out: Array = [
		[Kit.text("stat_plays", "Partidas"), str(n("plays"))],
		[Kit.text("stat_wins", "Niveles superados"), "%d  (%d %%)" % [n("wins"), win_rate()]],
		[Kit.text("stat_best_streak", "Mejor racha"), str(n("best_streak"))],
		[Kit.text("stat_level", "Nivel m\u00e1s alto"), "%d / %d" % [mini(Save.unlocked_count(), maxi(Kit.level_count(), 1)), Kit.level_count()]],
		[Kit.text("stat_stars", "Estrellas"), "%d / %d" % [stars(), Kit.level_count() * 3]],
		[Kit.text("stat_time", "Tiempo jugado"), time_text()],
		[Kit.text("stat_days", "D\u00edas jugando"), str(n("days"))],
	]
	if Expert.available() or Expert.medals() > 0:
		out.append([Kit.text("ex_medals", "Medallas de experto"), "%d / %d" % [Expert.medals(), Kit.level_count()]])
	return out

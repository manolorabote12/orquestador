class_name TimeAttack
extends RefCounted
## Modo contrarreloj (todos los generos): rejuega los niveles abiertos contra tu mejor tiempo.
## 1 - Se enciende con el boton "Contrarreloj" del selector de niveles (cuando ya has superado uno).
## 2 - En la partida se ve el reloj y tu record de ese nivel (Look pone la franja).
## 3 - Al ganar se guarda el tiempo si es mejor ("crono_<nivel>") y el panel lo celebra.
## 4 - Las estrellas, monedas y desbloqueos van como siempre; la portada lo apaga.
## Los niveles extra (reto del dia, 2 jugadores) no guardan tiempos.
## 5 - Con clasificacion online, cada record se sube a la del nivel LB_BASE + n (puntos = 1 h - ms).

const LB_BASE: int = 1000
const LB_HOUR_MS: int = 3600000


static func to_score(t: float) -> int:
	return clampi(LB_HOUR_MS - int(round(t * 1000.0)), 1, LB_HOUR_MS) if t > 0.0 else 0


static func from_score(p: int) -> float:
	return float(LB_HOUR_MS - p) / 1000.0


static func available() -> bool:
	return Kit.level_count() > 0 and Save.unlocked_count() >= 2


static func active() -> bool:
	return Kit.time_attack


static func start() -> void:
	Kit.time_attack = true
	QA.log_event("time_attack", {"on": true})


static func stop() -> void:
	Kit.time_attack = false


static func best(i: int) -> float:
	return float(Save.get_setting("crono_%d" % i, 0.0))


## Nivel ganado en contrarreloj: guarda el tiempo si es record.
static func on_win(i: int, t: float) -> Dictionary:
	var prev: float = best(i)
	var rec: bool = t > 0.05 and (prev <= 0.0 or t < prev - 0.001)
	if rec:
		Save.set_setting("crono_%d" % i, snappedf(t, 0.1))
		## Mejorar un tiempo que ya tenias cuenta para el logro.
		if prev > 0.0:
			Feats.mode_event("record_3", Feats.progress("record_3") + 1)
		if Online.available() and Online.alias() != "":
			Online.submit(LB_BASE + i, to_score(snappedf(t, 0.1)))
	return {"time": t, "best": snappedf(t, 0.1) if rec else prev, "record": rec, "prev": prev}


## 0:41.3 (o "--:--" si aun no hay tiempo).
static func fmt(t: float) -> String:
	if t <= 0.0:
		return "--:--"
	var m: int = int(t) / 60
	return "%d:%04.1f" % [m, t - float(m * 60)]


## El tiempo del nivel del juego que contiene a host (contrato: time_in_level).
static func game_time(host: Node) -> float:
	var n: Node = host
	while n != null:
		if "time_in_level" in n:
			return float(n.get("time_in_level"))
		n = n.get_parent()
	return 0.0


static func result_text(info: Dictionary) -> String:
	var s: String = Kit.text("ta_time", "Tiempo {t}").format({"t": fmt(float(info.get("time", 0.0)))})
	if bool(info.get("record", false)):
		return s + "  \u00b7  " + Kit.text("ta_record", "\u00a1Nuevo r\u00e9cord!")
	return s + "  \u00b7  " + Kit.text("ta_best", "R\u00e9cord {b}").format({"b": fmt(float(info.get("best", 0.0)))})


static func make_banner() -> CanvasLayer:
	var b: TimeBanner = TimeBanner.new()
	b.name = "TimeBanner"
	return b

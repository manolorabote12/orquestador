extends Node
## Audio: efectos con variacion de tono (para que no suenen repetidos) y musica con fundido.
## Autoload "Audio". Los sonidos se registran por nombre: Audio.register("coin", preload(...)).

const POOL_SIZE: int = 12
const UI_SOUNDS: Array[String] = ["ui_tap", "ui_big", "ui_open", "ui_close", "ui_coin", "ui_reward", "ui_swoosh", "ui_error", "ui_tick", "ui_pop"]
const RATE: int = 22050

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music: AudioStreamPlayer
var _music_tween: Tween
var _voice: AudioStreamPlayer
var last_voice: String = ""
var _lowpass: AudioEffectLowPassFilter
var _filter_tween: Tween
var _intensity: float = 1.0
var _muffled: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in POOL_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_music.bus = _music_bus()
	_voice = AudioStreamPlayer.new()
	_voice.name = "Voice"
	add_child(_voice)
	## 3 - Efectos generados por la fabrica (assets/manifest.json -> sfx).
	var sfx: Dictionary = Kit.assets.get("sfx", {})
	for sound_name: String in sfx.keys():
		var stream: AudioStream = load(str(sfx[sound_name])) as AudioStream
		if stream != null:
			register(sound_name, stream)
	## 9 - Sonidos de interfaz hechos aqui mismo (si la fabrica no trae los suyos): todos los juegos
	##     suenan al tocar, abrir, cerrar, contar monedas o cobrar un premio.
	for ui_name: String in UI_SOUNDS:
		if not _streams.has(ui_name):
			register(ui_name, synth_ui(ui_name))


func register(sound_name: String, stream: AudioStream) -> void:
	_streams[sound_name] = stream


## 1 - Reproduce un efecto. Si no esta registrado no falla: queda anotado para QA.
func play(sound_name: String, pitch_jitter: float = 0.08, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(sound_name):
		QA.log_event("sfx_missing", {"name": sound_name})
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _streams[sound_name]
	p.pitch_scale = pitch + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db + linear_to_db(float(Save.get_setting("sfx", 1.0)))
	p.play()


## 2 - Cambia de musica con fundido cruzado sencillo.
func play_music(stream: AudioStream, fade: float = 0.6) -> void:
	if _music.stream == stream and _music.playing:
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	var target_db: float = linear_to_db(maxf(float(Save.get_setting("music", 0.8)), 0.001))
	_music.stream = stream
	_music.volume_db = -40.0
	_music.play()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", target_db, fade)


func stop_music(fade: float = 0.4) -> void:
	if not _music.playing:
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -40.0, fade)
	_music_tween.tween_callback(_music.stop)


## 4 - Aplica el volumen de musica de los ajustes al momento (deslizador).
func apply_music_volume() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music.volume_db = linear_to_db(maxf(float(Save.get_setting("music", 0.8)), 0.001))


## 5 - Pistas de musica de la fabrica (assets/manifest.json -> "musica": menu, nivel, victoria).
## Si el juego no tiene musica no pasa nada: se queda en silencio.
func play_track(track: String, loop: bool = true) -> void:
	var tracks: Dictionary = Kit.assets.get("musica", {})
	if not tracks.has(track):
		return
	var stream: AudioStream = load(str(tracks[track])) as AudioStream
	if stream == null:
		QA.log_event("music_missing", {"track": track})
		return
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		if loop:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
		else:
			wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
		stream = wav
	elif stream is AudioStreamOggVorbis:
		## 6 - Musica con IA (ACE-Step en RunPod): OGG ya cortado para que el bucle no se note.
		var ogg: AudioStreamOggVorbis = (stream as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
		ogg.loop = loop
		ogg.loop_offset = 0.0
		stream = ogg
	play_music(stream, 0.5)


func current_music() -> AudioStream:
	return _music.stream if _music.playing else null


## 7 - Voz del heroe (assets/manifest.json -> "voces": inicio, victoria, derrota). Sin voz, nada.
## La musica baja un poco mientras habla, para que se entienda.
func play_voice(event: String) -> void:
	var voices: Dictionary = Kit.assets.get("voces", {})
	if not voices.has(event):
		return
	var stream: AudioStream = load(str(voices[event])) as AudioStream
	if stream == null:
		QA.log_event("voice_missing", {"event": event})
		return
	last_voice = event
	_voice.stream = stream
	_voice.volume_db = linear_to_db(maxf(float(Save.get_setting("sfx", 1.0)), 0.001))
	_voice.play()
	QA.log_event("voice", {"event": event})
	if _music_tween != null and _music_tween.is_running():
		return
	_music.volume_db = linear_to_db(maxf(float(Save.get_setting("music", 0.8)), 0.001)) - 8.0
	get_tree().create_timer(stream.get_length() + 0.1, true, false, true).timeout.connect(_restore_music_volume)


func _restore_music_volume() -> void:
	if _music_tween != null and _music_tween.is_running():
		return
	_music.volume_db = linear_to_db(maxf(float(Save.get_setting("music", 0.8)), 0.001))


## 8 - Bus propio de la musica con un filtro: la musica "respira" con la partida. Calma o peligro
## lejos: suena apagada; a tope: abierta y brillante. En pausa y en los paneles, como tras un cristal.
func _music_bus() -> String:
	var idx: int = AudioServer.get_bus_index("Musica")
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Musica")
		AudioServer.set_bus_send(idx, "Master")
		_lowpass = AudioEffectLowPassFilter.new()
		_lowpass.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(idx, _lowpass)
	else:
		_lowpass = AudioServer.get_bus_effect(idx, 0) as AudioEffectLowPassFilter
	return "Musica"


## Intensidad de 0 (calma) a 1 (a tope). La llaman los juegos (noche, zona, pila alta...).
func set_intensity(value: float) -> void:
	var v: float = clampf(value, 0.0, 1.0)
	if absf(v - _intensity) < 0.03:
		return
	_intensity = v
	_apply_filter(0.8)


## Musica tras un cristal (pausa, paneles). Se cuenta: cada muffle(true) con su muffle(false).
func muffle(on: bool) -> void:
	_muffled = maxi(0, _muffled + (1 if on else -1))
	_apply_filter(0.25)


func cutoff() -> float:
	return _lowpass.cutoff_hz if _lowpass != null else 20000.0


func _apply_filter(seconds: float) -> void:
	if _lowpass == null:
		return
	var target: float = 650.0 if _muffled > 0 else lerpf(1500.0, 20000.0, pow(_intensity, 1.6))
	if _filter_tween != null and _filter_tween.is_valid():
		_filter_tween.kill()
	_filter_tween = create_tween()
	_filter_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_filter_tween.tween_property(_lowpass, "cutoff_hz", target, seconds).set_trans(Tween.TRANS_SINE)


## 10 - Sintetiza un sonido de interfaz corto (PCM de 16 bits). Cada uno con su caracter:
##      toque seco, boton grande con golpe grave, abrir que sube, cerrar que baja, moneda, premio
##      en arpegio, barrido de aire, error grave y tic de contador.
func synth_ui(kind: String) -> AudioStreamWAV:
	var notes: Array = []
	var dur: float = 0.1
	var noise: float = 0.0
	match kind:
		"ui_tap":
			dur = 0.07
			notes = [[0.0, 0.07, 980.0, 640.0, 0.55]]
			noise = 0.08
		"ui_big":
			dur = 0.24
			notes = [[0.0, 0.2, 523.0, 500.0, 0.42], [0.0, 0.2, 784.0, 760.0, 0.32], [0.0, 0.12, 140.0, 70.0, 0.7]]
			noise = 0.05
		"ui_open":
			dur = 0.18
			notes = [[0.0, 0.18, 420.0, 1040.0, 0.45]]
		"ui_close":
			dur = 0.16
			notes = [[0.0, 0.16, 900.0, 330.0, 0.45]]
		"ui_coin":
			dur = 0.22
			notes = [[0.0, 0.1, 1320.0, 1320.0, 0.4], [0.07, 0.15, 1760.0, 1760.0, 0.4]]
		"ui_reward":
			dur = 0.6
			notes = [[0.0, 0.16, 523.0, 523.0, 0.36], [0.08, 0.16, 659.0, 659.0, 0.36], [0.16, 0.16, 784.0, 784.0, 0.36], [0.24, 0.36, 1046.0, 1046.0, 0.4]]
			noise = 0.02
		"ui_swoosh":
			dur = 0.28
			noise = 0.6
		"ui_error":
			dur = 0.24
			notes = [[0.0, 0.09, 190.0, 170.0, 0.5], [0.12, 0.1, 160.0, 140.0, 0.5]]
		"ui_tick":
			dur = 0.03
			notes = [[0.0, 0.03, 2100.0, 1900.0, 0.35]]
		_:
			dur = 0.1
			notes = [[0.0, 0.1, 700.0, 1200.0, 0.5]]
	var n: int = int(dur * float(RATE))
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var low: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		var v: float = 0.0
		for nt: Array in notes:
			var t0: float = float(nt[0])
			var d: float = float(nt[1])
			if t < t0 or t > t0 + d:
				continue
			var u: float = (t - t0) / d
			var f: float = lerpf(float(nt[2]), float(nt[3]), u)
			## Ataque rapido y caida suave; un poco de segundo armonico para que brille.
			var env: float = minf(1.0, (t - t0) / 0.004) * pow(1.0 - u, 2.2)
			var ph: float = TAU * f * (t - t0)
			v += (sin(ph) + 0.25 * sin(ph * 2.0)) * env * float(nt[4])
		if noise > 0.0:
			var env2: float = sin(PI * clampf(t / dur, 0.0, 1.0)) if kind == "ui_swoosh" else pow(1.0 - t / dur, 6.0)
			## Ruido filtrado (mas brillante a mitad del barrido).
			var k: float = 0.08 + 0.5 * env2
			low = lerpf(low, rng.randf_range(-1.0, 1.0), k)
			v += low * env2 * noise
		var sample: int = clampi(int(v * 0.8 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, sample)
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

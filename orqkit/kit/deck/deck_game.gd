extends Node2D
## Mazo: combates de cartas (estilo Slay the Spire). Reglas en deck_map.gd.
## 1 - Toca una carta de la mano para jugarla (si tienes energia). "Terminar turno" pasa al enemigo.
## 2 - Encima del enemigo esta su intencion: espada = va a atacar (numero x veces), escudo =
##     bloqueara, brazo = se hace mas fuerte, calavera = te envenena, flecha abajo = te debilita.
## 3 - Tras cada combate eliges una carta nueva (o saltas) y te curas un poco. Gana todos.
## 4 - Estrellas: 3 si ganas en los turnos del par o menos (con margen), 2 si ganas, 1 si mueres antes.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/deck/deck_map.gd")
const NAMES: Dictionary = {"golpe": "Golpe", "defensa": "Defensa", "tajo_doble": "Tajo doble", "golpe_pesado": "Golpe pesado",
	"rafaga": "R\u00e1faga", "muro": "Muro", "espinas": "Espinas", "veneno": "Veneno", "nube_toxica": "Nube t\u00f3xica",
	"debilitar": "Debilitar", "concentracion": "Concentraci\u00f3n", "curar": "Curar", "energia": "Energ\u00eda", "furia": "Furia",
	"armadura": "Armadura", "tajo_vampiro": "Tajo vampiro"}
const ENEMY_NAMES: Dictionary = {"slime": "Slime", "bandido": "Bandido", "caballero": "Caballero negro", "bruja": "Bruja",
	"golem": "G\u00f3lem", "dragon": "Drag\u00f3n"}
const TYPE_COLORS: Dictionary = {"attack": Color("#c0503a"), "skill": Color("#3f7ac0"), "power": Color("#8a5ab0")}

var level: Dictionary = {}
var run: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
var par: int = 0

var _font: Font
var _world: Node2D
var _camera: Camera2D
var _hand: HBoxContainer
var _end_btn: Button
var _energy: Label
var _piles: Label
var _fight_label: Label
var _toast: Label
var _toast_t: float = 0.0
var _reward_panel: PanelContainer
var _reward_box: HBoxContainer
var _enemy_art: AnimatedSprite2D
var _hero_art: AnimatedSprite2D
var _shake_e: float = 0.0
var _shake_h: float = 0.0
var _nums: Array[Dictionary] = []
var _last_ehp: int = 0
var _last_hp: int = 0
var _sig: String = ""
var _t: float = 0.0


## Carta dibujada: marco por tipo, coste, nombre, dibujo y texto.
class CardView:
	extends Button
	var card: String = ""
	var title: String = ""
	var desc: String = ""
	var cost: int = 0
	var kind: String = "attack"
	var col: Color = Color.GRAY
	var playable: bool = true
	var font: Font

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var a: float = 1.0 if playable else 0.55
		draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.35))
		draw_rect(r, Color(col.darkened(0.35), a))
		draw_rect(r.grow(-5.0), Color("#f4ead2", a))
		var art_h: float = r.size.y * 0.33
		draw_rect(Rect2(Vector2(10, 38), Vector2(r.size.x - 20.0, art_h)), Color(col.lightened(0.25), a))
		_icon(Vector2(r.size.x * 0.5, 38.0 + art_h * 0.5), a)
		draw_circle(Vector2(18, 18), 17.0, Color("#2a2a3a", a))
		draw_circle(Vector2(18, 18), 14.0, Color("#ffd23f", a) if playable else Color("#999999", a))
		_text(Vector2(18, 26), str(cost), 22, Color("#2a2a3a"))
		## Titulo a la derecha del coste (sin pisarlo): la letra baja hasta que cabe.
		var tw: float = r.size.x - 44.0
		var ts: int = 20
		while ts > 13 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x > tw:
			ts -= 1
		_text(Vector2(38.0 + tw * 0.5, 27), title, ts, Color("#2a1c12"))
		## Descripcion: letra legible y oscura; si no cabe, un punto menos.
		var top: float = 38.0 + art_h + 24.0
		var ds: int = 18
		var lines: PackedStringArray = _wrap(desc, r.size.x - 14.0, ds)
		while ds > 14 and top + float(lines.size() - 1) * float(ds + 3) > r.size.y - 10.0:
			ds -= 1
			lines = _wrap(desc, r.size.x - 14.0, ds)
		for i: int in lines.size():
			_text(Vector2(r.size.x * 0.5, top + float(i) * float(ds + 3)), lines[i], ds, Color("#24180e"))

	func _text(at: Vector2, s: String, sz: int, c: Color) -> void:
		var wd: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		draw_string(font, at - Vector2(wd * 0.5, 0.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)

	func _wrap(s: String, width: float, sz: int) -> PackedStringArray:
		var out: PackedStringArray = PackedStringArray()
		var line: String = ""
		for w: String in s.split(" "):
			var t: String = w if line == "" else line + " " + w
			if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > width and line != "":
				out.append(line)
				line = w
			else:
				line = t
		if line != "":
			out.append(line)
		return out

	func _icon(c: Vector2, a: float) -> void:
		var steel: Color = Color("#d8dde6", a)
		match kind:
			"attack":
				draw_line(c + Vector2(-18, 18), c + Vector2(16, -16), steel, 7.0)
				draw_line(c + Vector2(-20, 8), c + Vector2(-8, 20), Color("#8a5a2b", a), 6.0)
				if card in ["tajo_doble", "rafaga"]:
					draw_line(c + Vector2(-4, 18), c + Vector2(26, -12), steel, 5.0)
				if card == "tajo_vampiro":
					draw_circle(c + Vector2(14, 14), 6.0, Color("#e0304a", a))
			"skill":
				if card in ["veneno", "nube_toxica"]:
					draw_circle(c, 14.0, Color("#5fd05a", a))
					draw_circle(c + Vector2(-5, -4), 3.0, Color("#1a1a1a", a))
					draw_circle(c + Vector2(5, -4), 3.0, Color("#1a1a1a", a))
				elif card in ["curar"]:
					draw_rect(Rect2(c - Vector2(6, 16), Vector2(12, 32)), Color("#e0304a", a))
					draw_rect(Rect2(c - Vector2(16, 6), Vector2(32, 12)), Color("#e0304a", a))
				elif card in ["concentracion", "energia"]:
					draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -18), c + Vector2(8, -2), c + Vector2(0, -2), c + Vector2(4, 18),
						c + Vector2(-8, 0), c + Vector2(0, 0)]), Color("#ffd23f", a))
				else:
					draw_colored_polygon(PackedVector2Array([c + Vector2(-16, -16), c + Vector2(16, -16), c + Vector2(14, 6), c + Vector2(0, 20),
						c + Vector2(-14, 6)]), steel)
			"power":
				draw_circle(c, 16.0, Color("#ffb03a", a))
				draw_circle(c, 9.0, Color("#fff1a6", a))


var _hint_btn: Button

func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#1a1626"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	var hero_entry: Dictionary = Kit.sprite_by_role("jugador")
	if not hero_entry.is_empty():
		_hero_art = SpriteKit.animado(hero_entry, 150.0, "idle", false)
		add_child(_hero_art)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_camera.position = Vector2(360, 640)
	Juice.register_camera(_camera)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "deck", "fights": (run["fights"] as Array).size()})


func bot_script() -> String:
	return "res://qa/deck_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(4.0, 3.0)


func _reset() -> void:
	Hint.reset(self)
	finished = false
	failed = false
	time_in_level = 0.0
	run = MapRules.new_run(level)
	par = int(level.get("par", 0))
	coins_total = (run["fights"] as Array).size()
	coins = 0
	_nums.clear()
	_sig = ""
	_make_enemy_art()
	_last_ehp = int(run["f"]["ehp"])
	_last_hp = int(run["hp"])
	_refresh()


func _make_enemy_art() -> void:
	if _enemy_art != null:
		_enemy_art.queue_free()
		_enemy_art = null
	var kind: String = str(run["f"]["enemy"])
	var entry: Dictionary = {}
	if kind == "dragon":
		var id: String = str(Kit.param("art.enemies.boss", ""))
		entry = Kit.sprite_entry(id) if id != "" else {}
	if entry.is_empty():
		entry = Kit.sprite_by_role("enemigo")
	if entry.is_empty():
		return
	_enemy_art = SpriteKit.animado(entry, 230.0 if kind != "dragon" else 300.0, "idle", false)
	var tints: Dictionary = {"slime": Color(0.8, 1.0, 0.8), "bandido": Color(1, 1, 1), "caballero": Color(0.7, 0.7, 0.85),
		"bruja": Color(0.9, 0.75, 1.0), "golem": Color(0.75, 0.75, 0.75), "dragon": Color(1, 1, 1)}
	_enemy_art.modulate = tints.get(kind, Color.WHITE)
	_enemy_art.flip_h = true
	add_child(_enemy_art)


# ------------------------------------------------------------------ interfaz

func _build_hud() -> void:
	var hud: CanvasLayer = CanvasLayer.new()
	hud.name = "Hud"
	hud.layer = 20
	add_child(hud)
	var root: Control = Control.new()
	root.theme = UI.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var safe: MarginContainer = UI.safe_root(root, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_fight_label = Label.new()
	_fight_label.name = "Fight"
	_fight_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fight_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_fight_label.add_theme_constant_override("outline_size", 6)
	top.add_child(_fight_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	## Pista: la jugada que haria el bot (la primera gratis; despues anuncio o monedas).
	if not Kit.versus:
		_hint_btn = Hint.make_button(self, use_hint)
		_hint_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		top.add_child(_hint_btn)
		top.move_child(_hint_btn, pause_btn.get_index())
	_toast = Label.new()
	_toast.name = "Toast"
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_color_override("font_color", Kit.color("accent", Color("#ffd23f")))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 7)
	col.add_child(_toast)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	_energy = Label.new()
	_energy.name = "Energy"
	_energy.add_theme_font_size_override("font_size", 40)
	_energy.add_theme_color_override("font_color", Color("#ffd23f"))
	_energy.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_energy.add_theme_constant_override("outline_size", 8)
	row.add_child(_energy)
	_piles = Label.new()
	_piles.name = "Piles"
	_piles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_piles.add_theme_font_size_override("font_size", 24)
	_piles.add_theme_color_override("font_color", (UI.colors["texto_suave"] as Color).lightened(0.25))
	row.add_child(_piles)
	_end_btn = UI.make_button(Kit.text("deck_end_turn", "Terminar turno"), true, "")
	_end_btn.name = "BtnEndTurn"
	_end_btn.pressed.connect(end_turn)
	row.add_child(_end_btn)
	_hand = HBoxContainer.new()
	_hand.name = "Hand"
	_hand.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand.custom_minimum_size = Vector2(0, 230)
	col.add_child(_hand)
	## Recompensa tras cada combate.
	_reward_panel = PanelContainer.new()
	_reward_panel.name = "Reward"
	_reward_panel.visible = false
	_reward_panel.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(_reward_panel)
	var rv: VBoxContainer = VBoxContainer.new()
	rv.add_theme_constant_override("separation", 12)
	_reward_panel.add_child(rv)
	var rt: Label = Label.new()
	rt.text = Kit.text("deck_reward", "\u00a1Victoria! Elige una carta para tu mazo")
	rt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.custom_minimum_size = Vector2(560, 0)
	rv.add_child(rt)
	_reward_box = HBoxContainer.new()
	_reward_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_reward_box.add_theme_constant_override("separation", 12)
	rv.add_child(_reward_box)
	var skip: Button = UI.make_button(Kit.text("deck_skip", "Saltar"), false, "")
	skip.name = "BtnSkip"
	skip.pressed.connect(pick_reward.bind(-1))
	rv.add_child(skip)


func card_name(c: String) -> String:
	return Kit.text("deck_card_" + c, str(NAMES.get(c, c)))


func describe(c: String) -> String:
	var d: Dictionary = MapRules.CARDS[c]
	var parts: Array[String] = []
	if d.has("dmg"):
		var dmg: int = MapRules.card_damage(run, c) if not run.is_empty() and run.has("f") else int(d["dmg"])
		var t: String = Kit.text("deck_d_dmg", "Inflige {n}").format({"n": dmg})
		if int(d.get("hits", 1)) > 1:
			t += " x%d" % int(d["hits"])
		parts.append(t)
	if d.has("block"):
		parts.append(Kit.text("deck_d_block", "Bloquea {n}").format({"n": int(d["block"])}))
	if d.has("thorns"):
		parts.append(Kit.text("deck_d_thorns", "Espinas {n}").format({"n": int(d["thorns"])}))
	if d.has("poison"):
		parts.append(Kit.text("deck_d_poison", "Envenena {n}").format({"n": int(d["poison"])}))
	if d.has("weak"):
		parts.append(Kit.text("deck_d_weak", "Debilita {n} turnos").format({"n": int(d["weak"])}))
	if d.has("draw"):
		parts.append(Kit.text("deck_d_draw", "Roba {n} cartas").format({"n": int(d["draw"])}))
	if d.has("heal"):
		parts.append(Kit.text("deck_d_heal", "Cura {n}").format({"n": int(d["heal"])}))
	if d.has("energy"):
		parts.append(Kit.text("deck_d_energy", "+{n} de energ\u00eda").format({"n": int(d["energy"])}))
	if d.has("strength"):
		parts.append(Kit.text("deck_d_str", "+{n} de fuerza todo el combate").format({"n": int(d["strength"])}))
	if d.has("plating"):
		parts.append(Kit.text("deck_d_plating", "Bloquea {n} cada turno").format({"n": int(d["plating"])}))
	if bool(d.get("lifesteal", false)):
		parts.append(Kit.text("deck_d_lifesteal", "Te curas lo que da\u00f1es"))
	if bool(d.get("exhaust", false)):
		parts.append(Kit.text("deck_d_exhaust", "Se agota"))
	return ". ".join(parts)


func _card_view(c: String, playable: bool, w: float) -> CardView:
	var v: CardView = CardView.new()
	v.card = c
	v.title = card_name(c)
	v.desc = describe(c)
	v.cost = int(MapRules.CARDS[c]["cost"])
	v.kind = str(MapRules.CARDS[c]["type"])
	v.col = TYPE_COLORS.get(v.kind, Color.GRAY)
	v.playable = playable
	v.font = _font
	v.custom_minimum_size = Vector2(w, w * 1.55)
	v.flat = true
	v.focus_mode = Control.FOCUS_NONE
	return v


func _toast_now(t: String) -> void:
	_toast.text = t
	_toast_t = 2.2


func _refresh() -> void:
	if _hint_btn != null:
		_hint_btn.text = Hint.label(self)
	if run.is_empty() or _hand == null:
		return
	var f: Dictionary = run["f"]
	_fight_label.text = Kit.text("deck_fight", "Combate {a}/{b}").format({"a": int(run["fight"]) + 1, "b": (run["fights"] as Array).size()}) + \
		"  \u00b7  " + Kit.text("deck_turn", "Turno {n}").format({"n": int(f["turn"])})
	_energy.text = "%d/3" % int(f["energy"])
	_piles.text = Kit.text("deck_piles", "Mazo {a} \u00b7 Descartes {b}").format({"a": (f["draw"] as Array).size(), "b": (f["discard"] as Array).size()})
	var sig: String = str(f["hand"]) + str(f["energy"]) + str(run["reward"]) + str(f["str"]) + str(f["weak"])
	if sig == _sig:
		return
	_sig = sig
	for c: Node in _hand.get_children():
		_hand.remove_child(c)
		c.queue_free()
	var hand: Array = f["hand"]
	var w: float = 132.0
	_hand.add_theme_constant_override("separation", 6 if hand.size() <= 5 else int(-(float(hand.size()) * w - 690.0) / float(hand.size() - 1)))
	for i: int in hand.size():
		var v: CardView = _card_view(str(hand[i]), MapRules.can_play(run, i), w)
		v.name = "Card_%d" % i
		v.pressed.connect(play_card.bind(i))
		_hand.add_child(v)
	var rw: Array = run["reward"]
	_reward_panel.visible = not rw.is_empty()
	for c: Node in _reward_box.get_children():
		_reward_box.remove_child(c)
		c.queue_free()
	for i: int in rw.size():
		var rv: CardView = _card_view(str(rw[i]), true, 170.0)
		rv.name = "Reward_%d" % i
		rv.pressed.connect(pick_reward.bind(i))
		_reward_box.add_child(rv)
	if _reward_panel.visible:
		_reward_panel.reset_size()
		_reward_panel.position = (get_viewport_rect().size - _reward_panel.size) * 0.5
	_end_btn.disabled = not rw.is_empty()


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func play_card(i: int) -> bool:
	if not can_act():
		return false
	var hand: Array = run["f"]["hand"]
	if i < 0 or i >= hand.size():
		return false
	var c: String = str(hand[i])
	if not MapRules.play(run, i):
		if not fast:
			_toast_now(Kit.text("deck_no_energy", "No te queda energ\u00eda"))
		return false
	if not fast:
		Audio.play("jump" if str(MapRules.CARDS[c]["type"]) == "attack" else "click", 0.1, -4.0)
	_after()
	return true


func end_turn() -> void:
	if not can_act():
		return
	MapRules.end_turn(run)
	if not fast:
		Audio.play("hurt", 0.1, -8.0)
	_after()


func pick_reward(i: int) -> void:
	if (run["reward"] as Array).is_empty():
		return
	coins += 1
	MapRules.pick_reward(run, i)
	_make_enemy_art()
	_last_ehp = int(run["f"]["ehp"])
	if not fast:
		Audio.play("powerup")
		_toast_now(Kit.text("deck_next", "\u00a1Aparece {e}!").format({"e": enemy_name(str(run["f"]["enemy"]))}))
	_after()


func enemy_name(k: String) -> String:
	return Kit.text("deck_enemy_" + k, str(ENEMY_NAMES.get(k, k)))


## Numeros de dano y temblores segun lo que haya cambiado.
func _after() -> void:
	var f: Dictionary = run["f"]
	var ehp: int = int(f["ehp"])
	var hp: int = int(run["hp"])
	if ehp < _last_ehp:
		_nums.append({"at": Vector2(360, 330), "text": "-%d" % (_last_ehp - ehp), "t": 0.8, "col": Color("#ffdd66")})
		_shake_e = 0.25
	if hp < _last_hp:
		_nums.append({"at": Vector2(170, 700), "text": "-%d" % (_last_hp - hp), "t": 0.8, "col": Color("#ff6b5b")})
		_shake_h = 0.25
		if not fast:
			Juice.shake(0.1)
	elif hp > _last_hp:
		_nums.append({"at": Vector2(170, 700), "text": "+%d" % (hp - _last_hp), "t": 0.8, "col": Color("#9ff0a8")})
	_last_ehp = ehp
	_last_hp = hp
	if run["won"]:
		coins = coins_total
		_finish()
		return
	if run["lost"]:
		_lose()
		return
	_refresh()


## Pista: el siguiente movimiento lo hace el bot por ti (cuenta como tu jugada).
func use_hint() -> void:
	if not can_act():
		return
	if not await Hint.pay(self):
		Hint.say(self, Kit.text("hint_no_coins", "Te faltan monedas para la pista"))
		return
	if is_inside_tree() and can_act():
		bot_step()
	_refresh()


func bot_step() -> void:
	if not (run["reward"] as Array).is_empty():
		pick_reward(MapRules.bot_pick(run))
		return
	var c: int = MapRules.bot_choice(run)
	if c >= 0:
		play_card(c)
	else:
		end_turn()


# ------------------------------------------------------------------ bucle

func _process(delta: float) -> void:
	if finished:
		return
	time_in_level += delta
	_t += delta
	_shake_e = maxf(0.0, _shake_e - delta)
	_shake_h = maxf(0.0, _shake_h - delta)
	var keep: Array[Dictionary] = []
	for n: Dictionary in _nums:
		n["t"] = float(n["t"]) - delta
		if float(n["t"]) > 0.0:
			keep.append(n)
	_nums = keep
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.text = ""
	if _enemy_art != null:
		_enemy_art.position = Vector2(360 + sin(_shake_e * 60.0) * 12.0 * _shake_e * 4.0, 340 + sin(_t * 2.0) * 6.0)
	if _hero_art != null:
		_hero_art.position = Vector2(170 + sin(_shake_h * 60.0) * 10.0 * _shake_h * 4.0, 680)
	_world.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(0, 5000 - int(run["turns"]) * 60) + int(run["hp"]) * 40
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "turns": int(run["turns"]), "hp": int(run["hp"]), "deaths": deaths})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 0:
		return 1
	return 3 if par <= 0 or int(run["turns"]) <= int(ceil(float(par) * 1.3)) else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "deck", "fight": int(run["fight"]), "turns": int(run["turns"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("deck_lost", "\u00a1Derrota!"),
		Kit.text("deck_fail_hint", "Mira la intenci\u00f3n del enemigo: si va a atacar fuerte, bloquea; si no, ataca con todo."))
	p.closed.connect(retry)


func retry() -> void:
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"pos": Vector2(float(run.get("fight", 0)), float(run.get("hp", 0))), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "turns": int(run.get("turns", 0)), "hp": int(run.get("hp", 0))}


# ------------------------------------------------------------------ dibujo

func _text(at: Vector2, s: String, size: int, col: Color) -> void:
	var wd: float = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p: Vector2 = at - Vector2(wd * 0.5, 0.0)
	for o: Vector2 in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		_world.draw_string(_font, p + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.85))
	_world.draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _bar(c: Vector2, w: float, v: int, mx: int, block: int, col: Color) -> void:
	var r: Rect2 = Rect2(c - Vector2(w * 0.5, 0), Vector2(w, 22))
	_world.draw_rect(r, Color(0, 0, 0, 0.6))
	_world.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2((w - 4.0) * clampf(float(v) / float(maxi(mx, 1)), 0.0, 1.0), 18)), col)
	_text(c + Vector2(0, 18), "%d/%d" % [maxi(v, 0), mx], 18, Color.WHITE)
	if block > 0:
		var sp: Vector2 = r.position + Vector2(-26, 11)
		_world.draw_colored_polygon(PackedVector2Array([sp + Vector2(-16, -14), sp + Vector2(16, -14), sp + Vector2(14, 4), sp + Vector2(0, 16),
			sp + Vector2(-14, 4)]), Color("#7fb0e8"))
		_text(sp + Vector2(0, 6), str(block), 18, Color.WHITE)


func _status(at: Vector2, f: Dictionary, prefix: String) -> void:
	var items: Array = []
	var s_key: String = "estr" if prefix == "e" else "str"
	if int(f[s_key]) > 0:
		items.append([Color("#ff8a3c"), "F%d" % int(f[s_key])])
	if int(f[prefix + "poison" if prefix == "e" else "poison"]) > 0:
		items.append([Color("#5fd05a"), "V%d" % int(f[prefix + "poison" if prefix == "e" else "poison"])])
	if int(f[prefix + "weak" if prefix == "e" else "weak"]) > 0:
		items.append([Color("#b0b0c0"), "D%d" % int(f[prefix + "weak" if prefix == "e" else "weak"])])
	if prefix != "e" and int(f["plating"]) > 0:
		items.append([Color("#7fb0e8"), "A%d" % int(f["plating"])])
	if prefix != "e" and int(f["thorns"]) > 0:
		items.append([Color("#c0a060"), "E%d" % int(f["thorns"])])
	for i: int in items.size():
		var p: Vector2 = at + Vector2(float(i) * 54.0 - float(items.size() - 1) * 27.0, 0)
		_world.draw_circle(p, 22.0, items[i][0])
		_text(p + Vector2(0, 7), str(items[i][1]), 18, Color("#1a1a1a"))


func _draw_world() -> void:
	if run.is_empty():
		return
	var f: Dictionary = run["f"]
	## Fondo: suelo de piedra y luz de antorchas.
	_world.draw_rect(Rect2(-100, -100, 920, 1480), Color("#211b30"))
	for k: int in 8:
		_world.draw_rect(Rect2(-100, 520.0 + float(k) * 26.0, 920, 26), Color("#2c2440").lerp(Color("#3a3050"), float(k) / 8.0))
	for x: float in [90.0, 630.0]:
		_world.draw_circle(Vector2(x, 210), 60.0 + sin(_t * 7.0 + x) * 4.0, Color(1.0, 0.6, 0.2, 0.12))
		_world.draw_circle(Vector2(x, 210), 9.0, Color("#ffcf5a"))
	## Enemigo.
	var kind: String = str(f["enemy"])
	var ep: Vector2 = Vector2(360 + sin(_shake_e * 60.0) * 12.0 * _shake_e * 4.0, 340 + sin(_t * 2.0) * 6.0)
	_world.draw_set_transform(Vector2(ep.x, 470), 0.0, Vector2(1.0, 0.25))
	_world.draw_circle(Vector2.ZERO, 120.0, Color(0, 0, 0, 0.35))
	_world.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _enemy_art == null:
		_draw_enemy(kind, ep)
	_text(Vector2(360, 166), enemy_name(kind), 28, Color.WHITE)
	_bar(Vector2(360, 480), 260.0, int(f["ehp"]), int(f["emax"]), int(f["eblock"]), Color("#e0404a"))
	_status(Vector2(360, 540), f, "e")
	_draw_intent(Vector2(360, 200))
	## Heroe.
	var hp: Vector2 = Vector2(170 + sin(_shake_h * 60.0) * 10.0 * _shake_h * 4.0, 680)
	if _hero_art == null:
		_world.draw_circle(hp, 52.0, Kit.color("accent", Color("#3f8cff")))
		_world.draw_circle(hp + Vector2(0, -16), 26.0, Color("#f1c9a0"))
	_bar(Vector2(420, 650), 300.0, int(run["hp"]), int(run["max_hp"]), int(f["block"]), Color("#56d36a"))
	_status(Vector2(420, 712), f, "")
	for n: Dictionary in _nums:
		_text((n["at"] as Vector2) + Vector2(0, -50.0 * (0.8 - float(n["t"]))), str(n["text"]), 46, n["col"])


func _draw_intent(at: Vector2) -> void:
	var it: Array = MapRules.intent(run)
	var p: Vector2 = at + Vector2(0, sin(_t * 3.0) * 4.0)
	_world.draw_circle(p, 34.0, Color(0, 0, 0, 0.55))
	match str(it[0]):
		"atk", "blockatk":
			_world.draw_line(p + Vector2(-16, 16), p + Vector2(14, -14), Color("#e8e8f0"), 7.0)
			_world.draw_line(p + Vector2(-18, 6), p + Vector2(-6, 18), Color("#8a5a2b"), 6.0)
			var n: int = int(it[1]) if str(it[0]) == "atk" else int(it[2])
			var times: int = int(it[2]) if str(it[0]) == "atk" else 1
			_text(p + Vector2(54, 10), str(n) + ("x%d" % times if times > 1 else ""), 30, Color("#ff6b5b"))
			if str(it[0]) == "blockatk":
				_world.draw_circle(p + Vector2(-44, 0), 14.0, Color("#7fb0e8"))
		"block", "blockstr":
			_world.draw_colored_polygon(PackedVector2Array([p + Vector2(-16, -16), p + Vector2(16, -16), p + Vector2(14, 6), p + Vector2(0, 20),
				p + Vector2(-14, 6)]), Color("#7fb0e8"))
			if str(it[0]) == "blockstr":
				_world.draw_circle(p + Vector2(40, 0), 12.0, Color("#ff8a3c"))
		"str":
			_world.draw_circle(p, 18.0, Color("#ff8a3c"))
			_text(p + Vector2(0, 8), "+F", 22, Color("#1a1a1a"))
		"poison":
			_world.draw_circle(p, 18.0, Color("#5fd05a"))
			_world.draw_circle(p + Vector2(-6, -4), 4.0, Color("#1a1a1a"))
			_world.draw_circle(p + Vector2(6, -4), 4.0, Color("#1a1a1a"))
		"weak":
			_world.draw_colored_polygon(PackedVector2Array([p + Vector2(-14, -8), p + Vector2(14, -8), p + Vector2(0, 16)]), Color("#b0b0c0"))


func _draw_enemy(kind: String, p: Vector2) -> void:
	match kind:
		"slime":
			var sq: float = 1.0 + sin(_t * 4.0) * 0.06
			_world.draw_set_transform(p + Vector2(0, 40), 0.0, Vector2(sq, 2.0 - sq))
			_world.draw_circle(Vector2.ZERO, 80.0, Color("#5ad16a"))
			_world.draw_circle(Vector2(-26, -20), 10.0, Color("#1a1a1a"))
			_world.draw_circle(Vector2(26, -20), 10.0, Color("#1a1a1a"))
			_world.draw_circle(Vector2(-30, -40), 16.0, Color(1, 1, 1, 0.35))
			_world.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"bandido", "caballero":
			var body: Color = Color("#6a4a3a") if kind == "bandido" else Color("#3a3a4a")
			_world.draw_rect(Rect2(p + Vector2(-50, -20), Vector2(100, 120)), body)
			_world.draw_circle(p + Vector2(0, -50), 40.0, Color("#f1c9a0") if kind == "bandido" else Color("#5a5a6a"))
			if kind == "bandido":
				_world.draw_rect(Rect2(p + Vector2(-40, -62), Vector2(80, 16)), Color("#2a2a2a"))
			else:
				_world.draw_rect(Rect2(p + Vector2(-30, -56), Vector2(60, 8)), Color("#1a1a1a"))
			_world.draw_line(p + Vector2(50, 60), p + Vector2(110, -40), Color("#d8dde6"), 8.0)
		"bruja":
			_world.draw_colored_polygon(PackedVector2Array([p + Vector2(-60, 100), p + Vector2(60, 100), p + Vector2(0, -30)]), Color("#5a3a7a"))
			_world.draw_circle(p + Vector2(0, -40), 32.0, Color("#9adf6a"))
			_world.draw_colored_polygon(PackedVector2Array([p + Vector2(-50, -60), p + Vector2(50, -60), p + Vector2(10, -140)]), Color("#2a1a3a"))
			_world.draw_circle(p + Vector2(-10, -42), 5.0, Color("#ffd23f"))
			_world.draw_circle(p + Vector2(10, -42), 5.0, Color("#ffd23f"))
		"golem":
			_world.draw_rect(Rect2(p + Vector2(-80, -60), Vector2(160, 160)), Color("#7d7f86"))
			_world.draw_rect(Rect2(p + Vector2(-80, -60), Vector2(160, 40)), Color("#9a9ca3"))
			_world.draw_circle(p + Vector2(-30, -10), 12.0, Color("#ffb03a"))
			_world.draw_circle(p + Vector2(30, -10), 12.0, Color("#ffb03a"))
		"dragon":
			var wing: float = sin(_t * 3.0) * 20.0
			_world.draw_colored_polygon(PackedVector2Array([p + Vector2(-40, -20), p + Vector2(-180, -100 + wing), p + Vector2(-120, 40)]), Color("#7a2a2a"))
			_world.draw_colored_polygon(PackedVector2Array([p + Vector2(40, -20), p + Vector2(180, -100 + wing), p + Vector2(120, 40)]), Color("#7a2a2a"))
			_world.draw_circle(p + Vector2(0, 20), 90.0, Color("#b03a3a"))
			_world.draw_circle(p + Vector2(0, -80), 50.0, Color("#c04a3a"))
			_world.draw_circle(p + Vector2(-18, -86), 8.0, Color("#ffd23f"))
			_world.draw_circle(p + Vector2(18, -86), 8.0, Color("#ffd23f"))

extends Node
## Juice: lo que hace que un juego "se sienta bien".
## Sacudida de camara por trauma, parada de impacto (hitstop), destello y vibracion.
## Autoload "Juice".

var camera: Camera2D = null
var trauma: float = 0.0
var max_offset: Vector2 = Vector2(18.0, 14.0)
var max_roll: float = 0.035
var decay: float = 1.6

var _noise: FastNoiseLite = FastNoiseLite.new()
var _time: float = 0.0
var _hitstop_left: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.seed = 7
	_noise.frequency = 2.2


func register_camera(cam: Camera2D) -> void:
	camera = cam


## 1 - Sacudida acumulativa: golpes pequenos 0.15, grandes 0.5. La intensidad crece al cuadrado.
func shake(amount: float) -> void:
	## Modo calma (Ajustes -> Accesibilidad): sin sacudidas de pantalla.
	if bool(Save.get_setting("calm", false)):
		return
	trauma = clampf(trauma + amount, 0.0, 1.0)


## 2 - Congela el juego unos milisegundos para dar peso a un impacto.
## Se descuenta con el tiempo real de cada frame (no con el reloj del sistema): asi funciona
## igual a 60 fps, con tirones o con los bots de QA a maxima velocidad.
func hitstop(seconds: float = 0.06, scale: float = 0.05) -> void:
	if seconds <= _hitstop_left:
		return
	_hitstop_left = seconds
	Engine.time_scale = scale


## 3 - Vibracion corta, solo en movil y si el jugador no la ha desactivado.
func vibrate(ms: int = 25) -> void:
	if not OS.has_feature("mobile"):
		return
	if not bool(Save.get_setting("haptics", true)):
		return
	Input.vibrate_handheld(ms)


## 4 - Destello de un CanvasItem (por ejemplo al recibir dano).
func flash(item: CanvasItem, tint: Color = Color(3, 3, 3, 1), seconds: float = 0.08) -> void:
	if item == null:
		return
	var original: Color = item.modulate
	item.modulate = tint
	var tween: Tween = item.create_tween()
	tween.tween_property(item, "modulate", original, seconds)


## 5 - Estirar y aplastar: salto (0.8, 1.2), aterrizaje (1.25, 0.8).
func squash(node: Node2D, amount: Vector2, seconds: float = 0.14) -> void:
	if node == null:
		return
	node.scale = amount
	var tween: Tween = node.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, seconds)


## 6 - Estallido de particulas (pisoton, golpe, recoger). Se borra solo al terminar.
## Acabado de estudio: trozos redondos que encogen y se apagan, chispas brillantes en modo
## aditivo y, en los golpes grandes, una onda expansiva.
func burst(parent: Node, at: Vector2, col: Color, amount: int = 12, speed: float = 260.0) -> void:
	if parent == null:
		return
	var fx: CPUParticles2D = CPUParticles2D.new()
	fx.position = at
	fx.one_shot = true
	fx.explosiveness = 0.95
	fx.amount = amount
	fx.lifetime = 0.5
	fx.direction = Vector2(0.0, -1.0)
	fx.spread = 80.0
	fx.initial_velocity_min = speed * 0.5
	fx.initial_velocity_max = speed
	fx.gravity = Vector2(0.0, 900.0)
	fx.damping_min = 40.0
	fx.damping_max = 90.0
	fx.texture = dot_texture()
	fx.scale_amount_min = 0.28
	fx.scale_amount_max = 0.55
	fx.scale_amount_curve = _shrink_curve()
	fx.color = col
	fx.color_ramp = _fade_ramp(col)
	fx.z_index = 20
	parent.add_child(fx)
	fx.emitting = true
	fx.finished.connect(fx.queue_free)
	if amount >= 8:
		sparkle(parent, at, col.lerp(Color.WHITE, 0.6), maxi(4, amount / 2), speed * 0.8)
	if amount >= 14:
		ring(parent, at, col.lerp(Color.WHITE, 0.4), 30.0 + speed * 0.22)


## 6b - Chispas en estrella que giran y brillan (aditivas).
func sparkle(parent: Node, at: Vector2, col: Color, amount: int = 6, speed: float = 200.0) -> void:
	if parent == null:
		return
	var fx: CPUParticles2D = CPUParticles2D.new()
	fx.name = "Sparkle"
	fx.position = at
	fx.one_shot = true
	fx.explosiveness = 0.9
	fx.amount = amount
	fx.lifetime = 0.6
	fx.spread = 180.0
	fx.initial_velocity_min = speed * 0.3
	fx.initial_velocity_max = speed
	fx.gravity = Vector2(0.0, 120.0)
	fx.damping_min = 120.0
	fx.damping_max = 200.0
	fx.angular_velocity_min = -360.0
	fx.angular_velocity_max = 360.0
	fx.texture = star_texture()
	fx.scale_amount_min = 0.35
	fx.scale_amount_max = 0.8
	fx.scale_amount_curve = _shrink_curve()
	fx.color_ramp = _fade_ramp(col)
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx.material = mat
	fx.z_index = 21
	parent.add_child(fx)
	fx.emitting = true
	fx.finished.connect(fx.queue_free)


## 6c - Onda expansiva: un aro que crece y se apaga.
func ring(parent: Node, at: Vector2, col: Color, radius: float = 70.0, seconds: float = 0.32) -> Node2D:
	if parent == null:
		return null
	var r: Node2D = Node2D.new()
	r.name = "Shockwave"
	r.position = at
	r.z_index = 19
	r.set_meta("t", 0.0)
	r.draw.connect(func() -> void:
		var t: float = float(r.get_meta("t"))
		var rad: float = lerpf(radius * 0.2, radius, 1.0 - pow(1.0 - t, 3.0))
		var c: Color = Color(col, (1.0 - t) * 0.85)
		r.draw_arc(Vector2.ZERO, rad, 0.0, TAU, 40, c, lerpf(10.0, 1.5, t), true))
	parent.add_child(r)
	var tw: Tween = r.create_tween()
	tw.tween_method(func(v: float) -> void:
		r.set_meta("t", v)
		r.queue_redraw(), 0.0, 1.0, seconds)
	tw.tween_callback(r.queue_free)
	return r


## 6d - Polvo: nubecitas bajas que se abren a los lados (saltar, caer, frenar). Barato y da peso.
func dust(parent: Node, at: Vector2, col: Color = Color(1, 1, 1, 0.75), amount: int = 6, force: float = 1.0) -> void:
	if parent == null:
		return
	var fx: CPUParticles2D = CPUParticles2D.new()
	fx.position = at
	fx.one_shot = true
	fx.explosiveness = 0.9
	fx.amount = amount
	fx.lifetime = 0.42
	fx.direction = Vector2(0.0, -0.25)
	fx.spread = 85.0
	fx.initial_velocity_min = 50.0 * force
	fx.initial_velocity_max = 150.0 * force
	fx.gravity = Vector2(0.0, -40.0)
	fx.damping_min = 160.0
	fx.damping_max = 260.0
	fx.texture = dot_texture()
	fx.scale_amount_min = 0.5
	fx.scale_amount_max = 1.0
	fx.scale_amount_curve = _shrink_curve()
	fx.color = col
	fx.color_ramp = _fade_ramp(col)
	fx.z_index = 18
	parent.add_child(fx)
	fx.emitting = true
	fx.finished.connect(fx.queue_free)


## 6e - Confeti de victoria: papelitos de colores que suben y caen girando.
func confetti(parent: Node, at: Vector2, amount: int = 46) -> void:
	if parent == null:
		return
	var colores: Array[Color] = [Kit.color("accent", Color.GOLD), Kit.color("good", Color.LIME_GREEN),
		Kit.color("danger", Color.TOMATO), Color.WHITE, Kit.color("accent", Color.GOLD).lerp(Color.DEEP_SKY_BLUE, 0.7)]
	for i: int in colores.size():
		var fx: CPUParticles2D = CPUParticles2D.new()
		fx.position = at
		fx.one_shot = true
		fx.explosiveness = 0.85
		fx.amount = maxi(4, amount / colores.size())
		fx.lifetime = 1.5
		fx.direction = Vector2(0.0, -1.0)
		fx.spread = 55.0
		fx.initial_velocity_min = 380.0
		fx.initial_velocity_max = 760.0
		fx.gravity = Vector2(0.0, 1100.0)
		fx.damping_min = 60.0
		fx.damping_max = 140.0
		fx.angular_velocity_min = -540.0
		fx.angular_velocity_max = 540.0
		fx.scale_amount_min = 7.0
		fx.scale_amount_max = 12.0
		fx.color = colores[i]
		fx.color_ramp = _fade_ramp(colores[i])
		fx.z_index = 30
		parent.add_child(fx)
		fx.emitting = true
		fx.finished.connect(fx.queue_free)


## Texturas de particula hechas una vez (punto suave y estrella de cuatro puntas).
var _dot: Texture2D = null
var _star: Texture2D = null
var _curve: Curve = null


func dot_texture() -> Texture2D:
	if _dot == null:
		var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y: int in range(32):
			for x: int in range(32):
				var d: float = Vector2(float(x) - 15.5, float(y) - 15.5).length() / 15.5
				var a: float = clampf((1.0 - d) * 3.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_dot = ImageTexture.create_from_image(img)
	return _dot


func star_texture() -> Texture2D:
	if _star == null:
		var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y: int in range(32):
			for x: int in range(32):
				var px: float = absf(float(x) - 15.5) / 15.5
				var py: float = absf(float(y) - 15.5) / 15.5
				## Cuatro puntas finas y un nucleo con halo.
				var arm: float = maxf(clampf(1.0 - px * 1.05 - py * 7.0, 0.0, 1.0), clampf(1.0 - py * 1.05 - px * 7.0, 0.0, 1.0))
				var core: float = clampf(1.0 - Vector2(px, py).length() * 2.4, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(arm + core, 0.0, 1.0)))
		_star = ImageTexture.create_from_image(img)
	return _star


func _shrink_curve() -> Curve:
	if _curve == null:
		_curve = Curve.new()
		_curve.add_point(Vector2(0.0, 1.0))
		_curve.add_point(Vector2(0.6, 0.8))
		_curve.add_point(Vector2(1.0, 0.0))
	return _curve


func _fade_ramp(col: Color) -> Gradient:
	var g: Gradient = Gradient.new()
	g.set_color(0, col.lerp(Color.WHITE, 0.35))
	g.set_color(1, Color(col, 0.0))
	g.add_point(0.25, col)
	return g


func _process(delta: float) -> void:
	if _hitstop_left > 0.0:
		_hitstop_left -= delta / maxf(Engine.time_scale, 0.0001)
		if _hitstop_left <= 0.0:
			_hitstop_left = 0.0
			## Vuelve a la velocidad de la partida (1, o la que pida una regla viva).
			Engine.time_scale = Mods.tune("game_speed")
	_time += delta
	trauma = maxf(trauma - decay * delta, 0.0)
	if camera == null or not is_instance_valid(camera):
		return
	var power: float = trauma * trauma
	camera.offset = Vector2(
		max_offset.x * power * _noise.get_noise_2d(_time * 60.0, 0.0),
		max_offset.y * power * _noise.get_noise_2d(0.0, _time * 60.0)
	)
	camera.rotation = max_roll * power * _noise.get_noise_2d(_time * 60.0, 100.0)

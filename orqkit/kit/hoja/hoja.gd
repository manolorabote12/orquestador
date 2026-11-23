class_name Hoja
extends Sprite2D
## Personaje animado con hojas de sprites (las que pinta la herramienta animar: celdas de 256x256 en
## fila, pies abajo). Mide el tamano REAL del personaje en la hoja (no la celda) para que todas las
## animaciones salgan a la misma altura, apoyado en sus pies en position.
##   var h := Hoja.crear("heroe", ["idle", "attack", "death"], 180.0)  # 180 px de alto en pantalla
##   add_child(h); h.position = Vector2(300, 900)
##   h.poner("attack")                # vuelve sola a "idle" al acabar (si no es bucle)
##   h.poner("death", false, func(): h.queue_free())

signal acabada(anim: String)

const CELDA: int = 256
## Animaciones que se repiten; el resto se reproduce una vez.
const BUCLES: Array[String] = ["idle", "run", "walk", "fly", "victory"]

var fps: float = 10.0
var alto_px: float = 160.0
var _hojas: Dictionary = {}
var _medidas: Dictionary = {}
var _anim: String = ""
var _t: float = 0.0
var _frames: int = 1
var _bucle: bool = true
var _al_acabar: Callable = Callable()


## id: el que se dio a animar (busca res://assets/libre/anim/<id>_<anim>.png).
static func crear(id: String, anims: Array, alto: float = 160.0) -> Hoja:
	var h: Hoja = Hoja.new()
	h.alto_px = alto
	h.centered = false
	for a: Variant in anims:
		var ruta: String = "res://assets/libre/anim/%s_%s.png" % [id, str(a)]
		if ResourceLoader.exists(ruta):
			h._hojas[str(a)] = load(ruta)
	if h._hojas.has("idle"):
		h.poner("idle")
	elif not h._hojas.is_empty():
		h.poner(str(h._hojas.keys()[0]))
	return h


func tiene(anim: String) -> bool:
	return _hojas.has(anim)


## Cambia de animacion. bucle=null -> segun BUCLES. al_acabar: se llama al terminar (si no es bucle).
func poner(anim: String, bucle: Variant = null, al_acabar: Callable = Callable()) -> void:
	if not _hojas.has(anim):
		if al_acabar.is_valid():
			al_acabar.call()
		return
	var tx: Texture2D = _hojas[anim] as Texture2D
	texture = tx
	_frames = maxi(1, int(tx.get_width() / float(CELDA)))
	hframes = _frames
	frame = 0
	_anim = anim
	_t = 0.0
	_bucle = (anim in BUCLES) if bucle == null else bool(bucle)
	_al_acabar = al_acabar
	_ajustar()


## Escala y apoyo: el personaje mide alto_px de los pies a la cabeza y sus pies quedan en (0, 0).
func _ajustar() -> void:
	var r: Rect2i = _medida(_anim)
	if r.size.y <= 0:
		return
	var esc: float = alto_px / float(r.size.y)
	scale = Vector2(esc, esc)
	offset = Vector2(-CELDA / 2.0, -float(r.position.y + r.size.y))


func _medida(anim: String) -> Rect2i:
	if _medidas.has(anim):
		return _medidas[anim]
	var tx: Texture2D = _hojas.get(anim) as Texture2D
	var r: Rect2i = Rect2i(0, 0, CELDA, CELDA)
	if tx != null:
		var img: Image = tx.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			r = img.get_region(Rect2i(0, 0, mini(CELDA, img.get_width()), img.get_height())).get_used_rect()
	_medidas[anim] = r
	return r


func _process(delta: float) -> void:
	if _anim == "" or _frames <= 1:
		return
	_t += delta * fps
	var f: int = int(_t)
	if f >= _frames:
		if _bucle:
			_t = fmod(_t, float(_frames))
			f = int(_t)
		else:
			frame = _frames - 1
			var cb: Callable = _al_acabar
			var hecha: String = _anim
			_anim = ""
			if cb.is_valid():
				cb.call()
			elif _hojas.has("idle") and hecha != "death":
				poner("idle")
			acabada.emit(hecha)
			return
	frame = f

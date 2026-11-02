class_name MetroidMapPanel
extends UiModal
## Mapa grande del metroidvania (boton junto a la pausa): las salas visitadas casilla a casilla,
## con lo que queda por coger, puertas, bloques rompibles, pinchos, donde estas y la meta.
## El juego queda en pausa mientras esta abierto.

const M = preload("res://kit/metroid/metroid_map.gd")
const ITEM_COL: Dictionary = {"J": "#4cc9f0", "D": "#ffd166", "B": "#ef476f", "K": "#f4a261", "$": "#ffd54f", "+": "#ff6b81"}
const TILE_COL: Dictionary = {"#": "#3d405b", "%": "#9c6644", "L": "#f4a261", "^": "#e63946"}

var st: Dictionary = {}
var _map: Control
var _was_paused: bool = false


static func open(host: Node, state: Dictionary) -> MetroidMapPanel:
	var p: MetroidMapPanel = MetroidMapPanel.new()
	p.name = "MetroidMapPanel"
	p.layer = 60
	p.st = state
	host.add_child(p)
	return p


func _ready() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	build_frame(Kit.text("mv_map", "Mapa"), 660.0)
	var rooms: int = (st["seen"] as Dictionary).size()
	var total: int = maxi(1, ((int(st["w"]) - 1) / 14) * ((int(st["h"]) - 1) / 10))
	var info: Label = Label.new()
	info.name = "MapInfo"
	info.text = Kit.text("mv_map_rooms", "Salas exploradas: {n}/{t}").format({"n": mini(rooms, total), "t": total})
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(info)
	_map = Control.new()
	_map.name = "Map"
	var w: float = float(int(st["w"]))
	var h: float = float(int(st["h"]))
	var room_h: float = maxf(300.0, root.get_viewport().get_visible_rect().size.y - 620.0)
	var k: float = minf(600.0 / maxf(w, 1.0), room_h / maxf(h, 1.0))
	_map.custom_minimum_size = Vector2(w * k, h * k)
	_map.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_map.draw.connect(_draw_map.bind(k))
	body.add_child(_map)
	var legend: Label = Label.new()
	legend.name = "Legend"
	legend.text = Kit.text("mv_map_legend", "Azul: t\u00fa  \u00b7  Verde: meta  \u00b7  Naranja: puerta")
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.add_theme_font_size_override("font_size", 20)
	legend.add_theme_color_override("font_color", UI.colors["texto_suave"])
	body.add_child(legend)
	var close_btn: Button = UI.make_button(Kit.text("close", "Cerrar"), true, "close")
	close_btn.name = "BtnClose"
	close_btn.pressed.connect(close)
	body.add_child(close_btn)


func close() -> void:
	get_tree().paused = _was_paused
	super.close()


func _draw_map(k: float) -> void:
	var seen: Dictionary = st["seen"]
	_map.draw_rect(Rect2(Vector2.ZERO, _map.size), Color(0, 0, 0, 0.35))
	for room: Variant in seen:
		var r: Vector2i = room
		var r0: Vector2 = Vector2(r.x * 14, r.y * 10) * k
		_map.draw_rect(Rect2(r0, Vector2(15, 11) * k), Color(1, 1, 1, 0.06))
		for y: int in range(r.y * 10, mini(r.y * 10 + 11, int(st["h"]))):
			for x: int in range(r.x * 14, mini(r.x * 14 + 15, int(st["w"]))):
				var ch: String = M.cell(st, Vector2i(x, y))
				if TILE_COL.has(ch):
					_map.draw_rect(Rect2(Vector2(x, y) * k, Vector2(k, k)), Color(str(TILE_COL[ch])))
	## Lo que queda por coger en las salas vistas.
	for p: Variant in st["items"]:
		var ip: Vector2i = p
		if seen.has(M.room_of(ip)):
			_map.draw_circle((Vector2(ip) + Vector2(0.5, 0.5)) * k, maxf(2.5, k * 0.45), Color(str(ITEM_COL.get(str(st["items"][p]), "#ffffff"))))
	var g: Vector2i = st["goal"]
	if g.x >= 0 and seen.has(M.room_of(g)):
		_map.draw_circle((Vector2(g) + Vector2(0.5, 0.5)) * k, maxf(4.0, k * 0.8), Color("#80ed99"))
	var me: Vector2 = (Vector2(st["p"] as Vector2i) + Vector2(0.5, 0.5)) * k
	_map.draw_circle(me, maxf(5.0, k * 0.9), Color.WHITE)
	_map.draw_circle(me, maxf(3.5, k * 0.65), Color("#4cc9f0"))

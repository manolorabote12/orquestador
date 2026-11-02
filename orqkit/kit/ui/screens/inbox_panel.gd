class_name InboxPanel
extends UiModal
## Buzon "Mientras no estabas": lo que ha pasado desde la ultima vez (Notify.inbox()).
## Cada linea con su icono; "Misiones y pase" abre ese panel. Se ensena una vez al abrir el juego.

var items: Array = []


static func open(host: Node, list: Array) -> InboxPanel:
	var p: InboxPanel = InboxPanel.new()
	p.name = "InboxPanel"
	p.layer = 60
	p.items = list
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("inbox", "Mientras no estabas"), 600.0)
	var icons: Dictionary = {"season": "star", "torneo": "trophy", "liga": "grid", "guerra": "trophy", "evento": "coin"}
	var i: int = 0
	for it: Variant in items:
		var d: Dictionary = it
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Item%d" % i
		row.add_theme_constant_override("separation", 14)
		body.add_child(row)
		row.add_child(UiIcon.make(str(icons.get(str(d.get("kind", "")), "star")), UI.colors["acento"], 48.0))
		var l: Label = Label.new()
		l.text = str(d.get("text", ""))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		i += 1
	if items.any(func(x: Variant) -> bool: return str((x as Dictionary).get("kind", "")) == "season"):
		var go: Button = UI.make_button(Kit.text("season", "Misiones y pase"), true, "star")
		go.name = "BtnInboxSeason"
		go.pressed.connect(func() -> void:
			var host: Node = get_parent()
			close()
			SeasonPanel.open(host))
		body.add_child(go)
	var ok: Button = UI.make_button(Kit.text("ok", "Vale"), false, "")
	ok.name = "BtnClose"
	ok.pressed.connect(close)
	body.add_child(ok)

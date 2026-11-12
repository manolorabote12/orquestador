class_name SpriteKit
extends RefCounted
## Convierte las hojas de sprites de la fabrica (assets/manifest.json) en nodos de Godot.
## Cada animacion es una hoja con los frames en fila, todos del mismo tamano de celda.


## 1 - SpriteFrames a partir de una entrada del manifest.
static func frames_de(entry: Dictionary) -> SpriteFrames:
	var sf: SpriteFrames = SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	var celda: Array = entry.get("celda", [32, 32])
	var anims: Dictionary = entry.get("animaciones", {})
	for anim_name: String in anims.keys():
		var a: Dictionary = anims[anim_name]
		var tex: Texture2D = load(str(a.get("sheet", ""))) as Texture2D
		if tex == null:
			QA.fail("sprite_sheet_missing", {"sheet": str(a.get("sheet", ""))})
			continue
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, float(a.get("fps", 8.0)))
		sf.set_animation_loop(anim_name, bool(a.get("bucle", true)))
		for i: int in int(a.get("frames", 1)):
			var at: AtlasTexture = AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * float(celda[0]), 0.0, float(celda[0]), float(celda[1]))
			sf.add_frame(anim_name, at)
	return sf


## 2 - Escala entera (pixel perfecto): la figura ocupa ~86% de su celda. Si el arte es mas grande
##     que su tamano en pantalla (celdas de 128 del arte no pixelado), se reduce con escala exacta.
static func escala_entera(celda_alto: float, target_px: float) -> float:
	var k: float = target_px / (celda_alto * 0.86)
	if k < 0.8:
		return k
	return maxf(1.0, roundf(k))


## 3 - Nodo animado listo para usar. Con pies=true el origen queda en los pies.
static func animado(entry: Dictionary, target_px: float, first: String, pies: bool) -> AnimatedSprite2D:
	var spr: AnimatedSprite2D = AnimatedSprite2D.new()
	spr.sprite_frames = frames_de(entry)
	var celda: Array = entry.get("celda", [32, 32])
	var k: float = escala_entera(float(celda[1]), target_px)
	spr.scale = Vector2(k, k)
	## Arte reducido: con suavizado (sin el, al encoger salen dientes de sierra).
	if k < 1.0:
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.centered = true
	if pies:
		spr.position = Vector2(0.0, -float(celda[1]) * k * 0.5)
	if spr.sprite_frames.has_animation(first):
		spr.play(first)
	return spr


## 4 - El protagonista del juego como mascota (generos sin heroe en la partida: cocina, puzles...).
##     Sombra + personaje con su piel, origen en los pies. null si el juego no tiene arte del heroe.
static func mascota(alto: float) -> Node2D:
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if art.is_empty():
		return null
	var n: Node2D = Node2D.new()
	n.name = "Mascot"
	var sh: Polygon2D = Polygon2D.new()
	sh.polygon = LevelBuilder._circle(alto * 0.33, 18)
	sh.scale = Vector2(1.0, 0.3)
	sh.color = Color(0, 0, 0, 0.22)
	n.add_child(sh)
	var spr: AnimatedSprite2D = animado(art, alto, "idle", true)
	Skins.apply(spr)
	n.add_child(spr)
	return n


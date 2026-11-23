"""Prueba del juego a medida en directo (23 nov 2026): el Agente Estudio cuenta cada paso a la app.

Sin IA ni GPU: una «IA» de guion escribe un juego minimo, pinta una imagen (falsa), lo prueba entero y
termina. Se comprueba que salen los eventos que la app ensena (frases, fotos del arte y de las pruebas,
el bot) y que el boceto jugable se intenta subir.

	python -m pruebas.prueba_estudio_directo
"""

import io
import json
import sys
import tempfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ))

import cadena  # noqa: E402
from libre import agente  # noqa: E402

MAIN_GD = """extends Control

var toques: int = 0
var etiqueta: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fondo: TextureRect = TextureRect.new()
	fondo.texture = load("res://assets/libre/fondo.png")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	etiqueta = Label.new()
	etiqueta.text = "Toques: 0"
	etiqueta.position = Vector2(200, 300)
	add_child(etiqueta)
	var b: Button = Button.new()
	b.text = "Tocar"
	b.position = Vector2(260, 600)
	b.custom_minimum_size = Vector2(200, 100)
	b.pressed.connect(tocar)
	add_child(b)


func tocar() -> void:
	toques += 1
	etiqueta.text = "Toques: %d" % toques
"""

BOT_GD = """extends RefCounted


static func jugar(tree: SceneTree) -> Dictionary:
	var j: Node = tree.current_scene
	for i: int in 3:
		j.call("tocar")
	return {"ok": int(j.get("toques")) >= 3, "niveles": 3, "detalle": "toco tres veces"}
"""

TSCN = """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://libre/main.gd" id="1"]

[node name="Main" type="Control"]
script = ExtResource("1")
"""


def _uso(i: int, nombre: str, **args) -> dict:
	return {"type": "tool_use", "id": f"u{i}", "name": nombre, "input": args}


GUION = [
	[{"type": "text", "text": "Un juego de tocar con un fondo pintado: primero el fondo, luego la pantalla."},
		_uso(1, "dibujar", id="fondo", prompt="a calm painted meadow", ancho=512, alto=896)],
	[{"type": "text", "text": "Escribo la pantalla principal y el bot."},
		_uso(2, "escribir", ruta="res://libre/main.gd", contenido=MAIN_GD), _uso(3, "escribir", ruta="res://libre/main.tscn", contenido=TSCN),
		_uso(4, "escribir", ruta="res://libre/bot.gd", contenido=BOT_GD)],
	[{"type": "text", "text": "Lo pruebo todo."}, _uso(5, "probar", que="todo")],
	[_uso(6, "terminar", titulo="Toca Toca", resumen="Un juego de tocar.", huella={"metafora": "pradera", "navegacion": "una pantalla",
		"estructura": "contador", "estetica": "pintada", "mecanica": "tocar"})],
]


class ImagenFalsa:
	def generar(self, flujo, valores):
		from PIL import Image
		b = io.BytesIO()
		Image.new("RGB", (int(valores["ANCHO"]), int(valores["ALTO"])), (90, 150, 90)).save(b, "PNG")
		return [b.getvalue()]


def main() -> int:
	eventos: list[dict] = []
	subidas: list[str] = []
	cadena.oyentes.append(eventos.append)
	turno = {"n": 0}

	def llamar(mensajes, gasto):
		r = GUION[min(turno["n"], len(GUION) - 1)]
		turno["n"] += 1
		return {"content": r, "stop_reason": "tool_use"}
	agente._llamar = llamar
	with tempfile.TemporaryDirectory() as t:
		p = Path(t) / "juego"
		agente.preparar(p, "Mi juego", "un juego de tocar")

		def subir(local: Path, nombre: str) -> str:
			assert local.exists(), local
			subidas.append(nombre)
			return f"usuario/job/{nombre}"
		e = agente.Estudio(p, "un juego de tocar", "Mi juego", 5.0, [], Path(t) / "estudio", entrevista={"genero": "toques", "estetica": "pintada"},
			subir=subir, boceto=True)
		e.cli_img = ImagenFalsa()
		inf = e.ejecutar()
	cadena.oyentes.remove(eventos.append)
	pasos = [(x["paso"], x["estado"]) for x in eventos]
	print(json.dumps({"ok": inf["ok"], "titulo": inf["titulo"], "pasos": pasos, "subidas": subidas}, ensure_ascii=False, indent=1))
	fallos = []
	if not inf["ok"]:
		fallos.append("el estudio no termino: " + json.dumps(inf.get("prueba")))
	if inf.get("titulo") != "Toca Toca":
		fallos.append("no guardo el titulo del juego")
	if not any(x["paso"] == "arte" and x.get("foto") for x in eventos):
		fallos.append("falta la foto del arte en la bitacora")
	if not any(x["paso"] == "pruebas" and x.get("fotos") for x in eventos):
		fallos.append("faltan las fotos de las pruebas")
	if not any(x["paso"] == "bot" and x["estado"] == "ok" for x in eventos):
		fallos.append("falta el aviso del bot")
	if not any(x["estado"] == "info" for x in eventos):
		fallos.append("faltan las frases del estudio")
	print("FALLOS:" if fallos else "TODO BIEN", *fallos, sep="\n- " if fallos else "")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

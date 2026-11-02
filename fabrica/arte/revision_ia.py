"""Revision visual con IA: Claude mira la ficha de cada personaje antes de animarla.

Comprueba lo que los filtros automaticos no ven: que el dibujo sea el personaje descrito, que sea
uno solo y entero, que no tenga texto ni marcas de agua, y que no se parezca a un personaje
protegido (Mario, Pikachu...). Si no pasa, la ficha se repite con otra semilla (una vez).
Modelo barato con vision (Haiku); cuesta menos de un centimo por personaje.
"""

import base64

from director import llm

HERRAMIENTA = {
	"name": "revision",
	"description": "Resultado de revisar la ficha de un personaje de videojuego.",
	"input_schema": {
		"type": "object",
		"required": ["ok", "problemas", "parecido_protegido"],
		"properties": {
			"ok": {"type": "boolean", "description": "true si se puede usar tal cual"},
			"problemas": {"type": "array", "items": {"type": "string", "maxLength": 120}, "maxItems": 5,
				"description": "En espanol, concretos (vacio si ok)"},
			"parecido_protegido": {"type": "string", "maxLength": 80,
				"description": "Personaje o marca protegida a la que se parece claramente, o cadena vacia"},
		},
	},
}

SISTEMA = ("Eres director de arte de videojuegos moviles. Revisas la ficha (imagen de referencia) de un personaje "
	"sobre fondo magenta. Rechaza SOLO por problemas reales: no es lo descrito; hay varios personajes; esta cortado; "
	"tiene texto, letras o marca de agua; es ilegible a tamano pequeno; o se parece claramente a un personaje o marca "
	"protegida. El estilo artistico y pequenas diferencias de detalle NO son motivo de rechazo.")


def revisar(png: bytes, descripcion: str, estilo: str, gasto: llm.Gasto) -> dict:
	mensajes = [{"role": "user", "content": [
		{"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": base64.b64encode(png).decode("ascii")}},
		{"type": "text", "text": f"Personaje: {descripcion}\nEstilo: {estilo}\nRevisa la ficha y llama a la herramienta."},
	]}]
	r = llm.llamar_herramienta(llm.MODELOS[0], SISTEMA, mensajes, HERRAMIENTA, gasto, "revision_visual", max_tokens=400)
	ok = bool(r.get("ok")) and not str(r.get("parecido_protegido", "")).strip()
	return {"ok": ok, "problemas": [str(x) for x in r.get("problemas", [])][:5], "parecido": str(r.get("parecido_protegido", ""))}

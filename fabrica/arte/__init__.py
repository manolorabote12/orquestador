"""Cadena de arte de la fabrica de Orquestador.

Lee la Biblia del juego, encarga las imagenes a ComfyUI (Z-Image para crear,
FLUX.2 klein para variaciones desde una referencia), fuerza la coherencia con
postprocesado, revisa el resultado con QA y lo exporta al kit de Godot.
"""

VERSION = "0.1.0"

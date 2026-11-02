"""Prueba de punta a punta de la cadena de arte con ComfyUI simulado.

python -m pruebas.prueba_completa ../orqkit
"""

import argparse
import json
import sys
import wave
from pathlib import Path

import numpy as np
from PIL import Image

from arte import biblia as bib
from arte import cli, interfaz
from pruebas import comfy_simulado

RAIZ = Path(__file__).resolve().parent.parent


def main() -> int:
	godot = Path(sys.argv[1]) if len(sys.argv) > 1 else None
	srv = comfy_simulado.arrancar(8199)
	salida = RAIZ / "salida_prueba"
	args = argparse.Namespace(
		biblia=str(RAIZ / "ejemplos" / "biblia_salto.json"), comfy="http://127.0.0.1:8199",
		crear=str(RAIZ / "plantillas" / "simulado_crear.json"), editar=str(RAIZ / "plantillas" / "simulado_editar.json"),
		salida=str(salida), godot=str(godot) if godot else "", lado=512,
	)
	informe = cli.fabricar(args)
	srv.shutdown()

	biblia = bib.cargar(args.biblia)
	paleta = {tuple(c) for c in bib.paleta_rgb(biblia)}
	fallos = []

	def check(nombre: str, ok: bool, detalle: str = "") -> None:
		print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
		if not ok:
			fallos.append(nombre)

	print("== Cadena de arte ==")
	check("la trampa del simulador se detecta y se regenera", informe["regeneradas"] >= 1, f"regeneradas={informe['regeneradas']}")
	check("sin avisos finales", not informe["avisos"], str(informe["avisos"]))
	for sid, anims in informe["sprites"].items():
		for anim, datos in anims.items():
			check(f"{sid}/{anim} pasa QA", datos["qa_ok"], f"deriva media {datos['deriva_media']}")
	for tid, datos in informe["tiles"].items():
		check(f"tile {tid} sin costura", datos["qa_ok"], f"costura {datos['costura']}")

	if godot:
		man = json.loads((godot / "assets" / "manifest.json").read_text(encoding="utf-8"))
		for sid, s in man["sprites"].items():
			for anim, a in s["animaciones"].items():
				p = godot / a["sheet"].replace("res://", "")
				img = Image.open(p).convert("RGBA")
				w, h = s["celda"]
				check(f"hoja {sid}/{anim} mide {w * a['frames']}x{h}", img.size == (w * a["frames"], h))
				arr = np.asarray(img)
				opacos = arr[arr[..., 3] > 0][:, :3]
				fuera = sum(1 for c in map(tuple, opacos) if c not in paleta)
				check(f"hoja {sid}/{anim} 100% en paleta", fuera == 0, f"{fuera} pixeles fuera")
				semi = int(((arr[..., 3] > 0) & (arr[..., 3] < 255)).sum())
				check(f"hoja {sid}/{anim} sin semitransparencias", semi == 0)
		for nombre, ruta in man["sfx"].items():
			p = godot / ruta.replace("res://", "")
			with wave.open(str(p)) as w:
				dur = w.getnframes() / w.getframerate()
			check(f"sonido {nombre} valido", 0.03 < dur < 2.0, f"{dur:.2f}s")
		ui = man.get("ui", {})
		check("interfaz exportada con perfil del estilo", ui.get("perfil") == "pixel", str(ui.get("perfil")))
		check("interfaz con los 10 colores", sorted(ui.get("colores", {})) == sorted(interfaz.ROLES))
		if ui.get("colores"):
			rep = interfaz.informe_contraste(ui)
			check("interfaz legible (contraste >= 4.5)", min(rep.values()) >= 4.5, str(rep))
	print(f"== {len(fallos)} fallos, {informe['generaciones']} generaciones, {informe['segundos']} s ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

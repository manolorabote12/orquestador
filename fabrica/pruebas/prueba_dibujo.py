"""Tu dibujo como protagonista: la ficha del heroe sale de editar la imagen del autor.

	python -m pruebas.prueba_dibujo
"""

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from PIL import Image, ImageDraw  # noqa: E402

import cadena  # noqa: E402
import cambio  # noqa: E402
from director import cambios, director, simulado  # noqa: E402

SALIDA = Path(__file__).resolve().parent.parent.parent / "proyectos_prueba_dibujo"


def main() -> int:
	fallos = 0

	def check(nombre: str, ok: bool, detalle: str = "") -> None:
		nonlocal fallos
		print(("  OK   " if ok else "  FALLO ") + nombre + (f"  ({detalle})" if detalle and not ok else ""))
		fallos += 0 if ok else 1

	d = director.normalizar(simulado.disenar("un gato ninja que salta por tejados"))
	op = {"op": "redibujar", "que": "heroe", "descripcion": "a round orange cat drawn with crayons", "referencia": "dibujo"}
	sin = {k: v for k, v in op.items() if k != "referencia"}
	check("referencia valida para el heroe", not cambios.validar_plan({"resumen": "Uso tu dibujo", "operaciones": [op]}, d))
	check("referencia no vale para la moneda", bool(cambios.validar_plan({"resumen": "Uso tu dibujo", "operaciones": [dict(op, que="moneda")]}, d)))
	_, ef = cambios.aplicar_diseno(d, [[] for _ in d["niveles"]], {"resumen": "x", "operaciones": [op]})
	check("aplicar: usa la referencia y rehace el icono", ef["referencia"] == "usar" and ef["icono"])
	_, ef = cambios.aplicar_diseno(d, [[] for _ in d["niveles"]], {"resumen": "x", "operaciones": [sin]})
	check("redibujar sin referencia: se olvida el dibujo", ef["referencia"] == "quitar")

	shutil.rmtree(SALIDA, ignore_errors=True)
	inf = cadena.fabricar(argparse.Namespace(idea="un gato ninja rápido que salta por tejados de noche", salida=str(SALIDA),
		simulado=True, arte_simulado=True, comfy="", crear="", editar="", lado=512, semilla=5, apk=False, capturas=False))
	P = Path(inf["proyecto"])

	def plan(ops: list) -> dict:
		p = {"resumen": "Dibujo", "operaciones": ops}
		return cambio.cambiar(argparse.Namespace(proyecto=str(P), instruccion="Tu dibujo", plan=json.dumps(p), solo_plan=False, simulado=True,
			arte_simulado=True, comfy="", crear="", editar="", lado=512, semilla=5, slug="", apk=False, capturas=False))

	try:
		plan([op])
		check("sin el archivo del dibujo, el cambio falla (y se devuelve)", False)
	except cadena.ErrorCadena as e:
		check("sin el archivo del dibujo, el cambio falla (y se devuelve)", "dibujo" in str(e))
	ref = P / "fabrica" / "referencias" / "heroe.png"
	ref.parent.mkdir(parents=True, exist_ok=True)
	img = Image.new("RGBA", (400, 400), "white")
	ImageDraw.Draw(img).ellipse((80, 80, 320, 320), fill="orange", outline="black", width=8)
	img.save(ref)
	antes = hashlib.md5((P / "assets/heroe/run.png").read_bytes()).hexdigest()
	r = plan([op])
	informe = json.loads((P / "fabrica" / "arte" / "informe.json").read_text(encoding="utf-8"))
	check("cambio aplicado y validado por los bots", r["aplicado"])
	check("la ficha del heroe sale del dibujo", informe.get("referencias") == ["heroe"], str(informe.get("referencias")))
	check("el heroe es nuevo", hashlib.md5((P / "assets/heroe/run.png").read_bytes()).hexdigest() != antes)
	check("el dibujo se guarda con el proyecto (para futuros cambios de estilo)", ref.exists())
	plan([dict(sin, descripcion="a small black ninja cat with a red scarf")])
	check("redibujar sin dibujo lo olvida", not ref.exists())
	shutil.rmtree(SALIDA, ignore_errors=True)
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

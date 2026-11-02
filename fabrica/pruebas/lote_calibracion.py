"""Lote de calibracion: fabrica juegos de TODOS los generos (y dificultades) con la cadena entera
simulada. Cada fabricacion apunta en datos/fabrica.jsonl cuantas veces hubo que rehacer cada
nivel (aprendizaje.py lo usa para suavizar los tramos que salen injustos) y aqui se resume:
genero, dificultad, si salio, cuanto tardo y que niveles costaron.

	python -m pruebas.lote_calibracion                 (todos los generos, normal y dificil)
	python -m pruebas.lote_calibracion golf,pesca facil,normal,dificil
	python -m pruebas.lote_calibracion --giros         (cada giro en todos sus generos: la fabrica
	                                                      aprende que giro funciona donde)

Al final recalcula la calibracion (aprendizaje) y escribe datos/lote_calibracion.json.
"""

import argparse
import json
import shutil
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import aprendizaje  # noqa: E402
import cadena  # noqa: E402
import generos  # noqa: E402

SALIDA = Path(__file__).resolve().parent.parent.parent / "proyectos_lote"

## Una idea tipica por genero (la directora simulada elige el genero por estas palabras).
IDEAS = {
	"plataformas": "un gato ninja que salta por tejados de noche",
	"runner": "un zorro que huye corriendo sin parar por un volcan (runner)",
	"volador": "un pajaro de papel que vuela entre columnas de un toque",
	"saltos": "una rana que sube saltando hacia arriba por nenufares",
	"carreras": "carreras de karts en un desierto",
	"naves": "un matamarcianos con naves de colores",
	"horda": "sobrevive a hordas de zombis en un cementerio",
	"torres": "defiende tu castillo con torres",
	"rompebloques": "rompe ladrillos con una pelota en un castillo de caramelo",
	"puzle": "un puzle de combinar gemas en un bosque",
	"bloques": "encaja bloques en un tablero de un jardin",
	"cajas": "un sokoban de empujar cajas de regalos",
	"serpiente": "una serpiente que come fresas en un huerto",
	"memoria": "un juego de memoria con animales de la granja",
	"preguntas": "un trivial de preguntas sobre los planetas",
	"apilar": "apila bloques de tarta hasta el cielo",
	"topos": "aplasta a los topos que asoman en el huerto",
	"corredor": "corre por tres carriles esquivando trenes en una ciudad",
	"arena": "todos contra todos en una arena de robots chatarreros",
	"aldea": "asalta la base enemiga con tu ejercito de clanes",
	"ritmo": "un juego de ritmo musical con notas de colores",
	"clicker": "un clicker idle donde construyes un imperio de pasteles",
	"cartas": "un solitario de cartas en un casino pirata",
	"rpg": "un rpg por turnos de caballeros contra monstruos",
	"laberinto": "un laberinto de mazmorra con llaves y puertas",
	"golf": "un minigolf de hoyos en una playa",
	"pesca": "un juego de pesca en un lago con un oso pescador",
	"fusion": "un juego de fusionar gemas iguales tipo 2048",
	"tubos": "un puzle de ordenar colores en tubos de pociones",
	"burbujas": "un lanza burbujas de colores en un bosque de hadas",
}
SUFIJO = {"facil": " para peques, facil", "normal": "", "dificil": ", dificil y con reto"}


def lote_giros() -> int:
	"""Cada giro en cada genero donde vale (racha en 4 de muestra). Lo que falla se quita solo y
	queda apuntado (giros.py): asi la fabrica deja de ofrecerlo donde no funciona."""
	import giros
	filas = []
	for gid, g in giros.GIROS.items():
		gens = g["generos"] if g["generos"] != "*" else ["plataformas", "laberinto", "fusion", "golf"]
		for genero in gens:
			shutil.rmtree(SALIDA, ignore_errors=True)
			t0 = time.time()
			fila = {"genero": genero, "giro": gid}
			try:
				inf = cadena.fabricar(argparse.Namespace(idea=f"[gancho:{genero}:{gid}] " + IDEAS[genero], salida=str(SALIDA), simulado=True,
					arte_simulado=True, comfy="", crear="", editar="", lado=512, semilla=31 + len(filas), apk=False, capturas=False))
				game = json.loads((Path(inf["proyecto"]) / "game.json").read_text(encoding="utf-8"))
				fila.update(ok=bool(inf.get("ok")), giro_entregado=gid in game.get("twists", []))
			except Exception as e:  # noqa: BLE001
				fila.update(ok=False, giro_entregado=False, error=str(e)[:300])
			fila["total_s"] = round(time.time() - t0, 1)
			filas.append(fila)
			print("LOTE", json.dumps(fila, ensure_ascii=False), flush=True)
	shutil.rmtree(SALIDA, ignore_errors=True)
	resumen = {"t": int(time.time()), "fabricaciones": len(filas), "ok": sum(1 for f in filas if f.get("ok")),
		"con_giro": sum(1 for f in filas if f.get("giro_entregado")), "filas": filas, "informe": giros.informe()}
	(aprendizaje.carpeta() / "lote_giros.json").write_text(json.dumps(resumen, indent=1, ensure_ascii=False), encoding="utf-8")
	print(f"== {resumen['ok']}/{len(filas)} fabricados; con su giro {resumen['con_giro']}/{len(filas)} ==")
	print(giros.informe())
	return 0 if resumen["ok"] == len(filas) else 1


def main() -> int:
	if "--giros" in sys.argv:
		return lote_giros()
	solo = sys.argv[1].split(",") if len(sys.argv) > 1 and sys.argv[1] else list(IDEAS)
	difs = sys.argv[2].split(",") if len(sys.argv) > 2 else ["normal", "dificil"]
	faltan = [g for g in generos.GENEROS if g not in IDEAS]
	if faltan:
		print("generos sin idea en el lote:", faltan)
	filas = []
	for g in solo:
		for dif in difs:
			shutil.rmtree(SALIDA, ignore_errors=True)
			t0 = time.time()
			fila = {"genero": g, "dificultad": dif}
			try:
				inf = cadena.fabricar(argparse.Namespace(idea=IDEAS[g] + SUFIJO[dif], salida=str(SALIDA), simulado=True, arte_simulado=True,
					comfy="", crear="", editar="", lado=512, semilla=11 + len(filas), apk=False, capturas=False))
				dis = json.loads((Path(inf["proyecto"]) / "fabrica" / "diseno.json").read_text(encoding="utf-8"))
				niveles = inf.get("validacion", {}).get("niveles", [])
				fila.update(ok=bool(inf.get("ok")), genero_real=dis["genero"], dificultad_real=dis["dificultad"],
					niveles=len(dis["niveles"]), bot_muertes=sum(int(n.get("bot_muertes", 0)) for n in niveles),
					segundos_bot=round(sum(float(n.get("bot_segundos", 0)) for n in niveles), 1))
			except Exception as e:  # noqa: BLE001 - se apunta y se sigue con el resto
				fila.update(ok=False, error=str(e)[:300])
			fila["total_s"] = round(time.time() - t0, 1)
			filas.append(fila)
			print("LOTE", json.dumps(fila, ensure_ascii=False), flush=True)
	shutil.rmtree(SALIDA, ignore_errors=True)
	cal = aprendizaje.calcular([], aprendizaje.leer_fabricacion())
	aprendizaje.guardar(cal)
	resumen = {"t": int(time.time()), "fabricaciones": len(filas), "ok": sum(1 for f in filas if f.get("ok")),
		"genero_bien_elegido": sum(1 for f in filas if f.get("genero_real") == f["genero"]), "filas": filas,
		"calibracion": cal}
	(aprendizaje.carpeta() / "lote_calibracion.json").write_text(json.dumps(resumen, indent=1, ensure_ascii=False), encoding="utf-8")
	print(f"== {resumen['ok']}/{len(filas)} fabricados; genero bien elegido {resumen['genero_bien_elegido']}/{len(filas)} ==")
	return 0 if resumen["ok"] == len(filas) else 1


if __name__ == "__main__":
	sys.exit(main())

"""Partidas de muestra («Probar» en el catálogo del taller): cada género tiene una idea que la
directora convierte en ESE género, se fabrican de verdad (con validación de bots) y se suben al
bucket público con su índice; la tarea de RunPod solo hace las que faltan.

	python -m pruebas.prueba_muestras
"""

import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import generos  # noqa: E402
import muestras  # noqa: E402
import runpod_handler  # noqa: E402
from director import director  # noqa: E402

fallos = 0


def check(nombre: str, ok: bool, extra: str = "") -> None:
	global fallos
	print(("  OK   " if ok else "  FALLO ") + nombre + (f"  ({extra})" if extra else ""))
	if not ok:
		fallos += 1


class SupabaseFalso:
	"""Guarda lo que se sube; el índice se puede bajar después."""

	def __init__(self) -> None:
		self.archivos: dict[str, bytes] = {}

	def subir(self, ruta: str, archivo: Path, bucket: str = "juegos") -> str:
		self.archivos[f"{bucket}/{ruta}"] = archivo.read_bytes()
		return ruta

	def bajar(self, ruta: str, destino: Path, bucket: str = "juegos") -> Path:
		clave = f"{bucket}/{ruta}"
		if clave not in self.archivos:
			raise RuntimeError("404")
		destino.write_bytes(self.archivos[clave])
		return destino


def main() -> int:
	todos = muestras.lista_generos()
	check("hay muestra para todos los géneros menos el «a medida»", len(todos) == len(generos.GENEROS) - 1 and "a_medida" not in todos,
		f"{len(todos)} de {len(generos.GENEROS)}")
	check("primero los clásicos (el orden del catálogo)", todos[0] == "plataformas", todos[0])
	malos = []
	for g in todos:
		d, _ = director.disenar(muestras.idea_muestra(g), True, director.llm.Gasto())
		if d.get("genero") != g:
			malos.append(f"{g}->{d.get('genero')}")
	check("la idea de cada muestra da justo su género", not malos, ", ".join(malos[:8]))
	check("géneros con guion bajo también (marca de gancho)", muestras.idea_muestra("cartas_locas").startswith(("[plantilla:", "[gancho:cartas_locas:]")))

	sb = SupabaseFalso()
	salida = Path(tempfile.mkdtemp(prefix="orq_prueba_muestras_"))
	r = muestras.hacer(["diferencias", "numeros"], salida, sb)
	check("fabrica las muestras pedidas", r["hechas"] == ["diferencias", "numeros"] and not r["fallos"], json.dumps(r["fallos"])[:300])
	check("sube cada paquete al bucket público del motor", all(f"motor/muestras/{g}.pck" in sb.archivos for g in r["hechas"]), str(list(sb.archivos)))
	pck = sb.archivos.get("motor/muestras/diferencias.pck", b"")
	check("es un paquete de Godot (GDPC) pequeño", pck[:4] == b"GDPC" and len(pck) < 20_000_000, f"{len(pck)} bytes")
	indice = json.loads(sb.archivos.get("motor/muestras/indice.json", b"{}"))
	check("índice con título, versión y tamaño", set(indice) == {"diferencias", "numeros"} and all({"titulo", "v", "mb"} <= set(x) for x in indice.values()), str(indice))
	check("lo publicado se lee de vuelta", muestras.indice_remoto(sb) == indice)

	## La tarea de RunPod: sin lista hace solo las que faltan (aquí, ninguna más de las dos si se le
	## pide una lista; con un género desconocido, lo ignora).
	import os
	os.environ["ORQ_ARTE_SIMULADO"] = "1"
	r2 = runpod_handler.handler({"input": {"tarea": "muestras", "generos": ["cuchillos", "no_existe"]}}, sb=sb)
	check("RunPod: hace las pedidas y dice cuáles faltan", r2.get("hechas") == ["cuchillos"] and "cuchillos" not in r2.get("faltan", [])
		and "diferencias" not in r2.get("faltan", []) and "plataformas" in r2.get("faltan", []), json.dumps(r2)[:300])
	check("el índice suma, no se pisa", set(muestras.indice_remoto(sb)) == {"diferencias", "numeros", "cuchillos"})
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

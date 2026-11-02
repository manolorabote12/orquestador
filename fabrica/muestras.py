"""Partidas de muestra: un juego pequeño de cada género para «Probar» en el taller ANTES de fabricar.

En la app, cada tipo de juego del catálogo tiene un botón «Probar»: abre al instante una partida de
muestra de ese género con el mismo reproductor de «Jugar ya» (el motor web común + un paquete
index.pck de ~1 MB). Así quien no sabe qué es un «tower defense» o un «merge» lo juega 30 segundos
antes de gastar tuercas.

Los paquetes viven en el bucket público "motor", junto al motor web:
	motor/muestras/<genero>.pck     el juego de muestra de ese género
	motor/muestras/indice.json      {"<genero>": {"titulo", "v", "mb"}, ...} (la app solo enseña
	                                «Probar» en los géneros que están aquí)

Cada muestra se fabrica con la plantilla de éxito del género (o con su marca de género si no tiene),
pasa por la misma validación con bots que cualquier juego y se exporta solo para web. Con la
directora simulada no cuesta nada de IA; el arte puede ser el de verdad (GPU de RunPod) o el simulado.

	python -m muestras --solo diferencias,arquero            fabrica y deja los .pck en ./muestras_web
	python -m muestras --faltan --subir                      solo las que aún no están en el bucket
	python -m muestras --todas --subir --arte-real           todas otra vez (tras cambiar el kit)

En la nube lo lanza el despliegue: {"input": {"tarea": "muestras"}} (runpod_handler.py).
"""

import argparse
import json
import os
import shutil
import sys
import time
from pathlib import Path

import cadena
import generos
import plantillas

CARPETA = "muestras"
## Géneros que no tienen muestra: el «a medida» se inventa para cada juego.
SIN_MUESTRA = {"a_medida"}


def lista_generos() -> list[str]:
	"""Todos los géneros con muestra, en el orden del catálogo de la app (los primeros, los clásicos)."""
	return [g for g in reversed(generos.ORDEN) if g not in SIN_MUESTRA]


def idea_muestra(genero: str) -> str:
	"""La idea con la que se fabrica la muestra: la primera plantilla de éxito del género (la que
	mejor lo representa) o, si no tiene, la marca de género con su frase."""
	for pid, p in plantillas.PLANTILLAS.items():
		if p.get("genero") == genero and not p.get("giros"):
			return plantillas.idea_de(pid)
	frase = generos.GENEROS[genero].get("frase", ("", ""))[0] or generos.GENEROS[genero]["etiqueta"]
	return f"[gancho:{genero}:] {frase}"


def nombre_muestra(genero: str) -> str:
	"""Lo que se lee en la pantalla de título de la muestra: el nombre corto del género."""
	g = generos.GENEROS[genero]
	return str(g.get("etiqueta", genero)).split(":")[0].strip().capitalize()[:40]


def fabricar_muestra(genero: str, salida: Path, simulado: bool = True, arte_simulado: bool = True,
		comfy: str = "", semilla: int = 11) -> dict:
	"""Fabrica la muestra de un género y devuelve {"pck": ruta, "titulo", "mb"}."""
	import aprendizaje
	carpeta = salida / genero
	shutil.rmtree(carpeta, ignore_errors=True)
	carpeta.mkdir(parents=True)
	args = argparse.Namespace(
		idea=idea_muestra(genero), salida=str(carpeta), simulado=simulado, arte_simulado=arte_simulado,
		comfy=comfy or os.environ.get("ORQ_COMFY", "http://127.0.0.1:8188"), crear=cadena.flujo_arte("crear"),
		editar=cadena.flujo_arte("editar"), lado=1024, semilla=semilla, apk=False, capturas=False, web=True,
		ficha=False, clip=False, marketing=False, muestra=nombre_muestra(genero))
	## Las muestras no son juegos de nadie: que no cuenten para lo aprendido de las fabricaciones.
	anotar = aprendizaje.anotar_fabricacion
	aprendizaje.anotar_fabricacion = lambda *a, **k: None
	try:
		inf = cadena.fabricar(args)
	finally:
		aprendizaje.anotar_fabricacion = anotar
	if not inf.get("web"):
		raise cadena.ErrorCadena(f"{genero}: la fábrica no exportó la versión web")
	pck = Path(inf["web"])
	final = salida / f"{genero}.pck"
	shutil.copy(pck, final)
	return {"pck": str(final), "titulo": inf.get("titulo", genero), "mb": round(final.stat().st_size / 1e6, 2)}


def indice_remoto(sb) -> dict:
	"""El índice publicado ({} si aún no hay)."""
	import tempfile
	try:
		f = sb.bajar(f"{CARPETA}/indice.json", Path(tempfile.mkdtemp(prefix="orq_muestras_")) / "indice.json", bucket="motor")
		datos = json.loads(f.read_text(encoding="utf-8"))
		return datos if isinstance(datos, dict) else {}
	except Exception:  # noqa: BLE001 - sin índice todavía: se empieza de cero
		return {}


def hacer(lista: list[str], salida: Path, sb=None, simulado: bool = True, arte_simulado: bool = True, comfy: str = "",
		limite_s: float = 0.0) -> dict:
	"""Fabrica (y sube, si hay conexión) las muestras de la lista. Devuelve el índice resultante y
	los fallos. Un fallo en un género no para los demás."""
	inicio = time.time()
	indice = indice_remoto(sb) if sb is not None else {}
	fallos: dict[str, str] = {}
	hechas: list[str] = []
	version = time.strftime("%Y%m%d%H%M")
	for g in lista:
		if limite_s and time.time() - inicio > limite_s:
			fallos[g] = "sin tiempo en esta tanda"
			continue
		cadena.evento("muestra", "inicio", f"Muestra de «{g}»...")
		try:
			r = fabricar_muestra(g, salida, simulado, arte_simulado, comfy)
		except Exception as e:  # noqa: BLE001 - se apunta y se sigue con el siguiente género
			fallos[g] = str(e)[:300]
			cadena.evento("muestra", "aviso", f"«{g}» sin muestra: {fallos[g][:120]}")
			continue
		if sb is not None:
			sb.subir(f"{CARPETA}/{g}.pck", Path(r["pck"]), bucket="motor")
		indice[g] = {"titulo": r["titulo"], "v": version, "mb": r["mb"]}
		hechas.append(g)
		cadena.evento("muestra", "ok", f"«{g}» lista ({r['mb']} MB)")
	destino = salida / "indice.json"
	destino.write_text(json.dumps(indice, ensure_ascii=False, indent=1), encoding="utf-8")
	if sb is not None and hechas:
		sb.subir(f"{CARPETA}/indice.json", destino, bucket="motor")
	return {"indice": indice, "hechas": hechas, "fallos": fallos, "segundos": round(time.time() - inicio, 1)}


def main(argv: list[str] | None = None) -> int:
	p = argparse.ArgumentParser(description="Partidas de muestra de cada género para «Probar» en la app")
	p.add_argument("--solo", default="", help="Géneros separados por comas")
	p.add_argument("--todas", action="store_true", help="Todos los géneros")
	p.add_argument("--faltan", action="store_true", help="Solo los que no están en el índice publicado")
	p.add_argument("--subir", action="store_true", help="Sube los .pck y el índice al bucket 'motor'")
	p.add_argument("--arte-real", action="store_true", help="Arte de verdad (ORQ_COMFY o runpod://) en vez del simulado")
	p.add_argument("--directora-real", action="store_true", help="Diseño con la IA (cuesta un poco) en vez del simulado")
	p.add_argument("--salida", default=str(cadena.RAIZ.parent / "muestras_web"))
	a = p.parse_args(argv)
	sb = None
	if a.subir or a.faltan:
		from trabajador import Supabase
		url, clave = os.environ.get("SUPABASE_URL", ""), os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
		if not url or not clave:
			print("Faltan SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY", file=sys.stderr)
			return 2
		sb = Supabase(url, clave)
	todos = lista_generos()
	if a.solo:
		lista = [g.strip() for g in a.solo.split(",") if g.strip()]
		malos = [g for g in lista if g not in todos]
		if malos:
			print(f"Géneros desconocidos: {malos}", file=sys.stderr)
			return 2
	elif a.todas or a.faltan:
		lista = todos
	else:
		p.print_help()
		return 2
	if a.faltan and sb is not None:
		ya = indice_remoto(sb)
		lista = [g for g in lista if g not in ya]
	salida = Path(a.salida)
	salida.mkdir(parents=True, exist_ok=True)
	r = hacer(lista, salida, sb if a.subir else None, simulado=not a.directora_real, arte_simulado=not a.arte_real)
	print(json.dumps({"hechas": r["hechas"], "fallos": r["fallos"], "segundos": r["segundos"]}, ensure_ascii=False, indent=1))
	return 0 if not r["fallos"] else 1


if __name__ == "__main__":
	sys.exit(main())

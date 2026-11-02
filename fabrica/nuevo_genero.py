"""Crea el esqueleto de un genero nuevo y lo conecta en toda la cadena.

	python -m nuevo_genero laberinto maze --claves laberinto,maze,mazmorra \\
		--etiqueta "laberinto: recoge todo sin pincharte" \\
		--frase-es "Recorre laberintos y recoge cada moneda sin pisar los pinchos" \\
		--frase-en "Explore mazes and grab every coin without touching the spikes"

	python -m nuevo_genero laberinto maze --probar     (ademas fabrica un juego de prueba)
	python -m nuevo_genero --quitar laberinto maze     (lo deshace todo)

Que hace:
	1 - Copia la plantilla (un juego de cuadricula ya jugable, con analizador y bot) a OrqKit:
	    kit/<kit>/<kit>_game.gd, kit/<kit>/<kit>_map.gd, qa/<kit>_bot.gd y scenes/<kit>.tscn.
	2 - Lo registra en el kit (kit/genres.gd) y en la fabrica (generos.py).
	3 - Anade su generador de niveles a niveles/generador.py.
	4 - Lo anade a los esquemas de la directora y del taller y sincroniza el servidor.
Despues: cambia las reglas de la plantilla por las de tu genero (GENEROS-LEEME.md).
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
KIT = RAIZ.parent / "orqkit"
PLANTILLA = RAIZ / "plantillas" / "genero"
MARCA = "## NUEVOS GENEROS (nuevo_genero.py escribe encima de esta linea)"
ESQUEMAS = [RAIZ / "director" / "diseno.schema.json", RAIZ / "director" / "cambios.schema.json"]


def _pascal(t: str) -> str:
	return "".join(p.capitalize() for p in t.split("_"))


def _archivos(kit: str) -> dict[Path, Path]:
	"""Plantilla -> destino en OrqKit."""
	return {
		PLANTILLA / "kit" / "__ID___game.gd": KIT / "kit" / kit / f"{kit}_game.gd",
		PLANTILLA / "kit" / "__ID___map.gd": KIT / "kit" / kit / f"{kit}_map.gd",
		PLANTILLA / "qa" / "__ID___bot.gd": KIT / "qa" / f"{kit}_bot.gd",
		PLANTILLA / "scenes" / "__ID__.tscn": KIT / "scenes" / f"{kit}.tscn",
	}


def _rellenar(texto: str, es: str, kit: str) -> str:
	return texto.replace("__ID__", kit).replace("__CLASS__", _pascal(kit)).replace("__ES__", es)


def _esquemas(es: str, anadir: bool) -> None:
	"""Anade (o quita) el genero de los 'enum' de genero de los esquemas."""
	def tocar(nodo):
		if isinstance(nodo, dict):
			for k, v in nodo.items():
				if k == "genero" and isinstance(v, dict) and isinstance(v.get("enum"), list) and "plataformas" in v["enum"]:
					if anadir and es not in v["enum"]:
						v["enum"].append(es)
					if not anadir and es in v["enum"]:
						v["enum"].remove(es)
				tocar(v)
		elif isinstance(nodo, list):
			for v in nodo:
				tocar(v)
	for p in ESQUEMAS:
		datos = json.loads(p.read_text(encoding="utf-8"))
		tocar(datos)
		p.write_text(json.dumps(datos, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")


def _entrada_registro(a: argparse.Namespace) -> str:
	es, kit = a.es, a.kit
	textos = {"swipe_move_hint": "Desliza para moverte", f"{kit}_lost": "¡Pinchazo!",
		f"{kit}_hint": "Recoge todas las monedas sin pisar los pinchos"}
	claves = [c.strip() for c in (a.claves or es).split(",") if c.strip()]
	campos = {
		"kit": kit, "etiqueta": a.etiqueta or es,
		"jefe": False, "disparo": False, "poderes": False, "extras": False, "enemigos": False, "enemigos_fijos": False,
		"corre_solo": False, "estricto": True, "generar": f"generar_{es}", "parametros": None, "enemigos_nivel": False,
		"textos": textos,
		"frase": (a.frase_es or f"Un juego de {es} hecho a tu medida", a.frase_en or f"A {es} game made just for you"),
		"claves": claves,
		"pedir": a.pedir or "|".join(re.escape(c) for c in claves),
		"convertir": a.convertir or f"lo convierto en {es}, y rehago los niveles",
		"no_puedo": a.no_puedo or f"En un juego de {es} eso no se puede: cambia las reglas del genero para permitirlo.",
		"clip_saltar": 0.5,
		"corto": ((a.frase_es or es)[:30], (a.frase_en or es)[:30]),
		"aso": (",".join(claves)[:60], ",".join(claves)[:60]),
	}
	lineas = [f"\t## >> genero {es}", f"\t{json.dumps(es)}: {{"]
	for k, v in campos.items():
		if isinstance(v, tuple):
			txt = "(" + ", ".join(json.dumps(x, ensure_ascii=False) for x in v) + ")"
		elif v is None:
			txt = "None"
		elif isinstance(v, bool):
			txt = "True" if v else "False"
		else:
			txt = json.dumps(v, ensure_ascii=False)
		if k == "pedir":
			txt = "r" + json.dumps(v, ensure_ascii=False).replace("\\\\", "\\")
		lineas.append(f"\t\t{json.dumps(k)}: {txt},")
	lineas += ["\t},", f"\t## << genero {es}"]
	return "\n".join(lineas) + "\n"


def crear(a: argparse.Namespace) -> None:
	es, kit = a.es, a.kit
	if not re.fullmatch(r"[a-z][a-z0-9_]{2,20}", es) or not re.fullmatch(r"[a-z][a-z0-9_]{2,20}", kit):
		sys.exit("Los nombres van en minusculas, sin espacios ni tildes (p. ej. laberinto maze)")
	sys.path.insert(0, str(RAIZ))
	import generos
	if es in generos.GENEROS or any(v["kit"] == kit for v in generos.GENEROS.values()):
		sys.exit(f"Ya existe un genero '{es}' o con kit '{kit}'")
	## 1 - Archivos del kit desde la plantilla.
	for src, dst in _archivos(kit).items():
		if dst.exists():
			sys.exit(f"Ya existe {dst}")
	for src, dst in _archivos(kit).items():
		dst.parent.mkdir(parents=True, exist_ok=True)
		dst.write_text(_rellenar(src.read_text(encoding="utf-8"), es, kit), encoding="utf-8")
		print("creado", dst.relative_to(KIT.parent))
	## 2 - Registro del kit.
	genres = KIT / "kit" / "genres.gd"
	linea = (f'\t"{kit}": {{"scene": "res://scenes/{kit}.tscn", "analyzer": "res://kit/{kit}/{kit}_map.gd", '
		f'"strict": true, "enemy_art": false}},\n')
	t = genres.read_text(encoding="utf-8")
	genres.write_text(t.replace("\t" + MARCA, linea + "\t" + MARCA), encoding="utf-8")
	## 3 - Registro de la fabrica (el genero nuevo va primero en la prioridad de palabras clave).
	reg = RAIZ / "generos.py"
	t = reg.read_text(encoding="utf-8")
	t = t.replace("\t" + MARCA, _entrada_registro(a) + "\t" + MARCA)
	t = t.replace("ORDEN = [", f'ORDEN = ["{es}", ', 1)
	reg.write_text(t, encoding="utf-8")
	## 4 - Generador de niveles.
	gen = RAIZ / "niveles" / "generador.py"
	gen.write_text(gen.read_text(encoding="utf-8").rstrip("\n") + "\n" + _rellenar((PLANTILLA / "generador.py.txt").read_text(encoding="utf-8"), es, kit), encoding="utf-8")
	## 5 - Esquemas y servidor.
	_esquemas(es, True)
	subprocess.run([sys.executable, str(RAIZ / "sincronizar_servidor.py")], check=True)
	print(f"\nGenero '{es}' (kit '{kit}') creado y conectado. Siguiente paso: GENEROS-LEEME.md")


def quitar(a: argparse.Namespace) -> None:
	es, kit = a.es, a.kit
	for dst in _archivos(kit).values():
		for f in (dst, dst.with_name(dst.name + ".uid")):
			if f.exists():
				f.unlink()
	carpeta = KIT / "kit" / kit
	if carpeta.exists():
		shutil.rmtree(carpeta)
	genres = KIT / "kit" / "genres.gd"
	genres.write_text("".join(l for l in genres.read_text(encoding="utf-8").splitlines(True) if not l.startswith(f'\t"{kit}": ')), encoding="utf-8")
	bloque = re.compile(r"\n?[ \t]*## >> genero " + re.escape(es) + r"\b.*?## << genero " + re.escape(es) + r"\n", re.S)
	reg = RAIZ / "generos.py"
	t = bloque.sub("\n", reg.read_text(encoding="utf-8"), count=1).replace(f'"{es}", ', "", 1)
	reg.write_text(t.replace("\n\n\t" + MARCA, "\n\t" + MARCA), encoding="utf-8")
	gen = RAIZ / "niveles" / "generador.py"
	gen.write_text(bloque.sub("", gen.read_text(encoding="utf-8")).rstrip("\n") + "\n", encoding="utf-8")
	_esquemas(es, False)
	subprocess.run([sys.executable, str(RAIZ / "sincronizar_servidor.py")], check=True)
	print(f"Genero '{es}' quitado")


def probar(es: str) -> int:
	"""Fabrica un juego con la directora y el arte simulados y comprueba que los bots lo pasan."""
	sys.path.insert(0, str(RAIZ))
	import importlib

	import generos
	importlib.reload(generos)
	clave = generos.GENEROS[es]["claves"][0]
	r = subprocess.run([sys.executable, "-m", "cadena", f"un juego de {clave} con un robot valiente", "--simulado",
		"--arte-simulado", "--salida", str(RAIZ.parent / "proyectos_prueba" / f"genero_{es}")], cwd=RAIZ, capture_output=True, text=True)
	fin = [l for l in r.stdout.splitlines() if '"paso": "fin"' in l or '"paso": "diseno", "estado": "ok"' in l]
	print("\n".join(fin) or (r.stdout + r.stderr)[-1500:])
	ok = r.returncode == 0 and any('"paso": "fin", "estado": "ok"' in l for l in fin)
	print("PRUEBA SUPERADA" if ok else "LA PRUEBA HA FALLADO")
	return 0 if ok else 1


def main() -> int:
	p = argparse.ArgumentParser(description="Crea (o quita) un genero nuevo conectado en toda la cadena")
	p.add_argument("es", help="Nombre del genero en la fabrica, en espanol (p. ej. laberinto)")
	p.add_argument("kit", help="Nombre del genero en OrqKit, en ingles (p. ej. maze)")
	p.add_argument("--claves", help="Palabras de la idea que lo eligen, separadas por comas")
	p.add_argument("--etiqueta")
	p.add_argument("--frase-es")
	p.add_argument("--frase-en")
	p.add_argument("--pedir", help="Expresion regular para pedirlo en el taller")
	p.add_argument("--convertir")
	p.add_argument("--no-puedo")
	p.add_argument("--quitar", action="store_true", help="Deshace un genero creado con este comando")
	p.add_argument("--probar", action="store_true", help="Fabrica un juego de prueba del genero")
	a = p.parse_args()
	if a.quitar:
		quitar(a)
		return 0
	sys.path.insert(0, str(RAIZ))
	import generos
	if a.es not in generos.GENEROS:
		crear(a)
	if a.probar:
		subprocess.run(["godot", "--headless", "--path", str(KIT), "--import"], capture_output=True, timeout=300)
		return probar(a.es)
	return 0


if __name__ == "__main__":
	sys.exit(main())

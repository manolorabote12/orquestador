"""Esquemas del director al dia con el codigo: cada giro (giros.GIROS) y cada genero (generos.GENEROS)
tiene que estar en los enum de diseno.schema.json y cambios.schema.json. En noviembre se anadio el
giro «modos» sin ponerlo en el esquema y la fabrica rechazo el diseno de Marea Alta.
Rapida y sin dependencias: corre en el paso «comprobar» del despliegue, antes de construir imagenes.

	python fabrica/pruebas/prueba_esquemas.py
"""

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ))


def enums(nodo, out: list) -> list:
	if isinstance(nodo, dict):
		if isinstance(nodo.get("enum"), list):
			out.append(set(str(x) for x in nodo["enum"]))
		for v in nodo.values():
			enums(v, out)
	elif isinstance(nodo, list):
		for v in nodo:
			enums(v, out)
	return out


def main() -> int:
	import generos
	import giros
	fallos = 0
	for nombre in ("diseno.schema.json", "cambios.schema.json"):
		es = enums(json.loads((RAIZ / "director" / nombre).read_text(encoding="utf-8")), [])
		for que, todos in (("giros", set(giros.GIROS)), ("generos", set(generos.GENEROS))):
			## El enum que mas se parece a la lista del codigo es el suyo.
			mejor = max(es, key=lambda e: len(e & todos), default=set())
			faltan = sorted(todos - mejor)
			if faltan:
				fallos += 1
				print(f"FALLO {nombre}: faltan {que} en el esquema: {', '.join(faltan)}")
			else:
				print(f"OK    {nombre}: {len(todos)} {que}")
	## La biblia de arte de cada genero (con sus giros) cabe en su esquema (14 nov: el RPG de
	## equipo pedia 17 personajes y el esquema admitia 12: «La Biblia no es valida» en la fabrica).
	from arte import biblia as bib
	from director import director, simulado
	for gen in sorted(generos.GENEROS):
		for gi in ([[]] + [[g] for g in sorted(giros.GIROS) if gen in str(giros.GIROS[g])]):
			d = simulado.disenar("prueba")
			d["genero"] = gen
			d["giros"] = gi
			try:
				b = director.a_biblia(d)
				bib.recortar(b, 36, 0)
				bib.validar(b)
			except Exception as e:  # noqa: BLE001
				fallos += 1
				print(f"FALLO biblia de {gen} {gi}: {str(e)[:300]}")
	print("OK    biblias de todos los generos" if not fallos else "")
	print("== %d fallos ==" % fallos)
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

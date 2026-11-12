"""Directora creativa (director/conceptos.py) y laboratorio, sin IA: respuestas falsas del modelo."""

import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import laboratorio  # noqa: E402
from director import conceptos, director, llm  # noqa: E402

fallos = 0


def check(nombre, ok, extra=""):
	global fallos
	print(("  OK   " if ok else "  FALLO ") + nombre + ("" if ok else f" ({extra})"))
	if not ok:
		fallos += 1


def concepto(g, gancho):
	return {"titulo": "T", "genero": g, "gancho": gancho, "giro": "x", "momento_estrella": "x", "primer_minuto": "x",
		"progresion": "x", "heroe": "x", "mundo": "x", "enemigos": "x", "referencias": ["Clash"],
		"notas": {"gancho": 7, "claridad": 8, "retencion": 6, "originalidad": 7, "encaje": 9}}


bueno = {"conceptos": [concepto("reino", "a"), concepto("torres", "b"), concepto("aldea", "c")], "elegido": 0,
	"por_que": "x", "final": {k: v for k, v in concepto("reino", "un reino que resiste").items() if k != "notas"}}
check("validar: concepto bueno sin errores", conceptos.validar(bueno) == [], conceptos.validar(bueno))
malo = {**bueno, "conceptos": [concepto("kingshot", "a"), concepto("torres", "a"), concepto("aldea", "a")]}
e = conceptos.validar(malo)
check("validar: genero inventado y ganchos repetidos", any("kingshot" in x for x in e) and any("repiten" in x for x in e), e)
check("suma de notas", conceptos.suma(bueno["conceptos"][0]) == 37)
check("catalogo sin a_medida y con reino", "- reino:" in conceptos.catalogo() and "- a_medida:" not in conceptos.catalogo())

## explorar: el modelo falla la primera vez y corrige; si vuelve a fallar, None (el juego sigue).
respuestas = [malo, bueno]
llamadas = []


def falso(modelo, sistema, mensajes, herramienta, gasto, nota, max_tokens=3000, reintentos=3):
	llamadas.append(nota)
	return respuestas.pop(0)


real = llm.llamar_herramienta
llm.llamar_herramienta = falso
x = conceptos.explorar("un reino", llm.Gasto(), ["reino"])
check("explorar: corrige con los errores", x is bueno and llamadas == ["conceptos", "conceptos_correccion"], llamadas)
respuestas = [malo, malo]
check("explorar: dos fallos -> None", conceptos.explorar("un reino", llm.Gasto()) is None)


def roto(*a, **k):
	raise llm.ErrorIA("caida")


llm.llamar_herramienta = roto
check("explorar: la IA caida -> None", conceptos.explorar("un reino", llm.Gasto()) is None)
llm.llamar_herramienta = real

g = conceptos.guia(bueno)
check("guia: lleva genero y gancho del final", "genero: reino" in g and "un reino que resiste" in g)

## Laboratorio: el juez a ciegas devuelve las notas a su dueno aunque cambie el orden.
d_a = {"titulo": "A", "genero": "torres"}
d_b = {"titulo": "B", "genero": "reino"}
notas = lambda n: {k: n for k in laboratorio.CRITERIOS}  # noqa: E731
vistos = []


def juez(modelo, sistema, mensajes, herramienta, gasto, nota, max_tokens=3000, reintentos=3):
	txt = mensajes[0]["content"]
	b_es_1 = txt.index('"titulo": "B"') < txt.index('"titulo": "A"')
	vistos.append(b_es_1)
	## El juez siempre prefiere B (le da 9) frente a A (5).
	return {"notas_1": notas(9 if b_es_1 else 5), "notas_2": notas(5 if b_es_1 else 9), "ganador": 1 if b_es_1 else 2, "por_que": "x"}


llm.llamar_herramienta = juez
rng = random.Random(1)
rs = [laboratorio.juzgar("idea", d_a, d_b, rng, llm.Gasto()) for _ in range(8)]
llm.llamar_herramienta = real
check("juez: orden aleatorio", len(set(vistos)) == 2, vistos)
check("juez: notas y ganador vuelven a su dueno", all(r["gana"] == "B" and r["notas_b"]["gancho"] == 9 and r["notas_a"]["gancho"] == 5 for r in rs))
filas = [{"idea": "i", "a": {"titulo": "A", "genero": "g", "lema": ""}, "b": {"titulo": "B", "genero": "g", "lema": ""}, "concepto": bueno, **rs[0]}]
inf = laboratorio.informe(filas, 0.12)
check("informe: resumen y tabla", "B gana 1 de 1" in inf and "| gancho | 5.0 | 9.0 |" in inf, inf[:300])

## El diseno simulado no llama a la directora creativa (las pruebas no gastan IA).
director.disenar("un juego de gatos", True, llm.Gasto())
check("simulado: sin concepto", director.ULTIMO_CONCEPTO is None)

## Modo estudio: la marca se quita y los ajustes valen solo para ese juego.
import argparse  # noqa: E402
import os  # noqa: E402

import cadena  # noqa: E402

check("estudio: delante", cadena.separar_estudio("[estudio] un gato") == ("un gato", True))
check("estudio: detras de otra marca", cadena.separar_estudio("[a_medida] [estudio] un gato") == ("[a_medida] un gato", True))
check("estudio: sin marca", cadena.separar_estudio("un gato [estudio]") == ("un gato [estudio]", False))
visto = {}
real_f = cadena._fabricar
cadena._fabricar = lambda a: visto.update(idea=a.idea, c=os.environ.get("ORQ_CONCEPTOS"), r=os.environ.get("ORQ_A_MEDIDA_RONDAS")) or {}
os.environ.pop("ORQ_CONCEPTOS", None)
cadena.fabricar(argparse.Namespace(idea="[estudio] un dragon"))
check("estudio: ajustes durante el juego", visto == {"idea": "un dragon", "c": "1", "r": "8"}, visto)
check("estudio: y se quitan al terminar", os.environ.get("ORQ_CONCEPTOS") is None and os.environ.get("ORQ_A_MEDIDA_RONDAS") is None)
cadena._fabricar = real_f

print(f"== {fallos} fallos ==")
sys.exit(1 if fallos else 0)

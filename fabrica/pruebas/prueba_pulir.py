"""Bucle de pulido (pulir.py) con un juego simulado de verdad: capturas reales, critica y mods falsos."""

import argparse
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import agente_mods  # noqa: E402
import cadena  # noqa: E402
import pulir  # noqa: E402
from arte import critica  # noqa: E402
from director import llm  # noqa: E402

fallos = 0


def check(nombre, ok, extra=""):
	global fallos
	print(("  OK   " if ok else "  FALLO ") + nombre + ("" if ok else f" ({extra})"))
	if not ok:
		fallos += 1


## Puras
c5 = {"nota": 5, "problemas": [{"tipo": "efectos_pobres", "detalle": "sin particulas"}, {"tipo": "texto_cortado", "detalle": "x"}], "lo_mejor": ""}
i = pulir.instruccion_mod(c5)
check("instruccion: solo con problemas de vida/efectos", i and "sin particulas" in i and "texto_cortado" not in i)
check("instruccion: nada que arreglar con un mod", pulir.instruccion_mod({"nota": 5, "problemas": [{"tipo": "texto_cortado", "detalle": "x"}]}) is None)
check("mejor: igual o mas se queda", pulir.mejor({"nota": 6}, {"nota": 6}) and not pulir.mejor({"nota": 5}, {"nota": 6}) and not pulir.mejor(None, {"nota": 1}))
os.environ.pop("ORQ_PULIR_RONDAS", None)
check("apagado por defecto", pulir.pulir(Path("."), {}, 1, llm.Gasto()) is None)

## Un juego simulado de verdad (laberinto: rapido).
tmp = Path(tempfile.mkdtemp())
inf = cadena.fabricar(argparse.Namespace(idea="un explorador en un laberinto de cristal buscando la salida", salida=str(tmp),
	simulado=True, arte_simulado=True, comfy="", crear="", editar="", lado=256, semilla=3, apk=False, capturas=False))
proyecto = Path(inf["proyecto"]) if "proyecto" in inf else next(p for p in tmp.iterdir() if (p / "game.json").exists())
diseno = json.loads((proyecto / "fabrica" / "diseno.json").read_text(encoding="utf-8"))
game0 = (proyecto / "game.json").read_text(encoding="utf-8")

notas = []
critica.criticar = lambda caps, t, g, gasto: (dict(c5, nota=notas.pop(0)) if caps and notas else None)
real_prog = agente_mods.programar
agente_mods.programar = lambda p, instr, sim, gasto, rondas=3: real_prog(p, instr, True, gasto, rondas)

os.environ["ORQ_PULIR_RONDAS"] = "1"
notas[:] = [5, 6]
r = pulir.pulir(proyecto, diseno, 3, llm.Gasto())
mods = sorted(m.name for m in (proyecto / "mods").glob("*.gd")) if (proyecto / "mods").exists() else []
check("mejora: el mod se queda y la nota sube", r and r["nota"] == 6 and r["nota_inicial"] == 5 and len(r["cambios"]) == 1 and mods, (r, mods))
game1 = (proyecto / "game.json").read_text(encoding="utf-8")

notas[:] = [5, 4]
r = pulir.pulir(proyecto, diseno, 3, llm.Gasto())
mods2 = sorted(m.name for m in (proyecto / "mods").glob("*.gd"))
check("empeora: se deshace (mods y game.json como antes)", r and r["nota"] == 5 and not r["cambios"] and mods2 == mods
	and (proyecto / "game.json").read_text(encoding="utf-8") == game1, (r, mods2))

notas[:] = [9]
r = pulir.pulir(proyecto, diseno, 3, llm.Gasto())
check("ya en el objetivo: no toca nada", r and r["rondas"] == 0 and r["nota"] == 9, r)
check("pulido.json en la ficha", (proyecto / "fabrica" / "pulido.json").exists())
agente_mods.programar = real_prog

## Genero a medida: Claude (falso) devuelve custom_game.gd con un cambio; el bot lo vuelve a jugar.
import genero_usuario  # noqa: E402
tmp2 = Path(tempfile.mkdtemp())
cadena.fabricar(argparse.Namespace(idea="[a_medida] una ardilla que recoge bellotas en un tablero", salida=str(tmp2),
	simulado=True, arte_simulado=True, comfy="", crear="", editar="", lado=256, semilla=3, apk=False, capturas=False))
pam = next(p for p in tmp2.iterdir() if (p / "game.json").exists())
dam = json.loads((pam / "fabrica" / "diseno.json").read_text(encoding="utf-8"))
real_ll = llm.llamar_herramienta
pedido = {}


def falso(modelo, sistema, mensajes, herramienta, gasto, nota, max_tokens=3000, reintentos=3):
	pedido["imagenes"] = sum(1 for b in mensajes[0]["content"] if b.get("type") == "image")
	codigo = genero_usuario.archivos_actuales(pam)["juego_gd"]
	return {"juego_gd": codigo + "\n## pulido por la prueba\n", "cambios": "brillos"}


llm.llamar_herramienta = falso
notas[:] = [5, 7]
r = pulir.pulir(pam, dam, 3, llm.Gasto())
llm.llamar_herramienta = real_ll
check("a medida: codigo pulido, bot lo supera y se queda", r and r["nota"] == 7 and r["cambios"] == ["brillos"]
	and "pulido por la prueba" in genero_usuario.archivos_actuales(pam)["juego_gd"], r)
check("a medida: Claude ve las capturas", pedido.get("imagenes", 0) >= 1, pedido)
os.environ.pop("ORQ_PULIR_RONDAS", None)
shutil.rmtree(tmp, ignore_errors=True)
shutil.rmtree(tmp2, ignore_errors=True)
print(f"== {fallos} fallos ==")
sys.exit(1 if fallos else 0)

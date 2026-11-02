"""Generos hechos a medida (capa 3): revision de seguridad, generador GDScript del proyecto y un
juego entero fabricado con «[a_medida]» y superado por su bot (con la directora simulada)."""

import argparse
import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import cadena  # noqa: E402
import genero_usuario  # noqa: E402

fallos = 0


def check(nombre: str, ok: bool, extra: str = "") -> None:
	global fallos
	print(("  OK   " if ok else "  FALLO ") + nombre + (f"  ({extra})" if extra else ""))
	if not ok:
		fallos += 1


def main() -> int:
	print("== Generos hechos a medida ==")
	base = genero_usuario.archivos_actuales(cadena.KIT)
	check("la plantilla pasa la revision", not genero_usuario.revisar(base), str(genero_usuario.revisar(base)))
	malo = dict(base, mapa_gd=base["mapa_gd"] + "\nstatic func x() -> void:\n\tOS.execute(\"rm\", [])\n")
	check("codigo peligroso: rechazado antes de ejecutar", any("seguridad" in e for e in genero_usuario.revisar(malo)))
	sin_gen = dict(base, mapa_gd=base["mapa_gd"].replace("static func generate(", "static func generar_otra("))
	check("sin generate(): rechazado", any("generate" in e for e in genero_usuario.revisar(sin_gen)))
	con_kit = dict(base, mapa_gd=base["mapa_gd"] + "\nstatic func y() -> String:\n\treturn Kit.text(\"a\", \"b\")\n")
	check("el mapa no puede usar autoloads", any("autoloads" in e for e in genero_usuario.revisar(con_kit)))
	tmp = Path(tempfile.mkdtemp())
	inf = cadena.fabricar(argparse.Namespace(idea="[a_medida] un juego donde una ardilla recoge bellotas en un bosque con trampas",
		salida=str(tmp), simulado=True, arte_simulado=True, comfy="", crear="", editar="", lado=512, semilla=3, apk=False, capturas=False))
	p = Path(inf["proyecto"])
	d = json.loads((p / "fabrica" / "diseno.json").read_text(encoding="utf-8"))
	g = json.loads((p / "game.json").read_text(encoding="utf-8"))
	check("la idea con [a_medida] hace un genero a medida", d.get("genero") == "a_medida" and "ardilla" in d.get("a_medida", {}).get("descripcion", ""))
	check("el juego usa el kit propio del proyecto", g.get("genre") == "custom" and (p / "kit" / "custom" / "custom_map.gd").exists())
	vari = d.get("a_medida_mapas") or []
	check("los niveles salen del generador GDScript del proyecto (con variantes)", len(vari) == len(g["levels"]) and all(len(v) >= 2 for v in vari),
		str([len(v) for v in vari]))
	check("cada nivel es una de sus variantes", all(lv["map"] in [list(x) for x in vari[i]] for i, lv in enumerate(g["levels"])))
	check("el bot supera el juego entero", bool(inf.get("ok")) and all(n.get("bot_completa") for n in inf["validacion"]["niveles"]))
	variantes, errores, _ = genero_usuario.generar_mapas(p, 3, 0.5)
	check("el generador del proyecto responde desde la fabrica", len(variantes) == 3 and all(variantes), str(errores[:2]))
	## Las rondas: si la IA entrega algo que no pasa (aqui, codigo peligroso), recibe el error y lo corrige.
	llamadas = []

	def ia_falsa(modelo, sistema, mensajes, herramienta, gasto, motivo, max_tokens=0):
		llamadas.append(mensajes[0]["content"])
		if len(llamadas) == 1:
			return dict(malo, notas="primera version")
		return dict(base, notas="una ardilla que recoge bellotas")
	original = genero_usuario.llm.llamar_herramienta
	genero_usuario.llm.llamar_herramienta = ia_falsa
	try:
		r = genero_usuario.crear(p, d, 3, False, genero_usuario.llm.Gasto())
	finally:
		genero_usuario.llm.llamar_herramienta = original
	check("si la IA falla, recibe el error y lo corrige en la siguiente ronda", r["ok"] and r["rondas"] == 2 and "seguridad" in llamadas[1], str(r))
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

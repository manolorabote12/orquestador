"""Modo experto: lo que sube el autor se revisa antes de tocar nada (experto.py) y lo cambiado a mano en
game.json sobrevive a los cambios del taller (cadena.mezclar / diferencia).

	python -m pruebas.prueba_experto
"""

import json
import sys
import tempfile
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import cadena  # noqa: E402
import experto  # noqa: E402

FALLOS: list[str] = []


def ok(cond: bool, nombre: str, extra: str = "") -> None:
	print(("  OK   " if cond else "  FALLO ") + nombre + (f"  ({extra})" if extra and not cond else ""))
	if not cond:
		FALLOS.append(nombre)


def proyecto(base: Path) -> Path:
	p = base / "juego"
	(p / "scenes").mkdir(parents=True)
	(p / "mods").mkdir()
	(p / "fabrica").mkdir()
	(p / "project.godot").write_text("[application]\n", encoding="utf-8")
	(p / "game.json").write_text(json.dumps({"title": "A", "player": {"hp": 3, "run_speed": 400}, "levels": [{"map": ["..."]}]}), encoding="utf-8")
	(p / "scenes" / "a.tscn").write_text("[gd_scene format=3]\n", encoding="utf-8")
	(p / "mods" / "viejo.gd").write_text("extends Node\n", encoding="utf-8")
	return p


def hacer_zip(base: Path, nombre: str, archivos: dict[str, str], carpeta: str = "juego/") -> Path:
	z = base / nombre
	with zipfile.ZipFile(z, "w") as f:
		for rel, txt in archivos.items():
			f.writestr(carpeta + rel, txt)
	return z


def main() -> int:
	with tempfile.TemporaryDirectory() as t:
		base = Path(t)
		p = proyecto(base)
		todo = {"project.godot": "[application]\n", "game.json": (p / "game.json").read_text(encoding="utf-8"),
			"scenes/a.tscn": "[gd_scene format=3]\n", "mods/viejo.gd": "extends Node\n"}

		# 1 - Sin cambios: falla y no toca nada.
		try:
			experto.aplicar(p, hacer_zip(base, "igual.zip", todo))
			ok(False, "sin cambios: avisa")
		except experto.ErrorExperto as e:
			ok("No has cambiado nada" in str(e), "sin cambios: avisa", str(e))

		# 2 - Script de editor: rechazado (se ejecutaria al importar con el usuario del trabajador).
		malo = dict(todo, **{"scenes/b.gd": "@tool\nextends Node\n"})
		try:
			experto.aplicar(p, hacer_zip(base, "tool.zip", malo))
			ok(False, "@tool rechazado")
		except experto.ErrorExperto as e:
			ok("@tool" in str(e), "@tool rechazado", str(e))
		ok(not (p / "scenes" / "b.gd").exists(), "@tool: no se copia nada")
		malo2 = dict(todo, **{"kit/x.gd": "extends EditorPlugin\n"})
		try:
			experto.aplicar(p, hacer_zip(base, "plugin.zip", malo2))
			ok(False, "EditorPlugin rechazado")
		except experto.ErrorExperto:
			ok(True, "EditorPlugin rechazado")

		# 3 - Rutas con .. y tipos raros.
		z = base / "ruta.zip"
		with zipfile.ZipFile(z, "w") as f:
			f.writestr("juego/project.godot", "")
			f.writestr("juego/../../fuera.gd", "extends Node")
		ok(any("Ruta" in e for e in experto.revisar_zip(z)), "ruta con .. rechazada")
		try:
			experto.aplicar(p, hacer_zip(base, "exe.zip", dict(todo, **{"assets/a.so": "x"})))
			ok(False, "extension .so rechazada")
		except experto.ErrorExperto as e:
			ok(".so" in str(e), "extension .so rechazada", str(e))
		try:
			experto.aplicar(p, hacer_zip(base, "nogodot.zip", {"scenes/a.tscn": "x"}))
			ok(False, "sin project.godot")
		except experto.ErrorExperto as e:
			ok("project.godot" in str(e), "sin project.godot: avisa", str(e))

		# 4 - Cambio valido: escena cambiada, mod nuevo, mod quitado; addons y qa se ignoran.
		g2 = json.loads(todo["game.json"])
		g2["player"]["hp"] = 5
		bueno = {"project.godot": "[otra cosa]\n", "game.json": json.dumps(g2), "scenes/a.tscn": "[gd_scene format=3]\n[node name=\"A\"]\n",
			"mods/nuevo.gd": "extends Node\nfunc _ready():\n\tpass\n", "addons/x/plugin.gd": "extends EditorPlugin\n", "qa/trampa.gd": "extends Node\n"}
		previo = json.loads((p / "game.json").read_text(encoding="utf-8"))
		r = experto.aplicar(p, hacer_zip(base, "bueno.zip", bueno))
		ok(sorted(r["cambiados"]) == ["game.json", "scenes/a.tscn"], "cambiados", str(r))
		ok(r["nuevos"] == ["mods/nuevo.gd"], "nuevos", str(r))
		ok(r["borrados"] == ["mods/viejo.gd"] and not (p / "mods" / "viejo.gd").exists(), "mod quitado", str(r))
		ok("addons/x/plugin.gd" in r["ignorados"] and "qa/trampa.gd" in r["ignorados"] and "project.godot" in r["ignorados"],
			"addons, qa y project.godot ignorados", str(r))
		ok((p / "project.godot").read_text(encoding="utf-8") == "[application]\n", "project.godot intacto")
		ok(not (p / "addons").exists() and not (p / "qa").exists(), "addons y qa no se copian")
		ok("1 nuevos" in experto.resumen(r), "resumen", experto.resumen(r))

		# 5 - game.json: solo lo cambiado se guarda; se pone encima de lo generado (no los niveles).
		autor = json.loads((p / "game.json").read_text(encoding="utf-8"))
		dif = cadena.diferencia(previo, autor)
		ok(dif == {"player": {"hp": 5}}, "diferencia de game.json", str(dif))
		generado = {"title": "A", "player": {"hp": 3, "run_speed": 420}, "levels": [{"map": ["#"]}]}
		cadena.mezclar(generado, dict(dif, levels=[{"map": ["X"]}]))
		ok(generado["player"] == {"hp": 5, "run_speed": 420} and generado["levels"] == [{"map": ["#"]}], "mezcla sin tocar niveles", str(generado))

		# 6 - Encerrado: jugar va con otro usuario y sin el entorno; importar y exportar no.
		cadena.SANDBOX = "orqsb"
		try:
			c = cadena._encerrar(["godot", "--path", "x", "res://qa/validar_juego.tscn"], ("res://qa/validar_juego.tscn",))
			ok(c[0] == "setpriv" and "env" in c and "-i" in c, "jugar: encerrado", str(c))
			ok(cadena._encerrar(["godot", "--import"], ("--import",)) == ["godot", "--import"], "importar: sin encerrar")
		finally:
			cadena.SANDBOX = ""
		ok(cadena._encerrar(["godot"], ("x",)) == ["godot"], "sin SANDBOX: igual que siempre")
	print(f"== {len(FALLOS)} fallos ==")
	return 1 if FALLOS else 0


if __name__ == "__main__":
	sys.exit(main())

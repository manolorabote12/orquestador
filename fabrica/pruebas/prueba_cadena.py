"""Prueba de la cadena completa con varias ideas (directora y ComfyUI simulados).

python -m pruebas.prueba_cadena            (rapida, sin APK)
python -m pruebas.prueba_cadena --apk      (con APK de la primera idea; necesita SDK/plantillas)
"""

import argparse
import json
import sys
from pathlib import Path

import cadena
import ficha
from director import director, llm

IDEAS = [
	("un gato ninja rápido que salta por tejados de noche", "cartoon", "agil"),
	("astronauta en pixel art saltando entre planetas, difícil y competitivo", "pixel_art", "normal"),
	("juego para peques en un bosque de hadas con estilo low poly", "low_poly", "normal"),
	("un robot que huye corriendo sin parar por una ciudad en pixel art", "pixel_art", "normal"),
	("un pájaro que vuela entre tuberías de un toque", "cartoon", "normal"),
	("sobrevive a hordas de zombis en un cementerio", "cartoon", "normal"),
	("un puzle de combinar gemas en un bosque mágico", "cartoon", "normal"),
	("defiende tu castillo de oleadas de monstruos", "cartoon", "normal"),
	("carreras de coches por la ciudad", "cartoon", "normal"),
]


def main() -> int:
	ap = argparse.ArgumentParser()
	ap.add_argument("--apk", action="store_true")
	ap.add_argument("--salida", default=str(Path(__file__).resolve().parent.parent.parent / "proyectos_prueba"))
	a = ap.parse_args()
	fallos: list[str] = []

	def check(nombre: str, ok: bool, detalle: str = "") -> None:
		print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
		if not ok:
			fallos.append(nombre)

	print("== Directora: validacion ==")
	g = llm.Gasto()
	d, _ = director.disenar("un gato veloz", True, g)
	malo = json.loads(json.dumps(d))
	malo["titulo"] = "Super Mario Gato"
	check("rechaza nombres protegidos", any("protegido" in e for e in director.validar(malo)))
	malo = json.loads(json.dumps(d))
	malo["estilo"]["paleta"][0] = "#ffffff"
	check("rechaza cielo claro", any("cielo" in e for e in director.validar(malo)))
	malo = json.loads(json.dumps(d))
	malo["enemigos"] = [malo["enemigos"][0], malo["enemigos"][0]]
	check("rechaza enemigos repetidos", any("tipo distinto" in e for e in director.validar(malo)))
	malo = json.loads(json.dumps(d))
	malo["sensacion"] = "voladora"
	check("rechaza valores fuera del esquema", bool(director.validar(malo)))
	try:
		director.disenar("hola", True, g)
		check("rechaza ideas demasiado cortas", False)
	except llm.ErrorIA:
		check("rechaza ideas demasiado cortas", True)

	import generos
	check("registro de generos coherente", not generos.comprobar(), str(generos.comprobar()))
	for esq in ("diseno.schema.json", "cambios.schema.json"):
		texto = (Path(cadena.__file__).parent / "director" / esq).read_text(encoding="utf-8")
		check(f"{esq}: estan todos los generos del registro", all(f'"{g}"' in texto for g in generos.GENEROS))
	for n, (idea, familia, sensacion) in enumerate(IDEAS):
		print(f"== Cadena: {idea} ==")
		args = argparse.Namespace(idea=idea, salida=a.salida, simulado=True, arte_simulado=True,
			comfy="", crear="", editar="", lado=512, semilla=11 + n, apk=a.apk and n == 0, capturas=False)
		try:
			inf = cadena.fabricar(args)
		except Exception as e:  # noqa: BLE001 - la prueba informa de cualquier fallo
			check("cadena termina", False, repr(e)[:400])
			continue
		check("cadena termina", inf["ok"])
		proyecto = Path(inf["proyecto"])
		game = json.loads((proyecto / "game.json").read_text(encoding="utf-8"))
		dis = json.loads((proyecto / "fabrica" / "diseno.json").read_text(encoding="utf-8"))
		man = json.loads((proyecto / "assets" / "manifest.json").read_text(encoding="utf-8"))
		check("familia de estilo segun la idea", dis["estilo"]["familia"] == familia, dis["estilo"]["familia"])
		check("sensacion segun la idea", dis["sensacion"] == sensacion, dis["sensacion"])
		perfil = {"pixel_art": "pixel", "cartoon": "cartoon", "low_poly": "low_poly"}[familia]
		check("interfaz con el perfil del estilo", man["ui"]["perfil"] == perfil, man["ui"]["perfil"])
		check("cielo = primer color de la paleta", game["palette"]["sky"].lower() == dis["estilo"]["paleta"][0].lower())
		check("todos los niveles superados por bots", all(x.get("bot_completa") for x in inf["validacion"]["niveles"]))
		check("interfaz sin problemas", not inf["validacion"]["interfaz"], str(inf["validacion"]["interfaz"][:2]))
		dl = game.get("daily_levels") or []
		check("reto del dia: niveles nuevos probados por bots", len(dl) >= 3 and all(lv.get("map") and "variant_b" not in lv for lv in dl)
			and all({k: v for k, v in lv.items() if k != "name"} != {k: v for k, v in c.items() if k != "name"} for lv in dl for c in game["levels"]), str(len(dl)))
		usados = {ch for lv in game["levels"] for fila in lv["map"] for ch in fila}
		tipos = {e["tipo"] for e in dis["enemigos"]}
		esperados = {"walker": "E", "spiky": "K", "flyer": "F"}
		aparecen = {t for t, ch in esperados.items() if ch in usados}
		check("enemigos del diseno en los niveles", aparecen <= tipos and ("walker" not in tipos or "walker" in aparecen or dis.get("genero") in ("volador", "horda", "puzle", "torres", "carreras", "naves")), f"{sorted(aparecen)} de {sorted(tipos)}")
		check("icono creado", (proyecto / "icon.png").exists())
		tx = ficha.textos(dis, len(dis["niveles"]))
		check("ficha: textos ES/EN dentro de los limites de Google Play", all(
			0 < len(tx[i]["titulo"]) <= 30 and 0 < len(tx[i]["corta"]) <= 80 and 0 < len(tx[i]["larga"]) <= 4000
			and "\n" in tx[i]["larga"] for i in ("es", "en")), json.dumps({i: [len(v) for v in tx[i].values()] for i in tx}))
		if n == 0:
			r = ficha.generar(proyecto)
			from PIL import Image
			tam = {f: Image.open(Path(r["carpeta"]) / f).size for f in ("icono_512.png", "destacado_1024x500.png")}
			import shutil
			import subprocess
			if shutil.which("ffmpeg"):
				import clip
				mp4 = clip.generar(proyecto, 4.0)
				info = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
					"-of", "csv=p=0", str(mp4)], capture_output=True, text=True).stdout.strip()
				check("clip vertical 1080x1920 en MP4", info == "1080,1920", info)
			check("ficha: icono 512x512 y destacado 1024x500 en el zip", tam == {"icono_512.png": (512, 512),
				"destacado_1024x500.png": (1024, 500)} and Path(r["zip"]).exists(), str(tam))
		if dis.get("genero") == "runner":
			mapas = "".join("".join(lv["map"]) for lv in game["levels"])
			check("runner: corre solo y sin jefe", game["player"].get("auto_run") == 1.0 and "B" not in mapas and "=" not in mapas
				and not dis.get("jefe"))
			check("runner: niveles largos", all(len(lv["map"][0]) >= 70 for lv in game["levels"]), str([len(lv["map"][0]) for lv in game["levels"]]))
		elif dis.get("genero") == "torres":
			check("torres: mapas con camino, oleadas, oro y vidas; jefe al final", game["genre"] == "tower"
				and all("waves" in lv and "gold" in lv and "S" in "".join(lv["map"]) and "B" in "".join(lv["map"]) for lv in game["levels"])
				and game["levels"][-1]["boss"] == bool(dis.get("jefe")))
		elif dis.get("genero") == "carreras":
			check("carreras: pistas con rivales y sin jefe ni arte de enemigos", game["genre"] == "race"
				and all("rival_speed" in lv and len(lv["map"]) >= 120 for lv in game["levels"]) and not dis.get("jefe")
				and len(game["texts"].get("rivals", [])) >= 1 and not (proyecto / "assets" / "enemigo_walker").exists())
		elif dis.get("genero") == "puzle":
			check("puzle: tableros con movimientos, colores y objetivo; sin arte de enemigos", game["genre"] == "match3"
				and all({"moves", "colors", "goal_factor"} <= set(lv) for lv in game["levels"]) and not (proyecto / "assets" / "enemigo_walker").exists())
		elif dis.get("genero") == "horda":
			check("horda: arenas con tiempo, oleadas y jefe al final", game["genre"] == "horde" and all("seconds" in lv and "density" in lv for lv in game["levels"])
				and game["levels"][-1]["boss"] == bool(dis.get("jefe")) and (proyecto / "assets" / "enemigo_walker").exists())
		elif dis.get("genero") == "volador":
			mapas = "".join("".join(lv["map"]) for lv in game["levels"])
			check("volador: aletea, sin enemigos ni jefe", game["player"].get("flap") == 1.0 and not any(c in mapas for c in "EKFB=")
				and not dis.get("jefe") and not (proyecto / "assets" / "enemigo_walker").exists())
		else:
			check("plataformas: no corre solo", "auto_run" not in game["player"])
		pg = (proyecto / "project.godot").read_text(encoding="utf-8")
		check("nombre de la app = titulo", f'config/name="{dis["titulo"]}"' in pg)
		if args.apk:
			check("APK creada", bool(inf["apk"]) and Path(inf["apk"]).exists())
		print(f"  -> {inf['titulo']}: {inf['total_s']} s, {inf['imagenes']} imagenes, niveles rehechos {inf['niveles_rehechos']}")
	print(f"== {len(fallos)} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

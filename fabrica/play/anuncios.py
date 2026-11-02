"""Anuncios de verdad en la version de tienda (AdMob, plugin de Poing Studios en el kit).

Cada juego es una app distinta en AdMob: el usuario crea la app y dos bloques (intersticial y
bonificado) en su cuenta de AdMob y pega los ids en Orquestador. Aqui se meten en el proyecto
justo antes de compilar el .aab:
	game.json      -> "ads": {"enabled", "android": {"interstitial", "rewarded", "banner", "app_open"}, "child_directed", "max_rating"}
	                  "monetization": {"profile"} si el autor elige otro perfil (kit/monetize.gd)
	project.godot  -> [admob] general/android/app_id
Sin ids propios, la version de tienda va SIN anuncios (los de prueba no pagan y Google no los quiere
en produccion) y la guia de Play Console dice "No contiene anuncios".
"""

import json
import re
from pathlib import Path

APP_ID = re.compile(r"^ca-app-pub-\d{16}~\d{10}$")
UNIDAD = re.compile(r"^ca-app-pub-\d{16}/\d{10}$")
APP_ID_PRUEBA = "ca-app-pub-3940256099942544~3347511713"


def validar(cfg: dict | None) -> list[str]:
	cfg = cfg or {}
	errores = []
	if not APP_ID.match(str(cfg.get("app_id", ""))):
		errores.append("El ID de app de AdMob tiene la forma ca-app-pub-0000000000000000~0000000000")
	for k in ("interstitial", "rewarded"):
		if not UNIDAD.match(str(cfg.get(k, ""))):
			errores.append(f"El bloque {k} tiene la forma ca-app-pub-0000000000000000/0000000000")
	if not errores and cfg["app_id"].split("~")[0] != cfg["interstitial"].split("/")[0]:
		errores.append("La app y los bloques son de cuentas de AdMob distintas")
	return errores


def activos(cfg: dict | None) -> bool:
	return bool(cfg) and not validar(cfg)


def _poner_app_id(proyecto: Path, app_id: str) -> None:
	ruta = proyecto / "project.godot"
	texto = ruta.read_text(encoding="utf-8")
	linea = f'general/android/app_id="{app_id}"'
	if re.search(r"^general/android/app_id=.*$", texto, flags=re.M):
		texto = re.sub(r"^general/android/app_id=.*$", linea, texto, flags=re.M)
	elif "[admob]" in texto:
		texto = texto.replace("[admob]\n", f"[admob]\n\n{linea}\n", 1)
	else:
		texto = texto.rstrip("\n") + f"\n\n[admob]\n\n{linea}\n"
	ruta.write_text(texto, encoding="utf-8")


def aplicar(proyecto: Path, cfg: dict | None, para_ninos: bool = False) -> bool:
	"""Devuelve True si la version lleva anuncios reales."""
	ruta = proyecto / "game.json"
	game = json.loads(ruta.read_text(encoding="utf-8"))
	if activos(cfg):
		unidades = {"interstitial": cfg["interstitial"], "rewarded": cfg["rewarded"]}
		## Banner y apertura de app solo con bloques propios (sin ellos el juego no los pide: nunca
		## anuncios de prueba en la tienda).
		for k in ("banner", "app_open"):
			unidades[k] = cfg[k] if UNIDAD.match(str(cfg.get(k, ""))) else ""
		game["ads"] = {"enabled": True, "android": unidades, "child_directed": para_ninos, "max_rating": "G" if para_ninos else "PG"}
		_poner_app_id(proyecto, cfg["app_id"])
		con = True
		## Perfil elegido por el autor (si no, el del tipo de juego).
		if str(cfg.get("perfil", "")):
			game["monetization"] = dict(game.get("monetization") or {}, profile=str(cfg["perfil"]))
	else:
		game["ads"] = {"enabled": False}
		_poner_app_id(proyecto, APP_ID_PRUEBA)
		con = False
	ruta.write_text(json.dumps(game, indent=1, ensure_ascii=False), encoding="utf-8")
	return con

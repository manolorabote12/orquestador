"""Anuncios reales en la version de tienda: ids de AdMob del usuario -> game.json y project.godot.

	python -m pruebas.prueba_anuncios
"""

import json
import shutil
import sys
import tempfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ))

from play import anuncios  # noqa: E402

fallos: list[str] = []


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
	if not ok:
		fallos.append(nombre)


def main() -> int:
	tmp = Path(tempfile.mkdtemp())
	for f in ("game.json", "project.godot"):
		shutil.copy(RAIZ.parent / "orqkit" / f, tmp / f)
	bueno = {"app_id": "ca-app-pub-1234567890123456~1234567890", "interstitial": "ca-app-pub-1234567890123456/1111111111",
		"rewarded": "ca-app-pub-1234567890123456/2222222222"}
	print("== Anuncios de AdMob ==")
	check("ids correctos pasan", anuncios.validar(bueno) == [])
	check("app id mal escrito", anuncios.validar({**bueno, "app_id": "ca-app-pub-1~2"}) != [])
	check("bloques de otra cuenta", any("distintas" in e for e in anuncios.validar({**bueno, "rewarded": "ca-app-pub-9999999999999999/2222222222",
		"interstitial": "ca-app-pub-9999999999999999/1111111111"})))
	con = anuncios.aplicar(tmp, bueno)
	g = json.loads((tmp / "game.json").read_text())
	pg = (tmp / "project.godot").read_text()
	check("con ids: anuncios activos y bloques en game.json", con and g["ads"]["enabled"] and g["ads"]["android"]["rewarded"] == bueno["rewarded"])
	check("con ids: app id en project.godot (lo lee el plugin al exportar)", f'general/android/app_id="{bueno["app_id"]}"' in pg)
	check("una sola linea de app id", pg.count("general/android/app_id=") == 1)
	check("publico general: anuncios PG", g["ads"]["max_rating"] == "PG" and not g["ads"]["child_directed"])
	anuncios.aplicar(tmp, bueno, para_ninos=True)
	g = json.loads((tmp / "game.json").read_text())
	check("para ninos: solo anuncios aptos (G) y tratamiento infantil", g["ads"]["child_directed"] and g["ads"]["max_rating"] == "G")
	sin = anuncios.aplicar(tmp, None)
	g = json.loads((tmp / "game.json").read_text())
	pg = (tmp / "project.godot").read_text()
	check("sin ids: la version de tienda va sin anuncios", not sin and g["ads"] == {"enabled": False})
	check("sin ids: app id de prueba (el plugin lo necesita para arrancar)", anuncios.APP_ID_PRUEBA in pg)
	print(f"== {len(fallos)} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

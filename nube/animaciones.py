"""Animar personajes con Wan 2.2 (fabrica/arte/animar.py) desde GitHub Actions (animaciones.yml).

	python nube/animaciones.py volumen <GB>     agranda el volumen de modelos del endpoint de imagenes
	                                            (RunPod no deja encogerlo; se paga por GB al mes)
	python nube/animaciones.py modelos          baja Wan 2.2 (grupo "video" de modelos.json) al volumen
	python nube/animaciones.py endpoint         imprime el id del endpoint orq-imagenes
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from desplegar import REST, ejecutar, lista, pedir  # noqa: E402


def endpoint() -> dict:
	ep = next((e for e in lista("/endpoints") if str(e.get("name", "")).startswith("orq-imagenes")), None)
	if ep is None:
		raise SystemExit("No encuentro el endpoint orq-imagenes")
	return ep


def volumen(gb: int) -> dict:
	ep = endpoint()
	vid = ep.get("networkVolumeId")
	vol = next((v for v in lista("/networkvolumes") if v.get("id") == vid), None)
	if vol is None:
		raise SystemExit("El endpoint de imagenes no tiene volumen de red")
	antes = int(vol.get("size") or 0)
	if gb <= antes:
		return {"volumen": vol.get("name"), "gb": antes, "cambio": "ninguno (ya es igual o mayor)"}
	pedir("PATCH", f"{REST}/networkvolumes/{vid}", {"size": gb})
	return {"volumen": vol.get("name"), "antes_gb": antes, "ahora_gb": gb}


def main() -> int:
	accion = sys.argv[1] if len(sys.argv) > 1 else ""
	if accion == "volumen":
		print(json.dumps(volumen(int(sys.argv[2]))))
	elif accion == "modelos":
		r = ejecutar(endpoint()["id"], {"tarea": "descargar_modelos", "grupo": "video"}, 3000)
		print(json.dumps(r))
		if r.get("errores"):
			return 1
	elif accion == "endpoint":
		print(endpoint()["id"])
	else:
		print(__doc__)
		return 2
	return 0


if __name__ == "__main__":
	sys.exit(main())

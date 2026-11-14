"""Arreglar sin rehacer (cambio.actualizar): que se dibuja y que se conserva al poner un juego al dia.

	python -m pruebas.prueba_actualizar
"""

import copy
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import cambio  # noqa: E402


def main() -> int:
	fallos = 0

	def check(nombre: str, ok: bool, detalle: str = "") -> None:
		nonlocal fallos
		print(("  OK   " if ok else "  FALLO ") + nombre + (f"  ({detalle})" if detalle and not ok else ""))
		fallos += 0 if ok else 1

	heroe = {"id": "heroe", "rol": "jugador", "descripcion": "a knight", "tamano": [128, 128], "mira_a": "derecha",
		"animaciones": {"idle": {"frames": 2}, "run": {"frames": 4}}}
	vieja = {"personajes": [heroe, {"id": "viejo", "rol": "npc", "descripcion": "x", "tamano": [128, 128], "mira_a": "derecha", "animaciones": {}}],
		"objetos": []}
	## El kit de hoy pide mas frames (6) pero las mismas animaciones: se conserva el dibujo de antes.
	nuevo_heroe = copy.deepcopy(heroe)
	nuevo_heroe["animaciones"]["run"]["frames"] = 6
	nueva = {"personajes": [nuevo_heroe, {"id": "heroe_maga", "rol": "npc", "descripcion": "a mage", "tamano": [128, 128], "mira_a": "derecha",
		"animaciones": {"idle": {"frames": 1}}}], "objetos": []}
	dib, sobran = cambio.sprites_cambiados(vieja, nueva)
	check("solo se dibuja lo nuevo (la maga), no el heroe por tener mas frames", dib == ["heroe_maga"], str(dib))
	check("el heroe conserva su entrada vieja (sus frames dibujados)", nueva["personajes"][0]["animaciones"]["run"]["frames"] == 4)
	check("lo que ya no esta se quita", sobran == ["viejo"])
	## Una animacion nueva (la pose de ataque de la arena) si obliga a redibujar ese personaje.
	con_ataque = copy.deepcopy(heroe)
	con_ataque["animaciones"]["attack"] = {"frames": 2}
	dib2, _ = cambio.sprites_cambiados({"personajes": [heroe]}, {"personajes": [con_ataque]})
	check("una animacion nueva redibuja ese personaje", dib2 == ["heroe"])
	otra = copy.deepcopy(heroe)
	otra["descripcion"] = "a pirate"
	dib3, _ = cambio.sprites_cambiados({"personajes": [heroe]}, {"personajes": [otra]})
	check("otra descripcion redibuja", dib3 == ["heroe"])
	print("== %d fallos ==" % fallos)
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())

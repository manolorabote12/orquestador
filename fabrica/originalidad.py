"""Originalidad: que cada juego sea distinto de los que ya ha hecho la fabrica.

Cada juego deja una HUELLA (genero, giros, reglas, palabras del tema y estilo de dibujo; ni titulos
ni nombres de usuario). Antes de fabricar, la idea nueva se compara con las huellas del mismo
genero. Si sale casi igual que otro juego (un "copia y pega"), la fabrica le anade un giro fiable
que el otro no tiene, y le da un indice de originalidad (0-100) que la app ensena.

Las huellas de toda la fabrica viven en el servidor (huella_anotar / huellas_recientes); cada
maquina guarda una copia local que el trabajador refresca en el mantenimiento.

	python -m originalidad "un tetris de bloques de colores"     (lo que haria con esa idea)
"""

import json
import os
import re
import sys
import time
import unicodedata
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
sys.path.insert(0, str(RAIZ))

import giros  # noqa: E402

UMBRAL = 0.8
## El trabajador lo conecta al servidor (huella_anotar), como los giros.
remoto = None
VACIAS = set("""para como con una uno unos unas los las del que por sus mas muy pero este esta estos estas donde cuando
juego juegos game games with from that this your their into over under small big style cute little very tipo
""".split())


def carpeta() -> Path:
	return Path(os.environ.get("ORQ_DATOS", str(RAIZ / "datos")))


def _palabras(*textos: str) -> list[str]:
	out: list[str] = []
	for t in textos:
		t = unicodedata.normalize("NFKD", str(t or "").lower())
		t = "".join(c for c in t if not unicodedata.combining(c))
		for w in re.findall(r"[a-z]{4,}", t):
			if w not in VACIAS and w not in out:
				out.append(w)
	return out[:40]


def huella(diseno: dict) -> dict:
	"""Lo que distingue un juego, sin datos de nadie."""
	esc = diseno.get("escenario") or {}
	enemigos = " ".join(str(e.get("nombre", "")) + " " + str(e.get("descripcion", "")) for e in diseno.get("enemigos") or [] if isinstance(e, dict))
	return {
		"genero": str(diseno.get("genero", "")),
		"giros": sorted(set(diseno.get("giros") or [])),
		"reglas": sorted(set(diseno.get("reglas") or [])),
		"palabras": _palabras(diseno.get("resumen", ""), (diseno.get("heroe") or {}).get("descripcion", ""),
			(diseno.get("heroe") or {}).get("nombre", ""), esc.get("descripcion", "") if isinstance(esc, dict) else str(esc), enemigos),
		"familia": str((diseno.get("estilo") or {}).get("familia", "")),
	}


def _jaccard(a: list, b: list) -> float:
	sa, sb = set(a), set(b)
	if not sa and not sb:
		return 1.0
	return len(sa & sb) / len(sa | sb)


def parecido(a: dict, b: dict) -> float:
	"""0 (nada que ver) a 1 (el mismo juego con otro nombre). Otro genero: 0."""
	if a.get("genero") != b.get("genero"):
		return 0.0
	return round(0.25 + 0.25 * _jaccard(a.get("giros", []), b.get("giros", [])) + 0.15 * _jaccard(a.get("reglas", []), b.get("reglas", []))
		+ 0.3 * _jaccard(a.get("palabras", []), b.get("palabras", [])) + 0.05 * (1.0 if a.get("familia") == b.get("familia") else 0.0), 3)


# ------------------------------------------------------------------ huellas guardadas

def guardar_servidor(lista: object) -> None:
	"""Lo que devuelve huellas_recientes() del servidor (las de toda la fabrica)."""
	if not isinstance(lista, list):
		return
	c = carpeta()
	c.mkdir(parents=True, exist_ok=True)
	(c / "huellas_servidor.json").write_text(json.dumps(lista[:5000], ensure_ascii=False), encoding="utf-8")


def huellas(genero: str = "") -> list[dict]:
	out: list[dict] = []
	p = carpeta() / "huellas_servidor.json"
	if p.exists():
		try:
			datos = json.loads(p.read_text(encoding="utf-8"))
			out += [h for h in datos if isinstance(h, dict)]
		except (OSError, json.JSONDecodeError):
			pass
	p2 = carpeta() / "huellas.jsonl"
	if p2.exists():
		for ln in p2.read_text(encoding="utf-8").splitlines()[-3000:]:
			try:
				out.append(json.loads(ln))
			except json.JSONDecodeError:
				continue
	return [h for h in out if not genero or h.get("genero") == genero]


def anotar(diseno: dict) -> None:
	"""Tras fabricar un juego: su huella entra en la lista (local y, si hay, servidor)."""
	h = huella(diseno)
	if remoto is not None:
		try:
			remoto(h["genero"], h)
		except Exception:  # noqa: BLE001 - la originalidad nunca para la fabrica
			pass
	try:
		c = carpeta()
		c.mkdir(parents=True, exist_ok=True)
		with (c / "huellas.jsonl").open("a", encoding="utf-8") as f:
			f.write(json.dumps({**h, "t": int(time.time())}, ensure_ascii=False) + "\n")
	except OSError:
		pass


# ------------------------------------------------------------------ comprobar y diferenciar

def comprobar(diseno: dict, otras: list[dict] | None = None) -> dict:
	"""{"indice": 0-100 (100 = nada parecido), "max": parecido maximo, "otra": la huella mas parecida, "iguales": cuantas pasan el umbral}."""
	h = huella(diseno)
	otras = huellas(h["genero"]) if otras is None else otras
	mejor, mas = 0.0, None
	iguales = 0
	for o in otras:
		p = parecido(h, o)
		if p >= UMBRAL:
			iguales += 1
		if p > mejor:
			mejor, mas = p, o
	## Indice para personas: 100 = nada parecido; un juego normal del mismo genero sale alto y un
	## copia y pega, cerca de 0.
	return {"indice": int(round(min(1.0, (1.0 - mejor) / 0.3) * 100)), "max": mejor, "otra": mas, "iguales": iguales}


def diferenciar(diseno: dict, otras: list[dict] | None = None, fijo: bool = False) -> dict:
	"""Si el diseno es casi igual que otro juego, le anade un giro fiable que el otro no tiene.
	Devuelve {"indice", "cambio": "" o el giro anadido, "mensaje"} y deja diseno["originalidad"]."""
	r = comprobar(diseno, otras)
	cambio = ""
	gs = list(diseno.get("giros") or [])
	## fijo: la persona eligio los giros (un gancho original): no se tocan.
	if r["max"] >= UMBRAL and len(gs) < 2 and not fijo:
		genero = str(diseno.get("genero", ""))
		usados = set(gs) | set((r["otra"] or {}).get("giros", []))
		## Los mas raros primero: el giro que menos se ha usado en este genero.
		st = giros.estadisticas()
		candidatos = [g for g in giros.fiables(genero) if g not in usados and g != "racha"]
		candidatos.sort(key=lambda g: (int(st.get(f"{genero}|{g}", {}).get("usos", 0)), g))
		if candidatos:
			cambio = candidatos[0]
			diseno["giros"] = gs + [cambio]
			r = comprobar(diseno, otras)
	diseno["originalidad"] = r["indice"]
	if cambio:
		nombre = giros.GIROS.get(cambio, {}).get("nombre", cambio)
		msg = f"Se parecía mucho a otros juegos: le he añadido «{nombre}» para que sea único"
	elif r["max"] >= UMBRAL:
		msg = "Se parece a otros juegos: en el taller puedes pedir una regla nueva para hacerlo único"
	else:
		msg = ""
	return {"indice": r["indice"], "cambio": cambio, "mensaje": msg}


def main(argv: list[str] | None = None) -> int:
	from director import director, simulado
	idea = " ".join(argv if argv is not None else sys.argv[1:]) or "un tetris de bloques de colores"
	d = director.normalizar(simulado.disenar(idea))
	print(json.dumps({"huella": huella(d), **diferenciar(d)}, ensure_ascii=False, indent=1))
	return 0


if __name__ == "__main__":
	sys.exit(main())

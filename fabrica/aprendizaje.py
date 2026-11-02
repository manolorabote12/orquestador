"""La fabrica aprende: de sus propias pruebas y de la gente que juega los juegos publicados.

1 - De sus pruebas: cada juego fabricado apunta, por nivel, cuantas veces hubo que rehacerlo
    hasta que el analizador y los bots lo aceptaron (datos/fabrica.jsonl).
2 - De los jugadores: estadisticas_globales() del servidor agrupa, por genero, dificultad y tramo
    del juego (0 = primeros niveles ... 4 = ultimos), cuanta gente gana, abandona y muere.
3 - Calibracion (datos/calibracion.json): un ajuste de dificultad por (genero, dificultad, tramo)
    entre -0.3 y +0.3 que el generador aplica a los juegos NUEVOS. Si la gente gana mucho mas de lo
    previsto, sube; si se atasca o abandona, baja. Si el generador tiene que rehacer mucho un tramo,
    lo suaviza un poco (niveles injustos de salida).

Objetivo de victoria por tramo (curva de dificultad de un buen juego de movil):
	tramo 0: 85 %, 1: 75 %, 2: 65 %, 3: 55 %, 4: 45 %

	python -m aprendizaje informe        (lo aprendido, en una tabla)
	python -m aprendizaje actualizar     (baja las estadisticas del servidor y recalcula; lo hace el trabajador)
"""

import json
import os
import sys
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
OBJETIVO = [0.85, 0.75, 0.65, 0.55, 0.45]
MIN_INTENTOS = 200
MIN_JUEGOS = 3
LIMITE = 0.3


def carpeta() -> Path:
	return Path(os.environ.get("ORQ_DATOS", str(RAIZ / "datos")))


def tramo(i: int, n: int) -> int:
	"""0 = primer nivel ... 4 = ultimo (igual que estadisticas_globales en el servidor)."""
	if n <= 1:
		return 0
	return int(4 * i / (n - 1) + 0.5)


## ------------------------------------------------------------------ 1 - lo que aprende de sus pruebas

def anotar_fabricacion(diseno: dict, intentos: dict[int, int], validacion: list[dict]) -> None:
	"""Una linea por nivel del juego recien fabricado (lo llama la cadena al terminar)."""
	try:
		c = carpeta()
		c.mkdir(parents=True, exist_ok=True)
		n = len(diseno["niveles"])
		with (c / "fabrica.jsonl").open("a", encoding="utf-8") as f:
			for i in range(n):
				v = validacion[i] if i < len(validacion) else {}
				f.write(json.dumps({"t": int(time.time()), "genero": diseno.get("genero", "plataformas"),
					"dificultad": diseno["dificultad"], "sensacion": diseno.get("sensacion", "normal"), "tramo": tramo(i, n),
					"rehecho": int(intentos.get(i, 0)), "bot_muertes": int(v.get("bot_muertes", 0) or 0)}) + "\n")
	except OSError:
		pass


def leer_fabricacion(dias: int = 120) -> list[dict]:
	p = carpeta() / "fabrica.jsonl"
	if not p.exists():
		return []
	desde = time.time() - dias * 86400
	out = []
	for linea in p.read_text(encoding="utf-8").splitlines():
		try:
			r = json.loads(linea)
		except json.JSONDecodeError:
			continue
		if r.get("t", 0) >= desde:
			out.append(r)
	return out


## ------------------------------------------------------------------ 2 y 3 - calibracion

def calcular(jugadores: list[dict], fabricacion: list[dict]) -> dict:
	"""{ "genero|dificultad|tramo": {"ajuste": x, "motivo": "...", ...} }"""
	cal: dict[str, dict] = {}
	for r in jugadores:
		if int(r.get("intentos", 0)) < MIN_INTENTOS or int(r.get("juegos", 0)) < MIN_JUEGOS:
			continue
		t = int(r["tramo"])
		tasa = float(r["tasa_victoria"])
		abandono = float(r.get("tasa_abandono", 0))
		ajuste = (tasa - OBJETIVO[t]) * 0.8
		## Si la gente se rinde mucho, se suaviza aunque la tasa de victoria parezca buena.
		if abandono > 0.3:
			ajuste = min(ajuste, -(abandono - 0.3))
		ajuste = max(-LIMITE, min(LIMITE, round(ajuste, 3)))
		clave = f"{r['genero']}|{r['dificultad']}|{t}"
		cal[clave] = {"ajuste": ajuste, "motivo": f"jugadores: ganan {tasa:.0%} (objetivo {OBJETIVO[t]:.0%}), abandonan {abandono:.0%}",
			"intentos": int(r["intentos"]), "juegos": int(r["juegos"])}
	grupos: dict[str, list[int]] = {}
	for r in fabricacion:
		grupos.setdefault(f"{r['genero']}|{r['dificultad']}|{r['tramo']}", []).append(int(r["rehecho"]))
	for clave, rehechos in grupos.items():
		if len(rehechos) < 10:
			continue
		media = sum(rehechos) / len(rehechos)
		if media > 0.5:
			extra = -min(0.1, round((media - 0.5) * 0.1, 3))
			prev = cal.get(clave, {"ajuste": 0.0, "motivo": ""})
			cal[clave] = dict(prev, ajuste=max(-LIMITE, round(prev["ajuste"] + extra, 3)),
				motivo=(prev["motivo"] + "; " if prev["motivo"] else "") + f"fabrica: rehace {media:.1f} veces de media")
	return cal


def guardar(cal: dict) -> Path:
	c = carpeta()
	c.mkdir(parents=True, exist_ok=True)
	p = c / "calibracion.json"
	p.write_text(json.dumps({"actualizado": int(time.time()), "calibracion": cal}, indent=1, ensure_ascii=False), encoding="utf-8")
	return p


_cache: dict = {"t": 0.0, "cal": None}


def cargar() -> dict:
	if os.environ.get("ORQ_APRENDER", "1") == "0":
		return {}
	p = carpeta() / "calibracion.json"
	if not p.exists():
		return {}
	m = p.stat().st_mtime
	if _cache["cal"] is None or _cache["t"] != m:
		try:
			_cache["cal"] = json.loads(p.read_text(encoding="utf-8")).get("calibracion", {})
		except (OSError, json.JSONDecodeError):
			_cache["cal"] = {}
		_cache["t"] = m
	return _cache["cal"]


def ajustes_para(diseno: dict) -> dict[int, float]:
	"""Ajuste aprendido para cada nivel de un diseno nuevo (0.0 si no se sabe nada)."""
	cal = cargar()
	if not cal:
		return {}
	n = len(diseno["niveles"])
	g = diseno.get("genero", "plataformas")
	out = {}
	for i in range(n):
		v = cal.get(f"{g}|{diseno['dificultad']}|{tramo(i, n)}")
		if v and v.get("ajuste"):
			out[i] = float(v["ajuste"])
	return out


def actualizar(sb) -> dict:
	"""Baja las estadisticas del servidor (clave de servicio) y recalcula la calibracion."""
	filas = sb.rpc("estadisticas_globales") or []
	c = carpeta()
	c.mkdir(parents=True, exist_ok=True)
	(c / "jugadores.json").write_text(json.dumps(filas, indent=1, ensure_ascii=False), encoding="utf-8")
	cal = calcular(filas, leer_fabricacion())
	guardar(cal)
	return cal


def informe() -> str:
	cal = cargar()
	if not cal:
		return "Aun no hay nada aprendido (hacen falta juegos publicados con jugadores o mas fabricaciones)."
	lineas = [f"{'genero':12} {'dificultad':10} tramo  ajuste  motivo"]
	for k in sorted(cal):
		g, d, t = k.split("|")
		lineas.append(f"{g:12} {d:10} {t:>5}  {cal[k]['ajuste']:+.2f}   {cal[k]['motivo']}")
	return "\n".join(lineas)


if __name__ == "__main__":
	if len(sys.argv) > 1 and sys.argv[1] == "actualizar":
		import trabajador
		sb = trabajador.Supabase(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_ROLE_KEY"])
		actualizar(sb)
	print(informe())

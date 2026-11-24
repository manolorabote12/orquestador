"""Memoria de aprendizaje entre fabricaciones: cada juego a medida que pasa por el Agente Estudio deja un
rastro de que fallo y que fallo. Aqui se guarda ese rastro (sin gastar nada de IA, es solo lectura/escritura
de un json) y se destila en un resumen corto que el propio agente lee antes de fabricar el siguiente juego,
para no repetir los mismos errores una y otra vez.

No sustituye a las «huellas» (que evitan que dos juegos se parezcan): esto es sobre CALIDAD, no sobre
originalidad.
"""

import json
import re
from collections import Counter
from pathlib import Path

ARCHIVO = Path(__file__).parent / "lecciones.json"
MAX_GUARDADAS = 80          # cuantas fabricaciones recientes conservamos en detalle
MAX_PATRONES = 10           # cuantos patrones de fallo mostramos en el resumen


def _normalizar(err: str) -> str:
	"""Reduce un mensaje de error a un patron reconocible, quitando numeros, rutas y nombres concretos
	para poder contar cuantas veces se repite el MISMO tipo de fallo en juegos distintos."""
	e = err.strip()
	e = re.sub(r"res://\S+", "res://...", e)
	e = re.sub(r"\b\d+(\.\d+)?\b", "N", e)
	e = re.sub(r"'[^']{1,60}'", "'...'", e)
	e = re.sub(r'"[^"]{1,60}"', '"..."', e)
	return e[:160]


def registrar(informe: dict) -> None:
	"""Llamar al terminar cada fabricacion (haya ido bien o mal). Guarda lo esencial: si paso cada
	prueba, los errores vistos (normalizados) y si acabo con exito."""
	try:
		datos = json.loads(ARCHIVO.read_text(encoding="utf-8")) if ARCHIVO.exists() else []
	except (json.JSONDecodeError, OSError):
		datos = []
	errores = [_normalizar(e) for e in (informe.get("errores_vistos") or [])]
	entrada = {
		"titulo": str(informe.get("titulo") or "")[:60],
		"ok": bool(informe.get("ok")),
		"prueba": informe.get("prueba") or {},
		"errores": errores[:20],
	}
	datos.append(entrada)
	datos = datos[-MAX_GUARDADAS:]
	try:
		ARCHIVO.write_text(json.dumps(datos, ensure_ascii=False, indent=1), encoding="utf-8")
	except OSError:
		pass


def resumen(n: int = MAX_GUARDADAS) -> str:
	"""Resumen corto (para meter en el prompt del agente) de los fallos mas repetidos en las ultimas
	fabricaciones, y la tasa de exito por prueba. Vacio si todavia no hay historial."""
	if not ARCHIVO.exists():
		return ""
	try:
		datos = json.loads(ARCHIVO.read_text(encoding="utf-8"))
	except (json.JSONDecodeError, OSError):
		return ""
	datos = datos[-n:]
	if len(datos) < 3:
		return ""  # con menos de 3 juegos no hay patron fiable todavia
	contador: Counter = Counter()
	for d in datos:
		for e in d.get("errores", []):
			contador[e] += 1
	frecuentes = [(e, c) for e, c in contador.most_common(MAX_PATRONES) if c >= 2]
	if not frecuentes:
		return ""
	total = len(datos)
	pruebas = ("compilar", "recorrer", "mono", "bot")
	tasas = []
	for p in pruebas:
		vistas = [d["prueba"].get(p) for d in datos if d.get("prueba") and p in d["prueba"]]
		if vistas:
			tasas.append(f"{p}: {round(100 * sum(1 for v in vistas if v) / len(vistas))}%")
	lineas = [f"De los ultimos {total} juegos a medida, estos fallos se han repetido (evitalos desde el principio, no esperes a que fallen las pruebas):"]
	for e, c in frecuentes:
		lineas.append(f"- ({c}x) {e}")
	if tasas:
		lineas.append("Tasa de exito reciente por prueba: " + ", ".join(tasas))
	return "\n".join(lineas)

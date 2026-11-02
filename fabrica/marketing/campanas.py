"""Campanas de pago en Google Ads (campanas de aplicaciones) para un juego o para Orquestador.

Google solo deja anunciar apps de Play con «campanas de aplicaciones»: se le dan textos, imagenes,
videos, paises y un presupuesto, y el combina y optimiza solo. Aqui se prepara TODO eso a partir de
la ficha del juego y de sus videos, con un presupuesto prudente y una prueba en dos fases:

1 - plan(): titulares (hasta 5 de 30 caracteres), descripciones (hasta 5 de 90), recursos (icono,
    capturas, videos verticales), paises por grupos (empieza por los baratos con mucho Android para
    aprender) y presupuesto diario con limite de gasto total.
2 - editor_csv(): el plan en CSV para Google Ads Editor (importar y publicar en dos clics).
3 - Reglas de prudencia: nunca mas de lo que la persona fija como tope; empezar por instalaciones
    (CPI) y pasar a «valor» solo con 50+ instalaciones al dia; parar los grupos con CPI 2x el objetivo.
"""

import csv
import io
import json
from pathlib import Path

## CPI orientativo (EUR) de juegos casuales por grupo de paises; sirve para el presupuesto inicial.
GRUPOS = {
	"aprender": {"paises": ["IN", "ID", "PH", "BR", "MX", "CO", "AR", "TR"], "cpi": 0.08},
	"espanol": {"paises": ["ES", "MX", "AR", "CO", "CL", "PE"], "cpi": 0.25},
	"premium": {"paises": ["US", "GB", "DE", "FR", "CA", "AU"], "cpi": 0.9},
}


def _corta(t: str, n: int) -> str:
	t = " ".join(str(t).split())
	return t if len(t) <= n else t[:n - 1].rstrip(" ,.;:") + "…"


def plan(juego: dict, presupuesto_dia: float = 5.0, tope_total: float = 100.0, grupos: list[str] | None = None) -> dict:
	"""juego: {"titulo", "corto" (frase de la ficha), "descripcion", "genero", "paquete", "icono", "capturas", "videos"}."""
	titulo = str(juego.get("titulo", "Mi juego"))
	corto = str(juego.get("corto", "")) or titulo
	frases = [titulo, corto, f"Juega gratis a {titulo}", "Niveles nuevos cada semana", "Engancha desde el primer nivel",
		"Sin conexión, cuando quieras"]
	titulares = []
	for f in frases:
		c = _corta(f, 30)
		if c and c not in titulares:
			titulares.append(c)
	descripciones = []
	for f in [juego.get("descripcion", ""), corto, f"{titulo}: descárgalo gratis y supera todos los niveles.",
		"Fácil de aprender, difícil de dominar. Partidas cortas para cualquier momento."]:
		c = _corta(f, 90)
		if c and c not in descripciones:
			descripciones.append(c)
	grupos = grupos or ["aprender", "espanol"]
	presupuesto_dia = max(1.0, min(presupuesto_dia, tope_total))
	reparto = {g: round(presupuesto_dia / len(grupos), 2) for g in grupos}
	instalaciones = {g: int(reparto[g] / GRUPOS[g]["cpi"]) for g in grupos}
	return {
		"campana": f"{titulo} · instalaciones",
		"tipo": "App campaign (Google Play)", "paquete": juego.get("paquete", ""),
		"objetivo": "instalaciones (CPI) hasta 50 al dia; despues, acciones dentro de la app",
		"presupuesto_dia": presupuesto_dia, "tope_total": tope_total, "dias_hasta_tope": int(tope_total / presupuesto_dia),
		"grupos": [{"nombre": g, "paises": GRUPOS[g]["paises"], "presupuesto_dia": reparto[g], "cpi_objetivo": GRUPOS[g]["cpi"],
			"instalaciones_dia_estimadas": instalaciones[g]} for g in grupos],
		"titulares": titulares[:5], "descripciones": descripciones[:5],
		"recursos": {"icono": juego.get("icono", ""), "imagenes": list(juego.get("capturas", []))[:20], "videos": list(juego.get("videos", []))[:20]},
		"reglas": ["Parar un grupo si su CPI pasa del doble del objetivo 3 dias seguidos.",
			"No tocar la campana en los primeros 7 dias (Google esta aprendiendo).",
			"Subir el presupuesto como mucho un 20 % cada 3 dias si el CPI esta por debajo del objetivo."],
	}


def editor_csv(p: dict) -> str:
	"""CSV para Google Ads Editor (una fila por campana, grupo y texto)."""
	out = io.StringIO()
	w = csv.writer(out)
	w.writerow(["Campaign", "Campaign Type", "Budget", "Bid Strategy Type", "Target CPA", "App ID", "Ad Group", "Location", "Headline", "Description"])
	for g in p["grupos"]:
		for i in range(max(len(p["titulares"]), len(p["descripciones"]))):
			w.writerow([p["campana"], "App", g["presupuesto_dia"], "Target CPI", g["cpi_objetivo"], p["paquete"], g["nombre"],
				";".join(g["paises"]) if i == 0 else "", p["titulares"][i] if i < len(p["titulares"]) else "",
				p["descripciones"][i] if i < len(p["descripciones"]) else ""])
	return out.getvalue()


def guardar(p: dict, carpeta: Path) -> dict:
	carpeta.mkdir(parents=True, exist_ok=True)
	(carpeta / "campana.json").write_text(json.dumps(p, ensure_ascii=False, indent=1), encoding="utf-8")
	(carpeta / "campana_google_ads_editor.csv").write_text(editor_csv(p), encoding="utf-8")
	return {"json": str(carpeta / "campana.json"), "csv": str(carpeta / "campana_google_ads_editor.csv")}

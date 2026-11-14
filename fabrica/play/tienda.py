"""Compras a medida de cada juego (14 nov 2026): lo que el creador quiera vender.

El creador las define en la app (projects.tienda, funcion set_project_tienda, que valida lo mismo
que aqui) y viajan con la publicacion:
	{"moneda": {"nombre": "Perlas", "icono": "gem"},
	 "productos": [{"id": "perlas_100", "tipo": "monedas", "cantidad": 100, "precio_cent": 99, "nombre"?},
	               {"id": "sin_anuncios", "tipo": "sin_anuncios", "precio_cent": 299},
	               {"id": "cofre_rey", "tipo": "pack", "cantidad": 5000, "precio_cent": 999},
	               {"id": "pase", "tipo": "pase", "precio_cent": 399},
	               {"id": "vip_mes", "tipo": "vip", "precio_cent": 499, "periodo": "mes", "extra_pct": 50,
	                "diario": 30, "sin_anuncios": true}]}
	validar(t)          -> lista de errores (vacia = vale)
	a_game(t)           -> lo que va en game.json -> "store" (lo lee orqkit/kit/store.gd)
	cierres(t)          -> {sku: "consumir" | "reconocer" | "suscripcion"} (lo usa juego-compra)
	aplicar(proyecto, t) -> mete la tienda en game.json justo antes de compilar el .aab
Sin tienda propia, el juego lleva la del kit (monedas_500, sin_anuncios...)."""

import json
import re
from pathlib import Path

ID = re.compile(r"^[a-z][a-z0-9_]{2,39}$")
TIPOS = {"monedas": "coins", "sin_anuncios": "no_ads", "pack": "bundle", "pase": "pass", "vip": "vip"}
PERIODOS = {"semana": "P1W", "mes": "P1M", "anio": "P1Y"}
ICONOS = ("coin", "gem", "star", "heart", "trophy", "cube")
PRECIO_MIN, PRECIO_MAX = 10, 9999
MAX_PRODUCTOS = 12


def precio_texto(cent: int) -> str:
	return f"{cent // 100},{cent % 100:02d} €"


def validar(t: dict | None) -> list[str]:
	if not t:
		return []
	errores = []
	moneda = t.get("moneda") or {}
	nombre = str(moneda.get("nombre", "")).strip()
	if not 1 <= len(nombre) <= 20:
		errores.append("La moneda necesita un nombre de 1 a 20 letras (Gemas, Perlas...)")
	if str(moneda.get("icono", "coin")) not in ICONOS:
		errores.append("Icono de moneda desconocido")
	productos = t.get("productos") or []
	if not isinstance(productos, list) or not 1 <= len(productos) <= MAX_PRODUCTOS:
		return errores + [f"Pon de 1 a {MAX_PRODUCTOS} productos"]
	vistos, vip, pase = set(), 0, 0
	for p in productos:
		pid, tipo = str(p.get("id", "")), str(p.get("tipo", ""))
		if not ID.match(pid):
			errores.append(f"«{pid}»: el código va en minúsculas, sin espacios (3 a 40: letras, números y _)")
		elif pid in vistos:
			errores.append(f"«{pid}» está repetido")
		vistos.add(pid)
		if tipo not in TIPOS:
			errores.append(f"«{pid}»: tipo desconocido ({tipo})")
			continue
		cent = p.get("precio_cent")
		if not isinstance(cent, int) or not PRECIO_MIN <= cent <= PRECIO_MAX:
			errores.append(f"«{pid}»: el precio va de 0,10 € a 99,99 €")
		if tipo in ("monedas", "pack") and not (isinstance(p.get("cantidad"), int) and 1 <= p["cantidad"] <= 1_000_000):
			errores.append(f"«{pid}»: la cantidad va de 1 a 1.000.000")
		if len(str(p.get("nombre", ""))) > 40:
			errores.append(f"«{pid}»: el nombre tiene como mucho 40 letras")
		if tipo == "vip":
			vip += 1
			if str(p.get("periodo", "mes")) not in PERIODOS:
				errores.append(f"«{pid}»: el VIP se cobra por semana, mes o año")
			if not 0 <= int(p.get("extra_pct", 0)) <= 300 or not 0 <= int(p.get("diario", 0)) <= 100_000:
				errores.append(f"«{pid}»: extra de 0 a 300 % y regalo diario de 0 a 100.000")
		pase += tipo == "pase"
	if vip > 2:
		errores.append("Como mucho 2 suscripciones VIP")
	if pase > 1:
		errores.append("Solo un pase premium")
	return errores


def a_game(t: dict) -> dict:
	moneda = t["moneda"]
	out = []
	for p in t["productos"]:
		kind = TIPOS[p["tipo"]]
		d = {"id": p["id"], "kind": kind, "price": precio_texto(int(p["precio_cent"])), "name": str(p.get("nombre", ""))[:40]}
		if kind in ("coins", "bundle"):
			d["coins"] = int(p["cantidad"])
		if kind == "vip":
			d.update({"plan": str(p.get("periodo", "mes")), "bonus_pct": int(p.get("extra_pct", 0)),
				"daily": int(p.get("diario", 0)), "no_ads": bool(p.get("sin_anuncios", True))})
		out.append(d)
	return {"currency": {"name": str(moneda["nombre"]).strip(), "icon": str(moneda.get("icono", "coin"))}, "products": out}


def cierres(t: dict | None) -> dict[str, str]:
	if not t:
		return {}
	return {p["id"]: "suscripcion" if p["tipo"] == "vip" else "consumir" if p["tipo"] in ("monedas", "pase") else "reconocer"
		for p in t["productos"]}


def aplicar(proyecto: Path, t: dict | None) -> bool:
	"""Mete la tienda del creador en game.json. Devuelve True si el juego lleva tienda propia."""
	ruta = proyecto / "game.json"
	game = json.loads(ruta.read_text(encoding="utf-8"))
	if t and not validar(t):
		game["store"] = a_game(t)
	else:
		game.pop("store", None)
	ruta.write_text(json.dumps(game, indent=1, ensure_ascii=False), encoding="utf-8")
	return "store" in game


# ------------------------------------------------------------------ fichas de Google Play

DESCRIPCIONES = {
	"es": {"monedas": "{n} {m} para el juego.", "sin_anuncios": "Quita para siempre los anuncios entre partidas.",
		"pack": "{n} {m} y sin anuncios para siempre.", "pase": "Premios premium del pase de temporada.",
		"vip": "VIP: sin anuncios, más {m} en cada partida y regalo diario."},
	"en": {"monedas": "{n} {m} for the game.", "sin_anuncios": "Removes the ads between matches forever.",
		"pack": "{n} {m} and no ads forever.", "pase": "Premium rewards of the season pass.",
		"vip": "VIP: no ads, more {m} every match and a daily gift."},
}


def ficha(p: dict, moneda: str, idioma: str) -> tuple[str, str]:
	"""Titulo y descripcion de un producto en la tienda de Google."""
	textos = DESCRIPCIONES.get(idioma, DESCRIPCIONES["en"])
	n = p.get("cantidad", "")
	titulo = str(p.get("nombre") or "").strip()
	if not titulo:
		titulo = {"monedas": f"{n} {moneda}", "sin_anuncios": "Sin anuncios" if idioma == "es" else "No ads",
			"pack": f"Pack {n} {moneda}", "pase": "Pase premium" if idioma == "es" else "Premium pass", "vip": "VIP"}[p["tipo"]]
	return titulo[:55], textos[p["tipo"]].format(n=n, m=moneda)[:200]

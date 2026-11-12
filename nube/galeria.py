"""Galeria tipo Poki: reparto mensual a los creadores y cobros en dinero (lo lanza el dueno).

	python3 nube/galeria.py estado                       -> anuncios del mes, repartos hechos y cobros pendientes
	python3 nube/galeria.py repartir 2026-11 12.34       -> reparte el 50 % de 12,34 EUR (lo que pago Google ese mes)
	python3 nube/galeria.py pagado 17 [nota]             -> el cobro 17 ya esta pagado por PayPal
	python3 nube/galeria.py rechazado 17 [motivo]        -> el cobro 17 no se pudo pagar: el dinero vuelve al creador

Lo que pago Google por los anuncios de la galeria se mira en AdMob (Informes, bloque «Galeria entre
partidas»). El reparto es una sola vez por mes y nunca reparte mas de lo que se le dice.
Necesita SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY.
"""

import json
import os
import re
import sys
import urllib.error
import urllib.request

AGENTE = "Orquestador/1.0 (+https://github.com)"


def rest(metodo: str, ruta: str, cuerpo: object = None) -> object:
	k = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
	url = os.environ["SUPABASE_URL"].rstrip("/") + "/rest/v1/" + ruta
	req = urllib.request.Request(url, data=None if cuerpo is None else json.dumps(cuerpo).encode(), method=metodo,
		headers={"apikey": k, "Authorization": "Bearer " + k, "Content-Type": "application/json", "User-Agent": AGENTE})
	try:
		with urllib.request.urlopen(req, timeout=60) as r:
			txt = r.read().decode()
			return json.loads(txt) if txt.strip() else None
	except urllib.error.HTTPError as e:
		raise SystemExit(f"::error::{e.code} en {ruta}: {e.read()[:300].decode('utf-8', 'replace')}") from None


def euros(cent: int) -> str:
	return f"{cent / 100:.2f} EUR".replace(".", ",")


def mes_valido(m: str) -> str:
	"""Pura: 'AAAA-MM' -> 'AAAA-MM-01' (o error)."""
	if not re.fullmatch(r"20\d\d-(0[1-9]|1[0-2])", m or ""):
		raise ValueError("El mes va como AAAA-MM, por ejemplo 2026-11")
	return m + "-01"


def centimos(texto: str) -> int:
	"""Pura: '12,34' o '12.34' -> 1234 (o error)."""
	t = (texto or "").strip().replace(",", ".")
	if not re.fullmatch(r"\d{1,7}(\.\d{1,2})?", t):
		raise ValueError("La cantidad va en euros, por ejemplo 12,34")
	return round(float(t) * 100)


def estado() -> int:
	repartos = rest("GET", "galeria_repartos?select=*&order=mes.desc&limit=6") or []
	for r in repartos:
		print(f"::notice::Reparto {r['mes'][:7]}: entraron {euros(r['ingresos_cent'])}, repartidos {euros(r['reparto_cent'])} "
			f"entre {r['creadores']} creadores ({r['anuncios']} anuncios)")
	pend = rest("GET", "creador_cobros?select=id,cent,paypal,nombre,created_at&estado=eq.pendiente&order=created_at") or []
	total = sum(c["cent"] for c in pend)
	print(f"::notice::Cobros pendientes: {len(pend)} ({euros(total)})")
	for c in pend:
		print(f"::warning::Cobro {c['id']}: {euros(c['cent'])} a {c['paypal']} ({c['nombre']}), pedido {c['created_at'][:10]}")
	return 0


def main(a: list[str]) -> int:
	accion = a[0] if a else "estado"
	try:
		if accion == "repartir":
			r = rest("POST", "rpc/galeria_reparto", {"p_mes": mes_valido(a[1]), "p_ingresos_cent": centimos(a[2])})
			print(f"::notice::Reparto hecho: {json.dumps(r, ensure_ascii=False)}")
		elif accion in ("pagado", "rechazado"):
			r = rest("POST", "rpc/cobro_cerrar", {"p_id": int(a[1]), "p_estado": accion, "p_nota": " ".join(a[2:]) or None})
			print(f"::notice::Cobro {a[1]}: {r}")
	except (ValueError, IndexError) as e:
		print(f"::error::{e}")
		return 1
	return estado()


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))

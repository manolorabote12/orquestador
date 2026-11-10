"""Vigilante del gasto: lo ejecuta el Reloj de GitHub cada 15 minutos (sin coste extra).

Mira en una sola llamada (vigilancia() en Supabase) y en RunPod:
	1 - Gasto de la ultima hora por encima de ORQ_ALARMA_HORA_USD -> PARA la fabrica y avisa.
	2 - RunPod gastando mas de ORQ_ALARMA_RUNPOD_HORA $/h -> PARA la fabrica y avisa.
	3 - Un trabajo que costo mas de ORQ_ALARMA_JUEGO_USD -> avisa.
	4 - Dos juegos o mas fallidos en los ultimos minutos -> avisa.
	5 - RunPod gastando sin ningun trabajo en marcha (tarjetas encendidas de mas) -> avisa.
	6 - Saldo de RunPod bajo -> aviso amarillo (sin correo).
	7 - Correos de acceso cerca del limite de Gmail (~500 al dia): aviso amarillo desde 350 y correo desde 450.

"Avisa" = el paso termina en error y GitHub te manda un correo. Volver a arrancar la fabrica:
Actions -> "Fabrica: pausar o reanudar" -> reanudar.

python3 nube/vigilante.py            (con SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY y RUNPOD_API_KEY)
"""

import json
import os
import sys
import urllib.error
import urllib.request

AGENTE = "Orquestador/1.0 (+https://github.com)"
VENTANA_MIN = 16


def umbrales() -> dict:
	def f(nombre: str, defecto: str) -> float:
		return float(os.environ.get(nombre) or defecto)
	return {
		"hora_usd": f("ORQ_ALARMA_HORA_USD", "3"),
		"runpod_hora": f("ORQ_ALARMA_RUNPOD_HORA", "3"),
		"juego_usd": f("ORQ_ALARMA_JUEGO_USD", "0.8"),
		"fuga_hora": f("ORQ_ALARMA_FUGA_HORA", "0.4"),
		"saldo_min": f("ORQ_ALARMA_SALDO", "3"),
		"fallos": f("ORQ_ALARMA_FALLOS", "2"),
		"correos_aviso": f("ORQ_ALARMA_CORREOS", "350"),
		"correos_alarma": f("ORQ_ALARMA_CORREOS_MAX", "450"),
	}


def decidir(v: dict, rp: dict | None, u: dict) -> dict:
	"""Pura (sin red) para poder probarla. Devuelve {alarmas, avisos, pausar (motivo o None), resumen}."""
	alarmas: list[str] = []
	avisos: list[str] = []
	pausar = None
	gasto_rp = float((rp or {}).get("currentSpendPerHr") or 0)
	saldo = (rp or {}).get("clientBalance")
	if not v.get("pausada"):
		if float(v.get("hora_usd") or 0) > u["hora_usd"]:
			pausar = f"la ultima hora costo {float(v['hora_usd']):.2f} $ (limite {u['hora_usd']:.2f} $)"
		elif gasto_rp > u["runpod_hora"]:
			pausar = f"RunPod esta gastando {gasto_rp:.2f} $/h (limite {u['runpod_hora']:.2f} $/h)"
	if pausar:
		alarmas.append("FABRICA PARADA: " + pausar + ". Revisa y reanudala con el workflow 'Fabrica: pausar o reanudar'.")
	for c in v.get("caros") or []:
		alarmas.append(f"Trabajo caro: {c.get('kind')} {c.get('id')} costo {float(c.get('usd') or 0):.2f} $ ({c.get('status')})")
	fallos = v.get("fallos_recientes") or []
	if len(fallos) >= u["fallos"]:
		alarmas.append(f"{len(fallos)} juegos fallidos en los ultimos minutos: " + " | ".join(
			f"{x.get('kind')}: {str(x.get('error'))[:90]}" for x in fallos[:3]))
	if gasto_rp > u["fuga_hora"] and not int(v.get("en_marcha") or 0) and not int(v.get("en_cola") or 0):
		alarmas.append(f"RunPod gasta {gasto_rp:.2f} $/h sin ningun trabajo en marcha: mira Serverless -> Workers y apaga lo que siga encendido")
	if saldo is not None and float(saldo) < u["saldo_min"]:
		avisos.append(f"Saldo de RunPod bajo: {float(saldo):.2f} $ (los juegos fallaran sin saldo)")
	correos = int(v.get("correos_24h") or 0)
	if correos >= u["correos_alarma"]:
		alarmas.append(f"{correos} correos de acceso en 24 h: Gmail corta hacia 500 y nadie podra entrar. Pasa el correo a un servicio de envios (ver LANZAR-APP-LEEME)")
	elif correos >= u["correos_aviso"]:
		avisos.append(f"{correos} correos de acceso en 24 h (Gmail corta hacia 500)")
	if v.get("pausada"):
		avisos.append("La fabrica esta PARADA: " + str(v.get("nota_pausa") or ""))
	resumen = (f"hora {float(v.get('hora_usd') or 0):.2f} $ | hoy {float(v.get('dia_usd') or 0):.2f} $ de {float(v.get('presupuesto_dia_usd') or 0):.0f} $"
		f" | juegos hoy {v.get('juegos_dia', 0)} (fallidos {v.get('fallidos_dia', 0)}) | en marcha {v.get('en_marcha', 0)}, en cola {v.get('en_cola', 0)}"
		f" | correos 24 h {correos} | RunPod {gasto_rp:.2f} $/h" + (f", saldo {float(saldo):.2f} $" if saldo is not None else ""))
	return {"alarmas": alarmas, "avisos": avisos, "pausar": pausar, "resumen": resumen}


def _post(url: str, cuerpo: dict, cabeceras: dict) -> object:
	req = urllib.request.Request(url, data=json.dumps(cuerpo).encode(), method="POST",
		headers={"Content-Type": "application/json", "User-Agent": AGENTE, **cabeceras})
	with urllib.request.urlopen(req, timeout=30) as r:
		txt = r.read().decode("utf-8")
		return json.loads(txt) if txt.strip() else None


def rpc(nombre: str, args: dict) -> object:
	url = os.environ["SUPABASE_URL"].rstrip("/") + "/rest/v1/rpc/" + nombre
	k = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
	return _post(url, args, {"apikey": k, "Authorization": "Bearer " + k})


def runpod() -> dict | None:
	clave = os.environ.get("RUNPOD_API_KEY", "")
	if not clave:
		return None
	try:
		r = _post("https://api.runpod.io/graphql", {"query": "query { myself { clientBalance currentSpendPerHr spendLimit } }"},
			{"Authorization": "Bearer " + clave})
		return ((r or {}).get("data") or {}).get("myself") or None
	except (urllib.error.URLError, OSError, ValueError) as e:
		print(f"::notice::Vigilante: RunPod no responde ({str(e)[:120]}); se mira solo Supabase")
		return None


def main() -> int:
	u = umbrales()
	try:
		v = rpc("vigilancia", {"p_caro_usd": u["juego_usd"], "p_minutos": VENTANA_MIN})
	except (urllib.error.URLError, OSError, ValueError) as e:
		print(f"::warning::Vigilante: Supabase no responde ({str(e)[:160]})")
		return 0
	d = decidir(v or {}, runpod(), u)
	if d["pausar"]:
		try:
			rpc("pausar_fabrica", {"p_pausa": True, "p_motivo": "vigilante: " + d["pausar"]})
		except (urllib.error.URLError, OSError, ValueError) as e:
			d["alarmas"].append(f"NO se pudo parar la fabrica ({str(e)[:100]}): paralo a mano")
	print("::notice::Vigilante: " + d["resumen"])
	for a in d["avisos"]:
		print("::warning::" + a)
	for a in d["alarmas"]:
		print("::error::" + a)
	return 1 if d["alarmas"] else 0


if __name__ == "__main__":
	sys.exit(main())

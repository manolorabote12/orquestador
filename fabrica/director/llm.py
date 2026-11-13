"""Llamada a Claude con salida estructurada (herramienta forzada) y coste real por llamada.

Router de modelos: primero el barato (Haiku). Si su respuesta no pasa la validacion, se le
devuelven los errores para que la corrija una vez; si aun asi falla, se escala al modelo
superior (Sonnet). Asi el caso normal cuesta centimos y el dificil sigue saliendo bien.
"""

import json
import re
import os
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field

API_URL = os.environ.get("ANTHROPIC_API_URL", "https://api.anthropic.com/v1/messages")
MODELOS = [
	os.environ.get("ORQ_MODELO_BARATO", "claude-haiku-5-5"),
	os.environ.get("ORQ_MODELO_SUPERIOR", "claude-sonnet-5-5"),
]
## USD por millon de tokens (entrada, salida). Revisar en https://docs.claude.com (precios).
PRECIOS = {
	"claude-haiku-5-5": (0.10, 0.50),        ## hasta 100K tokens de entrada (los prompts de la fabrica no llegan)
	"claude-haiku-4-5-20251001": (1.0, 5.0),
	"claude-sonnet-5-5": (2.0, 10.0),
}
PRECIO_DESCONOCIDO = (5.0, 25.0)
## Modelos que rechazan tool_choice forzado (se descubren solos al primer error 400).
SIN_FORZAR: set[str] = set()


class ErrorIA(Exception):
	pass


@dataclass
class Gasto:
	llamadas: list[dict] = field(default_factory=list)

	@property
	def usd(self) -> float:
		return round(sum(c["usd"] for c in self.llamadas), 5)

	def anotar(self, modelo: str, uso: dict, segundos: float, nota: str) -> None:
		pi, po = PRECIOS.get(modelo, PRECIO_DESCONOCIDO)
		ent = int(uso.get("input_tokens", 0))
		cache_w = int(uso.get("cache_creation_input_tokens", 0))
		cache_r = int(uso.get("cache_read_input_tokens", 0))
		sal = int(uso.get("output_tokens", 0))
		usd = (ent * pi + cache_w * pi * 1.25 + cache_r * pi * 0.1 + sal * po) / 1e6
		self.llamadas.append({"modelo": modelo, "entrada": ent + cache_w + cache_r, "salida": sal,
			"usd": round(usd, 5), "segundos": round(segundos, 1), "nota": nota})


def clave() -> str:
	return os.environ.get("ANTHROPIC_API_KEY", "")


def llamar_herramienta(modelo: str, sistema: str, mensajes: list[dict], herramienta: dict,
		gasto: Gasto, nota: str, max_tokens: int = 3000, reintentos: int = 3) -> dict:
	"""1 - Una llamada forzando la herramienta. Devuelve el 'input' que la IA rellena."""
	if not clave():
		raise ErrorIA("Falta ANTHROPIC_API_KEY (o usa el modo --simulado)")
	cuerpo = {
		"model": modelo,
		"max_tokens": max_tokens,
		"system": [{"type": "text", "text": sistema, "cache_control": {"type": "ephemeral"}}],
		"tools": [herramienta],
		"tool_choice": {"type": "tool", "name": herramienta["name"]},
		"messages": mensajes,
	}
	datos = json.dumps(cuerpo).encode("utf-8")
	ultimo = ""
	for intento in range(reintentos):
		if modelo in SIN_FORZAR and cuerpo["tool_choice"]["type"] != "auto":
			## Algunos modelos nuevos no admiten forzar la herramienta: se pide con palabras.
			cuerpo["tool_choice"] = {"type": "auto"}
			cuerpo["system"] = [{**cuerpo["system"][0], "text": sistema + "\n\nResponde SIEMPRE llamando a la herramienta "
				+ herramienta["name"] + ", sin texto aparte."}]
			datos = json.dumps(cuerpo).encode("utf-8")
		req = urllib.request.Request(API_URL, data=datos, method="POST", headers={
			"x-api-key": clave(), "anthropic-version": "2023-06-01", "content-type": "application/json",
		})
		t0 = time.time()
		try:
			with urllib.request.urlopen(req, timeout=120) as r:
				resp = json.loads(r.read().decode("utf-8"))
		except urllib.error.HTTPError as e:
			ultimo = f"HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:300]}"
			if e.code == 400 and "tool_choice" in ultimo and modelo not in SIN_FORZAR and intento < reintentos - 1:
				SIN_FORZAR.add(modelo)
				continue
			## 2 - Saturacion o limite: se espera y se reintenta. Otros errores no se reintentan.
			if e.code in (429, 500, 502, 503, 529) and intento < reintentos - 1:
				time.sleep(2.0 * (intento + 1))
				continue
			raise ErrorIA(ultimo) from e
		except (urllib.error.URLError, TimeoutError) as e:
			ultimo = str(e)
			if intento < reintentos - 1:
				time.sleep(2.0 * (intento + 1))
				continue
			raise ErrorIA("No se pudo contactar con la IA: " + ultimo) from e
		gasto.anotar(modelo, resp.get("usage", {}), time.time() - t0, nota)
		if resp.get("stop_reason") == "refusal":
			raise ErrorIA("La IA ha rechazado la peticion")
		## Respuesta cortada por el limite: la herramienta llega a medias (12 nov: disenos de ~2.700
		## tokens contra un limite de 3.000). Se repite con el doble de espacio.
		if resp.get("stop_reason") == "max_tokens" and cuerpo["max_tokens"] < 32000 and intento < reintentos - 1:
			cuerpo["max_tokens"] = min(32000, cuerpo["max_tokens"] * 2)
			datos = json.dumps(cuerpo).encode("utf-8")
			ultimo = "respuesta cortada por el limite de tokens"
			continue
		for bloque in resp.get("content", []):
			if bloque.get("type") == "tool_use" and bloque.get("name") == herramienta["name"]:
				return reubicar(reparar_entrada(bloque.get("input", {})), herramienta.get("input_schema", {}))
		ultimo = "La IA no uso la herramienta"
	raise ErrorIA(ultimo)


_PARAM = re.compile(r'<parameter name="([^"]+)">(.*?)(?=</parameter>|<parameter name="|$)', re.S)


def _desde_parametros(texto: str) -> object:
	"""'\n<parameter name="a">1</parameter><parameter name="b">x' -> {"a": 1, "b": "x"} (o el texto si no)."""
	if '<parameter name="' not in texto:
		return texto
	out: dict = {}
	for nombre, valor in _PARAM.findall(texto):
		v = valor.strip()
		try:
			out[nombre] = json.loads(v)
		except ValueError:
			out[nombre] = v
	return out or texto


def reparar_entrada(x: object) -> object:
	"""13 nov: con esquemas grandes Sonnet a veces escribe los objetos anidados como texto con etiquetas
	<parameter name="..."> (o como JSON en texto). Se reconstruyen antes de validar: si no, el diseno
	fallaba entero, se pagaba una correccion y a veces acababa en el modelo barato."""
	if isinstance(x, dict):
		return {k: reparar_entrada(v) for k, v in x.items()}
	if isinstance(x, list):
		return [reparar_entrada(v) for v in x]
	if isinstance(x, str):
		t = x.strip()
		if t.startswith("<parameter") or t.startswith("\n<parameter"):
			return reparar_entrada(_desde_parametros(t))
		if (t.startswith("{") and t.endswith("}")) or (t.startswith("[") and t.endswith("]")):
			try:
				return reparar_entrada(json.loads(t))
			except ValueError:
				return x
	return x


def reubicar(x: object, esquema: dict) -> object:
	"""Campos que se salieron a la raiz (13 nov: «tempo», «victoria», «nombre_plural»... junto a «titulo»):
	si un campo desconocido es propio de uno solo de los objetos del esquema, vuelve a su sitio."""
	props = esquema.get("properties") if isinstance(esquema, dict) else None
	if not isinstance(x, dict) or not isinstance(props, dict) or esquema.get("additionalProperties") is not False:
		return x
	for k in [k for k in x if k not in props]:
		duenos = [p for p, sub in props.items() if isinstance(sub, dict) and k in (sub.get("properties") or {})]
		if len(duenos) == 1:
			d = duenos[0]
			if not isinstance(x.get(d), dict):
				x[d] = {}
			x[d].setdefault(k, x[k])
			del x[k]
	return x


## Errores de validacion de cada modelo en la ultima llamada a con_router (para el informe: el 12 nov
## el reino tipo Kingshot salio como RPG porque Sonnet fallo dos veces y nadie supo por que).
ULTIMOS_ERRORES: list[str] = []


def con_router(sistema: str, usuario: str, herramienta: dict, validar, gasto: Gasto, primero_superior: bool = False,
		max_tokens: int = 8000) -> tuple[dict, str]:
	"""3 - Barato -> correccion con errores -> modelo superior. validar(dict) -> lista de errores.
	primero_superior: el modelo bueno primero (y el barato de reserva). Para el DISENO del juego: es la
	decision que mas pesa (genero, mundo, personajes, niveles) y cuesta centimos frente al arte."""
	errores_previos: list[str] = []
	ULTIMOS_ERRORES.clear()
	for modelo in (list(reversed(MODELOS)) if primero_superior else MODELOS):
		mensajes = [{"role": "user", "content": usuario}]
		datos = llamar_herramienta(modelo, sistema, mensajes, herramienta, gasto, "diseno", max_tokens=max_tokens)
		errores = validar(datos)
		if not errores:
			return datos, modelo
		mensajes += [
			{"role": "assistant", "content": [{"type": "tool_use", "id": "t1", "name": herramienta["name"], "input": datos}]},
			{"role": "user", "content": [{"type": "tool_result", "tool_use_id": "t1", "is_error": True,
				"content": "El diseno no es valido. Corrige SOLO esto y vuelve a llamar a la herramienta:\n- " + "\n- ".join(errores[:12])}]},
		]
		ULTIMOS_ERRORES.extend(f"{modelo}: {e}" for e in errores[:4])
		datos = llamar_herramienta(modelo, sistema, mensajes, herramienta, gasto, "correccion", max_tokens=max_tokens)
		errores = validar(datos)
		if not errores:
			return datos, modelo
		ULTIMOS_ERRORES.extend(f"{modelo} (corregido): {e}" for e in errores[:4])
		errores_previos = errores
	raise ErrorIA("El diseno sigue sin ser valido: " + "; ".join(errores_previos[:5]))

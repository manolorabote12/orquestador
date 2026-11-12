"""Critica visual del juego TERMINADO: Claude mira las capturas reales (titulo y partida) y pone nota.

Es el control que faltaba: los bots dicen si el juego se puede jugar, pero no si se ve bien. El 11 nov
salieron juegos «validos» con los personajes dentro de un cuadro con escenario, botones con un
rectangulo granate y el heroe diminuto, y nadie lo supo hasta mirarlos a mano. Ahora cada juego lleva
su nota (1-10) y sus problemas en el informe y en el progreso del trabajo, y la fabrica los apunta en
el aprendizaje: lo que se repite entre juegos es lo siguiente que hay que arreglar.

No frena la entrega (un juego jugable se entrega igual); cuesta menos de un centimo (modelo barato
con vision). Sin capturas o sin IA, no hace nada.
"""

import base64
import io
from pathlib import Path

from PIL import Image

from director import llm

HERRAMIENTA = {
	"name": "critica",
	"description": "Critica visual de un juego movil a partir de sus capturas.",
	"input_schema": {
		"type": "object",
		"required": ["nota", "problemas", "lo_mejor"],
		"properties": {
			"nota": {"type": "integer", "minimum": 1, "maximum": 10,
				"description": "10 = podria estar destacado en Google Play; 6 = correcto; 3 = parece roto o un prototipo"},
			"problemas": {"type": "array", "minItems": 2, "maxItems": 6,
				"description": "Siempre al menos 2: lo que mas separa este juego de uno destacado en Google Play", "items": {"type": "object", "required": ["tipo", "detalle"], "properties": {
				"tipo": {"type": "string", "enum": ["personaje_con_fondo", "personaje_pequeno", "personaje_ilegible", "suelo_recargado",
					"fondo_vacio", "fondo_distrae", "interfaz_rota", "interfaz_sosa", "texto_cortado", "nivel_vacio", "poca_vida",
					"efectos_pobres", "colores_chocan", "estilos_mezclados", "otro"]},
				"detalle": {"type": "string", "maxLength": 140, "description": "En espanol, concreto: que se ve y donde"},
			}}},
			"lo_mejor": {"type": "string", "maxLength": 140, "description": "En espanol: lo que mas luce del juego"},
		},
	},
}

SISTEMA = ("Eres director de arte de una editora de juegos moviles y revisas capturas REALES de un juego recien fabricado "
	"(pantalla de titulo y partida, en vertical). Juzga solo lo que se ve: si los personajes se leen bien y estan recortados "
	"(sin un cuadro o escenario pegado alrededor), si el heroe tiene buen tamano, si el suelo y el fondo dejan ver la accion, "
	"si la interfaz esta limpia (botones sin marcos raros, textos enteros), si el nivel tiene cosas que hacer y si todo parece "
	"del mismo juego, y si hay vida y efectos (particulas, animaciones, menus con personalidad). Se exigente pero justo: "
	"compara con juegos de exito de Google Play, no con un prototipo. Aunque la nota sea buena, nombra SIEMPRE al menos dos "
	"cosas concretas que mejorar (el 12 nov un 6/10 llego sin ningun problema y no se pudo aprender nada de el).")


def _png(ruta: Path, lado: int = 640) -> str:
	img = Image.open(ruta).convert("RGB")
	img.thumbnail((lado, lado))
	b = io.BytesIO()
	img.save(b, "PNG")
	return base64.b64encode(b.getvalue()).decode("ascii")


def elegir(capturas: list[str]) -> list[Path]:
	"""Pura: titulo, dos de partida y el jefe si lo hay (las que mejor ensenan el juego), en ese orden."""
	por_nombre = {Path(c).name: Path(c) for c in capturas}
	orden = ["1_titulo.png", "3_juego.png", "4_juego.png", "6_jefe.png"]
	elegidas = [por_nombre[n] for n in orden if n in por_nombre]
	return elegidas or [Path(c) for c in capturas[:3]]


def criticar(capturas: list[str], titulo: str, genero: str, gasto: llm.Gasto) -> dict | None:
	"""{nota, problemas: [{tipo, detalle}], lo_mejor} o None si no se pudo."""
	elegidas = elegir(capturas)
	if not elegidas:
		return None
	contenido: list[dict] = [{"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": _png(c)}} for c in elegidas]
	contenido.append({"type": "text", "text": f"Juego: «{titulo}» (genero: {genero}). Capturas: titulo, partida y, si hay, el jefe. Llama a la herramienta."})
	try:
		r = llm.llamar_herramienta(llm.MODELOS[0], SISTEMA, [{"role": "user", "content": contenido}], HERRAMIENTA, gasto, "critica_visual", max_tokens=1000)
	except Exception:  # noqa: BLE001 - la critica nunca para un juego
		return None
	return normalizar(r)


def normalizar(r: object) -> dict | None:
	"""Pura: deja la respuesta de la IA en una forma segura (o None si no vale)."""
	if not isinstance(r, dict):
		return None
	try:
		nota = max(1, min(10, int(r.get("nota"))))
	except (TypeError, ValueError):
		return None
	problemas = []
	for p in r.get("problemas") or []:
		if isinstance(p, dict) and str(p.get("detalle") or "").strip():
			problemas.append({"tipo": str(p.get("tipo") or "otro")[:30], "detalle": str(p["detalle"])[:140]})
	return {"nota": nota, "problemas": problemas[:6], "lo_mejor": str(r.get("lo_mejor") or "")[:140]}


def resumen(c: dict) -> str:
	"""Pura: una linea para el progreso del trabajo."""
	if not c["problemas"]:
		return f"Nota visual {c['nota']}/10. {c['lo_mejor']}".strip()
	return f"Nota visual {c['nota']}/10. " + " | ".join(f"{p['tipo']}: {p['detalle']}" for p in c["problemas"])

"""Laboratorio de prompts: prueba A/B a ciegas de una mejora de la directora (13 nov 2026).

Para cada idea se hacen dos disenos: A (como hasta ahora) y B (con la mejora que se prueba, hoy la
directora creativa de director/conceptos.py). Un juez (modelo superior) los recibe en orden
aleatorio, sin saber cual es cual, y puntua gancho, claridad, retencion, originalidad y encaje con
la idea, y elige el mejor. Asi una mejora de prompt solo se queda si gana de verdad.

	python laboratorio.py 6            (6 ideas de la lista; necesita ANTHROPIC_API_KEY)
	ORQ_LAB_IDEAS="idea 1|idea 2" python laboratorio.py

Escribe laboratorio/informe.md y laboratorio/resultados.json. Lo corre el workflow «Laboratorio»
(GitHub Actions, gratis en repositorio publico); el informe va a la rama «laboratorio».
"""

import json
import os
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from director import director, llm  # noqa: E402

IDEAS = [
	"un juego de gatos",
	"un reino de fantasia al estilo Kingshot con elfos y enanos contra un senor oscuro",
	"un pulpo cocinero que reparte sushi en patines por un mercado",
	"algo de dinosaurios para mi hijo de 5 anos",
	"un juego de miedo en un hospital abandonado pero sin sangre",
	"una abuela hacker que salva la ciudad",
	"un juego relajante de jardineria en la luna",
	"un battle royale de patos de goma en una banera",
	"un detective que es un perro y resuelve misterios en Venecia",
	"un juego donde eres un volcan dormido que despierta",
	"una carrera de caracoles con turbo",
	"un juego tipo survivor con un mago de las tormentas",
]

CRITERIOS = ("gancho", "claridad", "retencion", "originalidad", "encaje")

JUEZ_PROMPT = """Eres productora ejecutiva en un estudio top de juegos de movil y decides que proyecto
recibe presupuesto. Recibes la idea de una persona y dos disenos (1 y 2) hechos para esa idea. No
sabes quien hizo cada uno. Puntua cada diseno de 1 a 10 en:
- gancho: te para el scroll en una tienda de apps (titulo, lema, personaje, la frase del juego);
- claridad: se entiende que se hace y se juega con un dedo;
- retencion: ganas de volver (progresion, historia, desbloqueos, jefe, variedad de niveles);
- originalidad: frente a los juegos top de su genero, no es "uno mas";
- encaje: respeta lo que pidio la persona (personaje, tono, publico, tipo de juego).
Se dura y concreta: un 9 o un 10 es excepcional. Elige el que financiarias y di por que en una frase.
Llama a la herramienta `juzgar` una vez."""

_NOTAS = {"type": "object", "additionalProperties": False, "required": list(CRITERIOS),
	"properties": {k: {"type": "integer", "minimum": 1, "maximum": 10} for k in CRITERIOS}}
JUEZ = {
	"name": "juzgar",
	"description": "Notas de los dos disenos y el elegido.",
	"input_schema": {"type": "object", "additionalProperties": False,
		"required": ["notas_1", "notas_2", "ganador", "por_que"],
		"properties": {"notas_1": _NOTAS, "notas_2": _NOTAS, "ganador": {"type": "integer", "enum": [1, 2]},
			"por_que": {"type": "string", "maxLength": 300}}},
}

CAMPOS = ("titulo", "lema", "resumen", "genero", "giros", "heroe", "enemigos", "jefe", "coleccionable",
	"escenario", "niveles", "poderes", "tutorial", "contenido", "historia", "voz", "publico", "dificultad")


def resumen_diseno(d: dict) -> str:
	x = {k: d[k] for k in CAMPOS if k in d}
	## La historia completa es larga: con 2 niveles basta para juzgar el tono.
	if isinstance(x.get("historia"), list):
		x["historia"] = x["historia"][:2]
	return json.dumps(x, ensure_ascii=False)[:9000]


def disenar(idea: str, mejora: bool, gasto: llm.Gasto) -> dict:
	os.environ["ORQ_CONCEPTOS"] = "1" if mejora else "0"
	d, _ = director.disenar(idea, False, gasto)
	return d


def juzgar(idea: str, a: dict, b: dict, rng: random.Random, gasto: llm.Gasto) -> dict:
	b_primero = rng.random() < 0.5
	uno, dos = (b, a) if b_primero else (a, b)
	usuario = (f"<idea>\n{idea}\n</idea>\n\n<diseno_1>\n{resumen_diseno(uno)}\n</diseno_1>\n\n"
		f"<diseno_2>\n{resumen_diseno(dos)}\n</diseno_2>")
	j = llm.llamar_herramienta(llm.MODELOS[-1], JUEZ_PROMPT, [{"role": "user", "content": usuario}], JUEZ, gasto,
		"juez", max_tokens=800)
	na, nb = (j["notas_2"], j["notas_1"]) if b_primero else (j["notas_1"], j["notas_2"])
	gana_b = (j["ganador"] == 1) == b_primero
	return {"notas_a": na, "notas_b": nb, "gana": "B" if gana_b else "A", "por_que": j.get("por_que", "")}


def generos_concepto(n: int) -> int:
	"""Que la directora creativa no empeore la eleccion de genero: n casos de pruebas/eval_director."""
	from director import conceptos
	from pruebas import eval_director
	rng = random.Random(int(os.environ.get("ORQ_LAB_SEMILLA", "13")))
	casos = rng.sample(eval_director.CASOS, min(n, len(eval_director.CASOS)))
	gasto = llm.Gasto()
	ok, fallos = 0, []
	for idea, buenos in casos:
		x = conceptos.explorar(idea, gasto, director.pistas_genero(idea))
		g = (x or {}).get("final", {}).get("genero", "(fallo)")
		if g in buenos:
			ok += 1
		else:
			fallos.append(f"{idea!r}: {g} (esperado {' o '.join(buenos)})")
	for f in fallos:
		print("  FALLO", f)
	print(f"::notice::Genero de la directora creativa: {ok}/{len(casos)} ({ok / max(1, len(casos)):.0%}) | {gasto.usd:.2f} $")
	return 0


def main(argv: list[str]) -> int:
	n = int(argv[0]) if argv and argv[0].isdigit() else 6
	if os.environ.get("ORQ_LAB_MODO") == "generos":
		return generos_concepto(n)
	ideas = [i.strip() for i in os.environ.get("ORQ_LAB_IDEAS", "").split("|") if i.strip()] or IDEAS[:n]
	rng = random.Random(int(os.environ.get("ORQ_LAB_SEMILLA", "13")))
	gasto = llm.Gasto()
	filas = []
	for idea in ideas:
		try:
			a = disenar(idea, False, gasto)
			b = disenar(idea, True, gasto)
			concepto = director.ULTIMO_CONCEPTO
			j = juzgar(idea, a, b, rng, gasto)
		except llm.ErrorIA as e:
			print(f"::warning::{idea[:50]}: {e}")
			continue
		filas.append({"idea": idea, "a": {"titulo": a["titulo"], "genero": a["genero"], "lema": a.get("lema", "")},
			"b": {"titulo": b["titulo"], "genero": b["genero"], "lema": b.get("lema", "")},
			"concepto": concepto, **j})
		print(f"{j['gana']} | {idea[:50]} | A {sum(j['notas_a'].values())} «{a['titulo']}» ({a['genero']}) | "
			f"B {sum(j['notas_b'].values())} «{b['titulo']}» ({b['genero']})", flush=True)
	out = Path("laboratorio")
	out.mkdir(exist_ok=True)
	(out / "resultados.json").write_text(json.dumps(filas, ensure_ascii=False, indent=1), encoding="utf-8")
	(out / "informe.md").write_text(informe(filas, gasto.usd), encoding="utf-8")
	if filas:
		gb = sum(1 for f in filas if f["gana"] == "B")
		print(f"::notice::Laboratorio: B gana {gb}/{len(filas)} | media A {media(filas, 'notas_a'):.1f} | "
			f"media B {media(filas, 'notas_b'):.1f} (de 50) | {gasto.usd:.2f} $")
	return 0 if filas else 1


def media(filas: list[dict], k: str) -> float:
	return sum(sum(f[k].values()) for f in filas) / max(1, len(filas))


def informe(filas: list[dict], usd: float) -> str:
	ls = ["# Laboratorio de prompts: directora creativa (B) frente a la de siempre (A)", ""]
	if filas:
		gb = sum(1 for f in filas if f["gana"] == "B")
		ls += [f"B gana {gb} de {len(filas)}. Media de 50: A {media(filas, 'notas_a'):.1f}, B {media(filas, 'notas_b'):.1f}. "
			f"Coste {usd:.2f} $.", ""]
		ls += ["| criterio | A | B |", "|---|---|---|"]
		for c in CRITERIOS:
			ma = sum(f["notas_a"][c] for f in filas) / len(filas)
			mb = sum(f["notas_b"][c] for f in filas) / len(filas)
			ls.append(f"| {c} | {ma:.1f} | {mb:.1f} |")
		ls.append("")
	for f in filas:
		ls += [f"## {f['idea']}", "",
			f"- A: «{f['a']['titulo']}» ({f['a']['genero']}) {f['a']['lema']} -> {sum(f['notas_a'].values())}",
			f"- B: «{f['b']['titulo']}» ({f['b']['genero']}) {f['b']['lema']} -> {sum(f['notas_b'].values())}",
			f"- Gana {f['gana']}: {f['por_que']}"]
		c = f.get("concepto")
		if c:
			ls.append("- Conceptos: " + " / ".join(f"{x.get('gancho', '')} [{sum(int(v) for v in (x.get('notas') or {}).values())}]"
				for x in c.get("conceptos", [])))
			ls.append(f"- Elegido: {c.get('por_que', '')}")
		ls.append("")
	return "\n".join(ls)


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))

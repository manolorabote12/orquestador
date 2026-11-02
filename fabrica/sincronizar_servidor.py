"""Copia al servidor (supabase/functions/_shared/cambios-datos.ts) lo que comparten la fabrica y
la funcion plan-change: esquema de operaciones, precios, prompt de Chispa y el registro de generos. Ejecutalo tras cambiar
cualquiera de esos archivos:  python sincronizar_servidor.py   (con --comprobar solo verifica)."""

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
DESTINO = RAIZ.parent / "supabase" / "functions" / "_shared" / "cambios-datos.ts"
## La app tambien ensena las plantillas de exito (galeria del taller).
DESTINO_APP = RAIZ.parent / "app" / "src" / "plantillas-datos.ts"
PROTEGIDOS_DE = RAIZ / "director" / "director.py"


def generar() -> str:
	esquema = json.loads((RAIZ / "director" / "cambios.schema.json").read_text(encoding="utf-8"))
	precios = {k: v for k, v in json.loads((RAIZ / "director" / "precios_cambios.json").read_text(encoding="utf-8")).items() if not k.startswith("_")}
	prompt = (RAIZ / "director" / "prompt_cambios.md").read_text(encoding="utf-8")
	sys.path.insert(0, str(RAIZ))
	from director import director  # noqa: E402
	import generos  # noqa: E402
	import plantillas  # noqa: E402
	import giros  # noqa: E402
	giros_srv = {k: {c: v[c] for c in ("nombre", "que", "generos", "seguro", "mezcla")} for k, v in giros.GIROS.items()}
	return (
		"// GENERADO por fabrica/sincronizar_servidor.py: no editar a mano.\n"
		"// Esquema de operaciones, precios y prompt de Chispa compartidos con la fabrica.\n\n"
		f"export const ESQUEMA_CAMBIO = {json.dumps(esquema, ensure_ascii=False)} as const;\n\n"
		f"export const PRECIOS_CAMBIO: Record<string, number> = {json.dumps(precios)};\n\n"
		f"export const PROMPT_CAMBIO = {json.dumps(prompt, ensure_ascii=False)};\n\n"
		f"export const PROTEGIDOS: string[] = {json.dumps(director.PROTEGIDOS, ensure_ascii=False)};\n\n"
		"// Que admite cada genero (fabrica/generos.py).\n"
		f"export const GENEROS: Record<string, Record<string, boolean>> = {json.dumps(generos.para_servidor())};\n"
		"\n// Editor manual de niveles: letras validas, obligatorias y tamano por genero (fabrica/generos.py).\n"
		f"export const EDITOR: Record<string, {{ letras: string; una: string; filas: number[]; ancho: number[] }}> = {json.dumps(generos.EDITOR)};\n"
		"\n// Plantillas de exito validas en «[plantilla:id] idea» (fabrica/plantillas.py).\n"
		f"export const PLANTILLAS: string[] = {json.dumps(sorted(plantillas.PLANTILLAS))};\n"
		"\n// Giros y mezclas (fabrica/giros.py): generos donde valen. \"*\" = todos.\n"
		"export const GIROS: Record<string, { nombre: string; que: string; generos: string[] | \"*\"; seguro: boolean; mezcla: boolean }> = "
		f"{json.dumps(giros_srv, ensure_ascii=False)};\n"
		"\n// Que es cada genero, en una frase (para proponer ganchos originales).\n"
		f"export const GENEROS_ETIQUETA: Record<string, string> = {json.dumps({g: x['etiqueta'] for g, x in generos.GENEROS.items()}, ensure_ascii=False)};\n"
	)


def generar_app() -> str:
	sys.path.insert(0, str(RAIZ))
	import plantillas  # noqa: E402
	import giros  # noqa: E402
	import generos  # noqa: E402
	import monetizacion  # noqa: E402
	perfil_genero = {g: monetizacion.perfil(x.get("kit", "")) for g, x in generos.GENEROS.items()}
	perfiles_mon = {k: monetizacion.informe("", k == "infantil", k) for k in monetizacion.PERFILES}
	nombres = {g: x["etiqueta"].split(":")[0].strip()[:1].upper() + x["etiqueta"].split(":")[0].strip()[1:] for g, x in generos.GENEROS.items()}
	lista_giros = [{"id": k, "nombre": v["nombre"], "que": v["que"], "generos": v["generos"], "mezcla": v["mezcla"]} for k, v in giros.GIROS.items()]
	lista = [{"id": k, "nombre": p["nombre"], "genero": p["genero"], "idea": p["idea"], "tema": p["tema"], "por_que": p["por_que"],
		"infantil": p.get("publico") == "infantil", "categoria": p.get("categoria", "accion"), "giros": p.get("giros", [])}
		for k, p in plantillas.PLANTILLAS.items()]
	return (
		"// GENERADO por fabrica/sincronizar_servidor.py desde fabrica/plantillas.py: no editar a mano.\n\n"
		"export interface Plantilla { id: string; nombre: string; genero: string; idea: string; tema: string; por_que: string; infantil: boolean;\n"
		"  categoria: \"accion\" | \"puzle\" | \"estrategia\" | \"relax\" | \"ninos\" | \"aula\" | \"unicas\"; giros: string[] }\n\n"
		f"export const PLANTILLAS: Plantilla[] = {json.dumps(lista, ensure_ascii=False, indent=2)};\n"
		"\n// Giros y mezclas (fabrica/giros.py): la app los ofrece en el taller de cada juego.\n"
		"export interface Giro { id: string; nombre: string; que: string; generos: string[] | \"*\"; mezcla: boolean }\n\n"
		f"export const GIROS: Giro[] = {json.dumps(lista_giros, ensure_ascii=False, indent=2)};\n"
		"\n// Nombre corto de cada genero (fabrica/generos.py) para las tarjetas de la app.\n"
		f"export const GENERO_NOMBRE: Record<string, string> = {json.dumps(nombres, ensure_ascii=False, indent=2)};\n"
		"\n// Monetizacion (fabrica/monetizacion.py, la misma que orqkit/kit/monetize.gd): perfil de cada genero y\n"
		"// lo que lleva cada perfil, para explicarselo al autor en la seccion de anuncios.\n"
		"export interface InformeMonetizacion { perfil: string; nombre: string; por_que: string; banner: string; intersticial: string;\n"
		"  anuncio_al_volver: boolean; premios: string[]; compras: string[]; bloques_admob: string[] }\n\n"
		f"export const PERFIL_GENERO: Record<string, string> = {json.dumps(perfil_genero, ensure_ascii=False, indent=2)};\n\n"
		f"export const MONETIZACION: Record<string, InformeMonetizacion> = {json.dumps(perfiles_mon, ensure_ascii=False, indent=2)};\n"
	)


if __name__ == "__main__":
	texto = generar()
	texto_app = generar_app()
	if "--comprobar" in sys.argv:
		igual = DESTINO.exists() and DESTINO.read_text(encoding="utf-8") == texto \
			and DESTINO_APP.exists() and DESTINO_APP.read_text(encoding="utf-8") == texto_app
		print("sincronizado" if igual else "DESINCRONIZADO: ejecuta python sincronizar_servidor.py")
		sys.exit(0 if igual else 1)
	DESTINO.write_text(texto, encoding="utf-8")
	DESTINO_APP.write_text(texto_app, encoding="utf-8")
	print("escrito", DESTINO)

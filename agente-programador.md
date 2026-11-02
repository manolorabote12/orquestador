# Agente programador de la fábrica: calidad, memoria y elección de modelos

Principio: ningún modelo es infalible. La fábrica no confía en lo que el modelo *dice*,
solo en lo que **se comprueba**. Nada llega al usuario sin pasar todas las verificaciones.

## 1. Memoria por proyecto (coherencia entre sesiones)

Cada juego tiene su propia memoria, igual que la que usamos con Ashen of Thrones:

| Pieza | Qué guarda | Quién la actualiza |
|---|---|---|
| **MEMORIA.md** | Arquitectura, autoloads, reglas del proyecto, decisiones, lecciones de bugs, pendientes | El agente, al cerrar cada sesión |
| **Biblia del juego** | Diseño, estilo, personajes, música, voces | El director; el usuario la aprueba |
| **Mapa del código** | Cada archivo: clases, funciones, señales, variables, quién llama a quién | Se regenera solo en cada cambio, leyendo el código real |
| **Buscador del proyecto** | Búsqueda por significado en código, memoria y Biblia | Se indexa solo (Supabase + pgvector) |
| **Historial** | Un commit por cambio, con el motivo | Automático (git) |
| **Resumen de sesión** | Qué se hizo, qué falta, qué falló | El agente, al terminar |

Antes de tocar nada, el agente **lee la memoria, el mapa y los archivos reales** que va a
cambiar. Prohibido afirmar que un método existe sin haberlo encontrado en el código o en
la API de Godot. Es la lección de Ashen: grepear antes de añadir una variable o función.

## 2. Barreras contra alucinaciones y bugs (en orden)

1. **Comprobación de la API real de Godot.** Godot exporta su API completa (`--doctool`).
   Cada método, propiedad y señal que usa el código se contrasta con esa lista y con el mapa
   del proyecto. Lo inventado se detecta antes de ejecutar nada.
2. **Compilación sin pantalla.** Godot 4.6 analiza todos los scripts; cualquier error o aviso
   grave detiene el cambio.
3. **Linter con las reglas de la casa** (las de Ashen): tabs, ASCII, tipos explícitos,
   `.get()` de dos argumentos sobre nodos, `class_name` junto a autoload, comentarios "1)",
   `set()` sobre propiedades inexistentes, variables duplicadas.
4. **Pruebas automáticas**: las del kit (26 hoy) más las que el agente escribe para cada
   mecánica nueva. Un cambio sin prueba no entra.
5. **Bots y analizadores**: niveles completables, cero errores de script durante minutos de
   juego, rendimiento dentro de límite. Los fallos silenciosos se convierten en `QA.fail`.
6. **Revisión cruzada**: un modelo de **otra familia** revisa cada cambio. Si discrepan,
   se corrige antes de seguir.
7. **Cambios pequeños con marcha atrás**: un commit por paso; si algo empeora, se deshace solo.
8. **Revisión visual**: capturas automáticas que una IA con visión compara con la Biblia.

## 3. Elección automática del modelo (calidad-precio)

- **Router**: el agente pide "haz esta tarea"; el router elige el modelo. Cambiar o añadir
  modelos es configuración, no código.
- **Examen propio de GDScript**: tareas reales del kit, corregidas solas por las pruebas.
  Cada modelo candidato se mide en aciertos, coste por tarea y velocidad. Se repite con cada
  modelo nuevo que salga.
- **Escalado automático**: las tareas sencillas empiezan en el modelo más barato que aprueba
  el examen. Si sus cambios fallan las pruebas dos veces, la tarea sube al modelo más potente.
  Así se paga caro solo cuando hace falta.
- **Reparto por tipo de tarea**: diseño y arquitectura → el mejor modelo; código rutinario →
  el más barato que apruebe; revisión → un modelo de otra familia; respaldo si un proveedor cae.
- **Candidatos**: Claude (Sonnet, Haiku), equivalentes de OpenAI y Google, y modelos abiertos
  de código (Qwen-Coder, DeepSeek, GLM, Kimi) autoalojados o por API. Licencias y versiones
  se verifican antes de integrar cada uno.

## 4. Qué se le promete al usuario (y qué no)

- **Sí**: cada versión entregada compila, pasa todas las pruebas y los bots, y respeta la Biblia.
- **No**: que un juego no tenga ningún bug nunca. Lo que no cubren las pruebas puede fallar;
  cada bug que aparezca se convierte en una prueba nueva y en una lección en MEMORIA.md,
  para que no se repita.

## 5. Aprendizaje continuo: que la fábrica mejore con cada juego

Tres niveles, de más barato y rápido a más caro y potente:

### Nivel 1 - Memoria de experiencia (desde el primer día, sin entrenar nada)
- **Registro de cada trabajo**: tarea, modelo, código, resultado de las pruebas, coste y qué
  hizo el usuario después (aceptó, editó o deshizo).
- **Biblioteca de soluciones verificadas**: cada cambio que pasó todas las pruebas se guarda.
  Ante una tarea parecida, el agente recibe los mejores ejemplos reales como guía.
- **Lecciones globales**: cada bug encontrado en cualquier juego se convierte en regla del
  linter, prueba nueva o lección para todos los juegos futuros (como MEMORIA.md, pero de la fábrica).
- **Router que aprende**: lleva la cuenta de qué modelo acierta en cada tipo de tarea y le da
  más trabajo al que mejor rinde por euro (algoritmo de tipo "bandido multibrazo").

### Nivel 2 - Ajuste fino de modelos abiertos (con miles de ejemplos verificados)
- Entrenar con LoRA, en RunPod, un modelo abierto de código con las soluciones que pasaron
  las pruebas: se especializa en GDScript y en nuestro kit.
- Lo mismo para imagen: LoRAs de estilo entrenados con el arte que los usuarios aprobaron.
- Las elecciones de los usuarios (esta versión sí, esta no) sirven para entrenar preferencias.
- Los modelos cerrados (Claude, GPT...) no se reentrenan por nuestra cuenta: mejoran por el
  nivel 1 y los usa el router mientras sean los mejores.

### Nivel 3 - Aprendizaje por refuerzo con recompensa verificable (más adelante)
- Las pruebas automáticas dan una recompensa objetiva (pasa / no pasa). Con eso se puede
  entrenar un modelo abierto para que programe cada vez mejor en nuestro entorno.
- Es lo más potente y lo más caro; tiene sentido cuando haya mucho volumen.

### Reglas de seguridad del aprendizaje
- **Solo se aprende de lo verificado**: nada que no haya pasado las pruebas entra en los datos.
- **Ningún modelo nuevo sustituye al actual sin aprobar el examen** con mejor nota.
- **Datos de los usuarios**: usarlos para entrenar exige consentimiento explícito (opción en
  la app y condiciones de uso claras, cumpliendo el RGPD). Sin consentimiento, solo cuentan
  las métricas anónimas.

## Estado (implementado, octubre 2026)

Primera versión en producción como **mods**: lo que el taller no sabe hacer con operaciones lo
programa Claude Sonnet como un script que extiende `res://kit/mod_base.gd`.

| Paso | Qué hace | Dónde |
|---|---|---|
| Petición | En el taller, si Chispa responde «no puedo», sale «Que Chispa lo programe (30 tuercas)» | `app/src/vistas/juegos.ts` → función `program-change` → `queue_mod` |
| Escribir | Claude con la herramienta `escribir_mod`; solo puede usar la API de eventos (`on_level_start`, `on_event`, `on_tick`, `toast`, `burst`, `shake`, `flash_screen`, `play_sound`, `add_wallet` ≤ 50, `param`, `level`) | `fabrica/agente_mods.py` |
| Lista negra | Fuera `FileAccess`, `load`, `OS.`, `Engine.`, `Save.`, `Ads.`, `ProjectSettings`, cambiar escena, salir, inyectar entrada... | `NEGRA_MOD` |
| Compilar | Escena `qa/compilar_mod.tscn` con los autoloads cargados → `[MOD_OK]` | Godot sin pantalla |
| Humo | 6 s de partida buscando `SCRIPT ERROR` | `qa/clip.tscn` |
| Bots | La versión nueva tiene que pasar todos los niveles | `cambio.programar` → `_cerrar_version` |
| Rondas | Hasta 3; los errores vuelven a Claude. Si no sale, se deshace y se devuelven las tuercas | `trabajador.atender_cambio` (kind `game_mod`) |

Cada mod queda como versión nueva (se puede volver atrás gratis) y se lista en `game.json → mods`.
Pendiente: mapa del código y buscador por significado para cambios grandes fuera de los mods.

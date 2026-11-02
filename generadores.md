# Generadores de la fábrica: decisión cerrada (8 oct 2026)

Objetivo: cualquier género, en 2D y 3D, y cualquier estilo (pixel art, cartoon, realista,
low-poly…), con la mejor relación calidad-precio. Todos los modelos son **abiertos, con
licencia comercial y utilizables en la UE**, autoalojados en **RunPod serverless** (pago por
segundo) y probables gratis en la RTX 4060 Ti del desarrollo cuando caben.

## La pieza que da la coherencia: la Biblia del juego

El director de la fábrica la escribe primero, a partir de la idea del usuario, y **todos los
generadores la obedecen**:

- **Estilo visual**: familia (pixel art, cartoon, realista, low-poly), paleta exacta, resolución
  o tamaño de píxel, grosor de línea, imágenes de referencia.
- **Fichas de personaje**: una imagen de referencia por personaje. Todo lo demás (poses,
  animaciones, retratos, modelo 3D) sale **editando o reconstruyendo esa referencia**.
- **Música**: tonalidad, tempo, instrumentos y variaciones de intensidad por escena.
- **Voces**: un perfil por personaje clonado de una muestra fija.
- **Sonido**: paleta de efectos acorde al estilo.

El QA comprueba la coherencia automáticamente (IA con visión frente a las referencias, paleta
forzada, volumen igualado) y regenera lo que desentona.

## Los modelos elegidos

| Uso | Modelo | Licencia | GPU |
|---|---|---|---|
| Imagen principal (rápida, fotorrealista y versátil) | **Z-Image-Turbo** (6B) | Apache 2.0 | 16-24 GB |
| Coherencia: variaciones a partir de referencias | **FLUX.2 [klein] 4B** (multirreferencia) | Apache 2.0 | ~13 GB |
| Edición precisa y texto en imagen (interfaz, logos) | **Qwen-Image-2512** + **Qwen-Image-Edit** | Apache 2.0 | 48 GB |
| Pixel art | Los anteriores + LoRA de estilo + reducción y paleta forzada | — | — |
| Modelos 3D con texturas PBR | **TRELLIS.2-4B** (imagen → GLB) | MIT | 24 GB+ |
| Esqueleto y pesos de piel en 3D | **UniRig** | MIT (código) | 24 GB |
| Animaciones 3D | Retarget desde bibliotecas de animación **CC0** | CC0 | CPU |
| Música | **ACE-Step 1.5 XL** | MIT | 24 GB |
| Voces (español incluido, clonación, emoción) | **Chatterbox Multilingual** | MIT | ~8 GB |
| Voces alternativa | **Qwen3-TTS** | Apache 2.0 | — |
| Efectos de sonido | **Stable Audio 3.0 Small-SFX** + generación procedural (estilo sfxr) | Stability Community (gratis hasta 1 M$/año) | 16-24 GB |
| Código y diseño | **Claude Sonnet 5.5** (agente) y **Haiku 4.5** (tareas simples) | API | — |
| QA visual | Modelo con visión (Claude o un VL abierto) | — | — |

Todo se monta en flujos de **ComfyUI** dentro de trabajadores de RunPod serverless.

## Descartados y por qué

| Modelo | Motivo |
|---|---|
| **Hunyuan3D** (todas las versiones) y Hunyuan-GameCraft | Su licencia **excluye la UE, Reino Unido y Corea del Sur** |
| **Qwen-Image 2.1** | Licencia solo de investigación, sin uso comercial |
| FLUX.1 [dev], FLUX.2 [dev], FLUX.2 [klein] 9B | No comerciales |
| MusicGen, AudioGen, TangoFlux | Pesos no comerciales |
| XTTS-v2, Fish Speech 1.5 | Pesos no comerciales |
| Mixamo | Sin API y condiciones no pensadas para un servicio automatizado |

## Opciones premium (si el usuario paga más)

- **PixelLab** (pixel art con animaciones muy cuidadas) y **ElevenLabs** (voces y efectos).
- Antes de integrarlos: confirmar que sus condiciones permiten usarlos dentro de un servicio para terceros.

## Lo que hay que saber sin adornos

- **3D en móvil**: el estilo realista pesa mucho en móviles baratos. Por defecto, el 3D se
  orienta a **low-poly y estilizado**; el realista queda como opción para móviles potentes.
- **Personajes 3D**: los humanoides se animan bien (esqueleto automático + bibliotecas CC0).
  Las criaturas raras (dragones, arañas) necesitan más trabajo y saldrán más tarde.
- **Licencias**: cambian entre versiones. Antes de cada integración se revisa el archivo de
  licencia **de la versión exacta** que se descarga, y se guarda copia junto al modelo.
- **Costes**: se miden con el registro de coste real por trabajo que ya tiene el backend;
  los precios de las tuercas se ajustan con esos datos.

## Orden de integración

1. Biblia del juego (esquema) + cadena de imagen 2D coherente (Z-Image + FLUX.2 klein + paleta).
2. Audio: ACE-Step (música), Chatterbox (voces), efectos procedurales y Stable Audio.
3. 3D: TRELLIS.2 + UniRig + animaciones CC0, con un primer género 3D en el kit de Godot.
4. Trabajadores en RunPod serverless conectados al sistema de trabajos y tuercas.

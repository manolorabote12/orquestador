# La fábrica de Orquestador (Godot)

Objetivo: que cualquiera, desde el móvil, fabrique juegos 2D **competitivos** de casi
cualquier género casual, y los publique en Google Play. Aunque tarde minutos u horas.

## Dónde superamos a Rosebud AI

| | Rosebud AI | Orquestador |
|---|---|---|
| Motor | JavaScript (Phaser) en el navegador | **Godot 4**: proyecto real con escenas y nodos |
| Android / Google Play | Sin build nativa; hay que empaquetarlo a mano | **.aab firmado** y ayuda para publicar |
| Proyecto descargable | Solo código suelto, sin proyecto | **Proyecto Godot completo**, abrible y editable |
| Calidad | Resultados al azar; le cuesta guardado, economía, progresión | **Kit base pulido** con esos sistemas ya hechos y probados |
| Pruebas | Arreglo de errores al vuelo | **Bots y analizadores** que juegan y comprueban cada versión |
| Dónde se crea | Navegador de escritorio | **App móvil** con Chispa |

## Cómo funciona una fabricación

1. **Entrevista con Chispa**: referencias, controles, gancho y progresión.
2. **Documento de diseño** (mecánicas, niveles, enemigos, economía, anuncios), aprobado por el usuario.
3. **Arte y sonido** con una guía de estilo fija.
4. **Programación por agentes** sobre el kit base: la IA escribe GDScript solo para lo propio de cada juego.
5. **QA automático en bucle**: el proyecto se ejecuta sin pantalla; analizadores y bots buscan cuelgues, niveles imposibles y bajadas de rendimiento. Lo que falla vuelve al paso 4.
6. **Pulido y equilibrio** simulando muchas partidas.
7. **Revisión del usuario** y ajustes por chat.
8. **Empaquetado**: .aab firmado, proyecto descargable y ficha de la tienda.

## Fases de trabajo

### Fase 1: kit base (empezada)
- Núcleo: configuración, efectos de "feeling", guardado seguro, audio, anuncios con reglas anti-abuso y registro para bots.
- Primer género a calidad alta: **plataformas** (coyote time, buffer de salto, salto variable, cámara con anticipación, controles táctiles).
- Primeras herramientas de QA: analizador de niveles imposibles y pruebas automáticas del feeling.
- Criterio de salida: Daniel juega el módulo y lo aprueba como "nivel comercial".

### Fase 2: más géneros en el kit
Runner, flappy, shooter vertical, top-down de acción, puzle de tablero (match-3/merge), tower defense. Sistemas comunes: progresión y mejoras, misiones diarias, tienda interna, logros, tutorial.

### Fase 3: agente programador + QA en la nube
Servidor con Godot sin pantalla: el agente escribe código, ejecuta las pruebas y corrige hasta que pasan. Bots por género, capturas revisadas por IA con visión, medición de rendimiento.

### Fase 4: arte y sonido
Guía de estilo, personajes con animaciones, escenarios en capas, interfaz, efectos, música y sonidos (solo modelos con licencia comercial).

### Fase 5: integración en la app
Trabajos largos con progreso en vivo de Chispa, avisos al terminar, precios por fabricación medidos con coste real, vista previa web dentro de la app.

### Fase 6: publicación
.aab firmado, ficha de tienda generada, Lanzadera (prueba cerrada con testers reales) y ayuda con el cuestionario de producción.

### Después: Unity como segundo motor
Solo tras confirmar con Unity qué licencia exige compilar en servidores para terceros.

## Reglas del código del kit
Las mismas que Ashen of Thrones: tabs, ASCII en el código, tipos explícitos, nunca
class_name junto a un autoload, comentarios numerados "1 -", .get() de un solo argumento
sobre nodos. Los textos del jugador viven en game.json (listos para traducir).

# Profundidad: de 1 hora de juego a muchas (13 nov 2026)

Problema: los juegos salían con 3 a 8 niveles (1–2 horas). La gente se cansa en pocos días.
Objetivo: 10–30 horas según el género, con lo que mantiene a la gente en los juegos top.

## Los 8 módulos de profundidad (comunes a todos los géneros)

| # | Módulo | Qué da | Géneros | Estado |
|---|---|---|---|---|
| 1 | **Campaña larga por mundos** | 30–40 niveles más, dificultad en dientes de sierra, mundos de 5 («Pantano 3-2») | Todos los de niveles (plataformas, puzle, tubos, laberinto...) | **Hecho** (13 nov) |
| 2 | **Mejoras permanentes** | «Fortuna» (+15 % de monedas, 5 niveles) para todos; corazón extra en todos los de acción | Todos | **Hecho** (base) |
| 3 | Ligas asíncronas | Subir de liga contra fantasmas/bots con la puntuación | Carreras, battle royale, RPG, arcade | Pendiente |
| 4 | Torre / modo infinito | Pisos sin fin, cada vez más duros, récord | RPG, supervivencia, shooter, puzle | Pendiente |
| 5 | Colección | Álbum de personajes/cartas/objetos por completar | Todos | Pendiente |
| 6 | Temporadas y eventos | Pase, retos semanales (ya existe el pase y el reto del día) | Todos | Parcial |
| 7 | Prestigio / economía exponencial | Reiniciar con bonus | Tycoon, idle, reino | Parcial (idle) |
| 8 | Asaltos de base asíncronos | Atacar bases de otros (guardadas en Supabase) | Reino, aldea | Pendiente |

Orden acordado: 1+2 → 3 → 4+5 → 8.

## Horas por tipo de juego (lo que buscamos)

- **Puzle / casual** (plataformas, tubos, fusión...): campaña larga (40+ niveles) + reto del día + experto + mejoras.
- **RPG / batallas**: campaña + arena + ligas + torre + colección de héroes.
- **Battle royale / carreras**: partidas cortas + subir de liga + pase de temporada + coches/skins.
- **Supervivencia**: días/oleadas cada vez más duras + base que crece + récord.
- **Reino / tycoon**: economía larga + prestigio + asaltos.

## Módulo 1: campaña larga (cómo funciona)

En `fabrica/cadena.py`, después del reto del día (paso 6b2):
1. Si el género va por niveles (`CAMPANA_KITS`), el generador del género hace 48 niveles más
   (32 + reserva), usando como plantilla la segunda mitad de los niveles del diseño.
2. La dificultad sube con el índice y, encima, por tramos: cada 8 niveles un respiro.
3. **Los bots juegan todos**; solo se quedan los que superan, en orden, hasta 32.
4. Se nombran por mundos («Raíces enredadas 2-3») y la pantalla de niveles ya los agrupa en
   mundos de 5 con estrellas.
5. Si algo falla, el juego sigue con sus niveles de siempre (es un extra).

6. El último nivel generado lleva el jefe: se prueba el primero y cierra la campaña. Si no lo supera
   el bot, el jefe del diseño pasa al final. El final de la historia también va al último nivel.
7. Tope de tiempo de bots: `ORQ_CAMPANA_SEG` (8 min). La primera tanda es de 4 niveles para medir
   cuánto tarda cada uno; las siguientes caben en el tiempo que queda.

`ORQ_CAMPANA_EXTRA` cambia cuántos (0 la apaga; máximo 200). No gasta IA: es generación
procedural + bots. Prueba local (13 nov): plataformas 3→24, puzle 3→35, tubos 3→35, RPG 3→35,
carreras 3→35, battle royale 3→23, supervivencia 4→36, horda 4→36 (acaba en jefe).

## Módulo 2 y 3 (base)

- `orqkit/kit/save.gd`: mejora «fortuna» (+15 % de monedas por nivel, 5 compras: 200 → 4000).
  El corazón extra sale en plataformas, horda, breakout, carriles, shooter y RPG.
- `orqkit/kit/chests.gd` + ruta de trofeos: ligas Bronce (0), Plata (150), Oro (400), Platino (800),
  Diamante (1300), Maestro (2000), Leyenda (3000).

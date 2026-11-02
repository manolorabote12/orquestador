# Giros, mezclas y ganchos originales

Lo que separa un juego que se olvida de uno que engancha suele ser **una regla rara** encima de un
género conocido. Orquestador ya no solo copia géneros: los combina y los retuerce, y lo hace sin
entregar nunca un juego roto, aprendiendo de cada error.

## Qué hay

**Giros** (reglas que se ponen encima de cualquier género compatible, como mucho dos):

| Giro | Qué cambia | Dónde vale |
|---|---|---|
| A oscuras | solo ves lo que alumbra tu linterna | plataformas, runner, volador, hordas, naves, cajas, laberinto, minigolf |
| Mundo espejo | el mundo se ve al revés (los mandos y la interfaz no) | plataformas, runner, volador, hordas, cajas, laberinto, minigolf, serpiente |
| Contrarreloj | cada intento tiene un tiempo; si se acaba, a empezar | laberinto, minigolf, cajas, serpiente, bloques, memoria, rompebloques, saltos, apilar, cartas |
| Racha | cada nivel sin morir sube las monedas (hasta x3) | todos |
| Fantasma | corres contra tu mejor partida: una figura transparente repite tu mejor camino | plataformas, runner, volador, hordas |
| Hielo | las cajas resbalan hasta chocar con algo; hay que pensar dónde se paran | cajas |
| Túneles | huecos en el borde: sales por un lado y entras por el contrario | serpiente |
| Bichos de oro | a veces asoma uno de oro: se va antes, pero vale 3 golpes | topos |
| Notas invisibles | las notas se apagan antes de la línea: se toca de memoria (se pide algo menos y hay más energía) | ritmo |
| Niebla de guerra | solo se ve lo que tienen cerca tus aldeanos, tropas y edificios; lo explorado se recuerda (edificios rivales sí, sus tropas no) | imperio |
| Cartas inquietas | cada 2 fallos, dos cartas tapadas se cambian de sitio (se ve el cambio; hay más intentos) | memoria |
| Viento | empuja la bola mientras rueda (dirección y fuerza por hoyo; el par cuenta con él) | minigolf |
| Tormenta | llueve y los peces nadan cada vez más rápido (el tiempo cuenta con ello) | pesca |
| Piedras | bloques que estorban hasta que una fusión al lado los rompe | fusión |

**Mezclas** (dos géneros en uno, con sus propias reglas, analizador y bot):

- **Laberinto serpiente**: las casillas que dejas atrás se cierran. Hay que pensar el camino
  entero antes de moverse. El analizador busca un camino que lo recoja todo sin repetir casilla, y
  el bot sigue ese mismo camino.
- **Golf de monstruos**: hay monstruos en el campo; la bola los derriba al pasar y el hoyo está
  cerrado hasta derribarlos a todos. El plan del bot apunta primero a los monstruos.
- **Estilos de supervivencia** (se pueden juntar dos): **apocalipsis** (casas y coches que
  saquear, zombis que no temen al fuego, machete, muros, vendas y una radio para escapar, tipo Last
  Day on Earth), **invierno** (frío de noche: hoguera, cama o abrigo de piel) y **caza** (ciervos que
  huyen, jabalíes que embisten, carne cruda que enferma y se asa en la hoguera). Son estilos de la
  plantilla de datos del kit; ver `PLANTILLA-SUPERVIVENCIA-LEEME.md`.
- **Estilos de RPG**: **equipo** (tipo Raid / Summoners War) y **criaturas** (tipo Pokémon); ver
  `PLANTILLA-RPG-LEEME.md`.
- **Estilos de hordas**: **survivor** (tipo Survivor.io) y **vampiros** (tipo Vampire Survivors);
  ver `PLANTILLA-SHOOTERS-LEEME.md`.
- **Estilos de imperio**: **fantasía** y **galáctico**; **karts**: **fiesta** (estrella y cáscara
- **Tycoon**: **mina** (tipo Idle Miner: pozos, ascensor y almacén con cuello de botella).
- **Tragaperras**: **dados** (tipo Monopoly Go: tablero de 20 casillas con ficha y dos dados).
  triple); ver `PLANTILLA-ESTRATEGIA-CARRERAS-LEEME.md`.

**Saltar nivel**: tras 3 derrotas seguidas en un nivel, el panel de derrota ofrece saltarlo
viendo un anuncio con premio (gratis tras 5, o si el juego no tiene anuncios). Así nadie abandona
el juego por un nivel atascado.

**Reto del día**: botón «Reto» en el título. Un nivel ya desbloqueado con un giro sorpresa que
solo cambia cómo se ve (a oscuras o espejo; el fantasma no, porque necesita una partida tuya guardada), elegido por la fecha, con 50 monedas una vez al día.

**Ganchos originales**: en la app, «Proponme 3 ideas originales». La IA propone tres juegos muy
distintos para tu idea (género + giros + idea concreta + por qué engancha). El código comprueba
todo lo que dice la IA: géneros que existen, giros que valen en ese género y que no fallan, nada de
marcas. Si algo no vale, lo cambia por una mezcla probada. Al elegir uno, la fábrica lo hace con
ese género y esos giros.

## Innovar sin errores y aprender de ellos

1. **Todo se prueba con bots**. Los giros se aplican también cuando los bots juegan cada nivel. El
   tiempo de contrarreloj sale de lo que tarda el bot (× 3 + 10 s).
2. **Si un giro rompe un juego, se quita y se rehace sin él**. La persona recibe su juego (sin ese
   giro) en vez de un error, y no se cobra de más.
3. **Cada intento se apunta** (`giro_anotar` en el servidor, de todas las máquinas de la fábrica).
   Un giro que falla en un género (menos del 70 % de éxitos en 5 o más intentos) **deja de
   ofrecerse en ese género**: ni la directora, ni los ganchos, ni el reto del día lo usan. Si
   vuelve a ir bien (por ejemplo, tras arreglar el kit), se vuelve a ofrecer.
4. **Lecciones para la directora**: cada fallo deja una frase («laberinto con cola: los bots no lo
   superan...») que la directora lee antes de diseñar el siguiente juego.
5. **Lote de entrenamiento**: `python -m pruebas.lote_calibracion --giros` fabrica cada giro en
   cada género donde vale y deja la tabla de fiabilidad (`python -m giros informe`).

## Para programadores

- Kit: autoload `Twist` (`orqkit/kit/twist.gd`). Se engancha solo al juego (el nodo con
  `bot_state()`) cuando empieza un nivel. `Twist.has("cola")` lo usan las mezclas dentro de su
  género. Capas: espejo 5, oscuridad 6 (por debajo de los mandos táctiles, 10, y de la interfaz, 20).
- Fábrica: `fabrica/giros.py` (registro, compatibilidades, aprendizaje, guía para la directora,
  marca `[gancho:genero:giros]`). `cadena._quitar_giros` hace la vuelta atrás.
- Servidor: `migraciones/…31_giros_ganchos.sql` y la función `ganchos`. El registro se sincroniza
  con `python sincronizar_servidor.py`.
- Taller: operación `giros` (lista completa; 3 tuercas). Las mezclas rehacen los niveles.
- Pruebas: `python -m pruebas.prueba_giros` (incluye un error a propósito que la fábrica tiene que
  superar sola), kit `--solo=twists`, `supabase/pruebas/giros.sql` y `ganchos.mjs`.

# Más juegos de los que más se juegan en 2026

## Multitud (`multitud`, kit `crowd`) · tipo Count Masters y el anuncio de Last War

Tu grupo corre solo; deslizas a izquierda o derecha para pasar por la mejor de cada par de puertas
(+10, x2, -5, ÷2...), esquivar trampas y vencer a los grupos enemigos. Al final, el jefe: hay que
llegar con más gente que él.

- Las puertas siempre crecen con la gente que llevas, así que quedarse con la mejor en cada una es
  el mejor camino: el analizador lo calcula exacto y el jefe pide entre un 60 y un 85 % de ese
  máximo (hay que elegir bien casi siempre, pero no hace falta ser perfecto). El peor camino pierde.
- Estrellas según la gente que te sobra frente a lo mejor posible.

## Fusión con pedidos (`pedidos`, kit `mergeboard`) · tipo Gossip Harbor y Merge Mansion

Tablero de 7x9 con generadores (horno, tetera, jardín, caja de herramientas). Tocar uno saca un
objeto de nivel 1 (gasta energía); arrastrar dos iguales los fusiona en el siguiente. Los clientes
piden objetos y al entregarlos das las gracias, ganas monedas y avanza el nivel.

- La energía se recarga con el tiempo y con un anuncio (+25): la forma de ganar dinero del género.
- Cada nivel lleva la energía justa: la mitad al empezar y el resto llega hacia el 75 % del tiempo
  de 3 estrellas (un objeto de nivel L sale de 2^(L-1) toques). El bot cumple los pedidos con
  exactamente esa energía.
- Las cadenas (nombres de cada nivel, generador, color y dibujo) son por datos en
  `kit/mergeboard/merge_catalog.json`.

## Reglas programables en más géneros (capa 2 de «cualquier juego»)

Además de caída, mundo de cubos y battle royale, ahora la IA puede escribir **reglas** (código que
cambia la mecánica, no solo los efectos) en tycoon, tragaperras, reino, multitud, fusión con
pedidos, adivina la palabra y palabras con letras. Cada simulación llama a sus ganchos (en
`orqkit/kit/rule_base.gd` está la lista) y, como el analizador y los bots usan la misma
simulación, cada nivel se vuelve a comprobar con la regla puesta. Ejemplos de lo que se puede
pedir en el taller: «que cada 10 ciclos la limonada dé el triple», «que el cofre a veces traiga
tiradas», «que tras cada victoria se unan soldados del enemigo», «que las puertas x2 cambien de
lado» o «que las palabras largas den monedas extra».

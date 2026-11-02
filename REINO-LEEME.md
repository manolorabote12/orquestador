# Reino: estrategia tipo Kingshot y Whiteout Survival

Los juegos que más facturan del mundo en 2026 junto al MOBA chino son de este tipo (Whiteout
Survival, Last War, Kingshot). Su gancho: **tu ejército crece solo, en tiempo real**, y siempre
hay algo que mejorar.

## Cómo se juega (`reino`, kit `realm`)

- **Ciudad**: castillo (ningún edificio puede pasar de su nivel), granja, aserradero y cantera
  (producen solos) y cuartel, establo y arquería (entrenan soldados sin parar mientras haya comida).
- **Un constructor**: una mejora a la vez y con su tiempo. **Ayuda** gratis cada 20 s (la obra va
  un 30 % más rápido) y **Terminar ya** viendo un anuncio (lo que más ingresos da en el género).
- **Tropas** con piedra, papel, tijera: lanceros ganan a jinetes, jinetes a arqueros y arqueros a
  lanceros. Batallas por rondas; la mitad de los caídos vuelven heridos y curados.
- **Mapa**: campamentos en orden, con el poder enemigo a la vista frente al tuyo (verde si ganas
  seguro, amarillo justo, rojo si no). Ganar da recursos y **héroes** (más ataque a un tipo de
  tropa). El último es el jefe: derrotarlo gana el nivel.
- La ciudad se guarda sola y sigue produciendo y entrenando con la app cerrada (hasta 2 horas).

## Cómo se asegura que cada nivel es justo

Cada campamento dice **cuándo** debería caer (una parte del tiempo de 3 estrellas) y **cuánto
más débil o fuerte** es que tu ejército de ese momento. El juego simula al bot construyendo y
entrenando y monta cada campamento a esa medida: así el reto vale con cualquier catálogo, también
con lo que invente la IA. El analizador juega el nivel entero y comprueba que se conquista a tiempo
(en las pruebas: 24 de 24 niveles, de fácil a difícil).

## Por datos

Catálogo en `kit/realm/realm_catalog.json`. La IA puede inventar el reino de cada juego: nombres de
recursos, edificios, tropas, héroes y campamentos (un reino helado con cazadores, trineos de lobos
y la Fortaleza del Rey Yeti) y cambiar la vida y el ataque de las tropas un 30 % como mucho.

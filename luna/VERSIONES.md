# Bajo la Luna Roja

Estrategia de conquista sin conexión en scroll lateral (horizontal). De día la reina, a lomos de un ciervo
blanco, paga brasas para reclutar vagabundos, comprarles herramientas (arquero, constructor, granjero,
lancero) y construir; de noche las sombras salen de las grietas de los dos extremos y atacan los muros.

- v1 (22 nov, Claude en sesión + RunPod): 3 valles (Ciervo, Ciénaga Gris, Picos de Ceniza) + Luna eterna;
  5 lunas (llena, nueva, creciente, azul con mercader fantasma, roja cada 5 noches con jefe); sombras que
  roban brasas o herramientas y huyen; brutos que derriban muros, alados que los sobrevuelan; muros de 3
  niveles (dibujados por código), torres, granjas, hoguera de 3 niveles, campamentos, cofres; asalto de
  grietas con soldados; oscuridad con luces (farol, hoguera, torres); guardado en cada amanecer, volver al
  último amanecer (con anuncio o perdiendo 25% de brasas); tienda; ES/EN/PT; 5 músicas ACE-Step.
  Arte RunPod ~0,15 $ (dos tandas: la primera salió con fondos; se repitió con prompt de sprite aislado).
  Bot: valle 1 ganado en 12 y 20 días; valle 2 ganado en 20 / perdido en el 21; valle 3 perdido en el 10 /
  ganado en 45. Recorrido 26 pantallas, mono 353 acciones sin errores.
- v2 (22 nov): animación (pasos con rebote y estirado, constructores martilleando, arqueros tensando,
  lanceros embistiendo, polvo del ciervo al galope, sombras con estela de humo y estallido al morir, aura
  del jefe), flechas con punta y plumas, brasas que vuelan a la reina, minimapa del valle, cielo teñido
  por la luna, estrellas, pájaros, niebla y luciérnagas de noche, lluvia en la Ciénaga, ceniza en los
  Picos, antorchas en los muros, humo de la hoguera, tiendas con toldo, bosque lejano en silueta.
- v3 (22 nov): 3 héroes rescatables en santuarios (Caballero de la Aurora con onda que empuja, Bruja de la
  Ciénaga con bolas y llamarada verde, Cazadora de Estrellas con lluvia de estrellas), habilidades de la reina
  (Destello del farol que quema y aturde; Cuerno de guerra +60% daño), fragmentos de luna (jefes, grietas,
  valles) y Altar de la Luna con 5 mejoras permanentes, criaturas propias (ahogados en la Ciénaga, gólems de
  lava en los Picos), cielos y árboles propios de cada valle, números de daño, parón de impacto, sombras en
  el suelo, guía de los primeros días, brasas flotando en la portada. Dificultad: Ciénaga ×1,42, Picos ×1,95.
  Bot: valle 1 en 21 y 36 días; valle 2 en 17 y 19; valle 3 ganado en 14 / perdido en el 30.
- v4 (22 nov): 6 valles (nuevos: Bosque Helado con lobos de escarcha, Cañón Dorado con escorpiones,
  Ruinas del Rey con espectros; cielos y árboles propios), 6 héroes (nuevos: Monje del Alba, Ingeniera Brasa,
  Druida del Roble), catapultas, 10 mejoras en el Altar, 15 logros con fragmentos. Integración: luz de ambiente
  en sprites y suelo, hierba delante de los pies, bosque lejano con perspectiva atmosférica y bruma, árboles
  sin tierra pegada, bordes de sprites limpios, humo suave. Valles duros: fuerza que sube en 8 noches y
  empalizadas iniciales. Bot (con las mejoras que tendría un jugador desde el valle 4): 5 de 6 valles.
- v5 (23 nov, noche; feedback de Daniel con capturas del móvil): sin franja gris en móviles alargados
  (ancho real del viewport); mapa el doble de largo (grietas a mitad de camino, tierra salvaje detrás con
  cofres y campamento); capas de fondo pintadas por valle (cascada y castillo, ciénaga, volcanes con lava,
  palacio de hielo, pirámide y esfinge, castillo gótico) + capa media (bosque y molino, árboles quemados,
  ruinas, palmeras) en espejo sin costuras; monumentos (estatua del rey, ángel, monolito, obelisco, molino,
  torre, arco, barco); agua en primer plano que refleja el mundo (shader con ondas y brillos; lava en
  Ceniza, calma en Nieve, sin agua en el desierto); portal nuevo (anillo de piedra) con espiral que gira,
  ruge, tiembla y escupe criaturas que crecen desde el remolino; puestos pintados; fin del parpadeo del
  fondo (siluetas suaves); arreglo del volteo de sprites (Rect2 negativo los desplazaba); jefes únicos por
  valle con habilidad y fase 2 (embestida, invocar ahogados, lluvia de fuego, aliento helado, enterrarse,
  guardia de espectros); 3 monturas en el altar (reina montada en caballo, oso o grifo con ventajas);
  personajes repintados (sin cabezas cortadas) y animados con Wan 2.2 (51 hojas: andar, atacar, morir,
  galope de la reina...); interfaz pintada (hierro negro, oro y rubíes). Bot: 5/6 valles.

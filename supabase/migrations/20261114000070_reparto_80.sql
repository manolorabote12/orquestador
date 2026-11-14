-- Reparto de los anuncios de la galeria (14 nov 2026, decision del dueno): el 80 % de lo que pagan
-- los anuncios vistos en los juegos de un creador va a ese creador y el 20 % se queda en Orquestador
-- (antes 50/50). En Google Play el creador se queda el 100 % (sus anuncios de AdMob y sus ventas).
update public.settings
   set value = 80,
       note = 'Parte (%) de lo que pagan los anuncios de la galeria que va a los creadores (80 creador / 20 Orquestador)'
 where key = 'galeria_reparto_pct';

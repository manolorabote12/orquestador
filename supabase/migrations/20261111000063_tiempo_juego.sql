-- Un juego con arte de verdad tarda 22-28 min (11 nov: 51-68 imagenes). Con el corte en 30 min se
-- perdia un juego casi terminado (y su gasto). 45 min da margen; el guardian y el vigilante siguen
-- vigilando el gasto por hora.
update public.settings set value = 45 where key = 'game_timeout_minutes' and value < 45;

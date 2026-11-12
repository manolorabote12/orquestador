-- El diseno (tambien el de la vista previa gratis) lo hace ahora el modelo superior: es lo que decide
-- el genero, el mundo y los personajes del juego. Cuesta ~0,03-0,07 $ en vez de ~0,01 $, asi que las
-- vistas previas gratis bajan de 15 a 6 al dia por persona (nadie usa mas; frena el abuso).
update public.pricing set max_per_day = 6, est_cost_usd = 0.0700 where kind = 'game_preview';

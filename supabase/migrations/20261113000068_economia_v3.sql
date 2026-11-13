-- Economia v3 (13 nov 2026): margen del 50-60 % en todo lo que se vende y ninguna venta a perdidas.
--
-- Coste real medido (13 nov): ~0,55 EUR por juego con fallos incluidos (directora creativa, diseno
-- largo, critica visual y campana larga). Con 80 tuercas por juego y 3.600 tuercas por 29,99 EUR, el
-- pack grande daba 0,47 EUR netos por juego: se perdia dinero.
--
-- Lo que deja cada juego (120 tuercas), quitando IVA (21 %) y la comision de Google (15 %):
--   Pack pequeno  2,99 EUR ->   180 tuercas  -> 1,40 EUR por juego  -> margen ~61 %
--   Pack mediano  9,99 EUR ->   660 tuercas  -> 1,28 EUR            -> ~57 %
--   Pack grande  29,99 EUR -> 2.000 tuercas  -> 1,26 EUR            -> ~56 %
--   Plan Taller   4,99 EUR/mes ->   300/mes  -> 1,40 EUR            -> ~61 %  (anual 54,99 EUR: ~57 %)
--   Plan Pro     12,99 EUR/mes -> 1.000/mes  -> 1,10 EUR            -> ~50 %  (anual 139,99 EUR: ~45 %)
--   Pro + pack grande (+10 %)  -> 2.200      -> 1,15 EUR            -> ~52 %
-- (Los precios en euros se ponen en Play Console; aqui van las tuercas que da cada producto.)
--
-- Lo unico que se regala a perdidas, a proposito: el juego de bienvenida (una vez por correo real) y
-- las invitaciones (se pagan cuando el invitado compra). Los anuncios con premio quedan a la par:
-- Google paga ~0,009 EUR y 2 tuercas valen ~0,009 EUR.

update public.pricing set credits = 120, est_cost_usd = 0.60 where kind = 'game';
-- Video, programa y volver a una version: al menos el doble de su coste con la tuerca mas barata.
update public.pricing set credits = 40 where kind = 'game_marketing';
update public.pricing set credits = 60 where kind = 'game_mod';
update public.pricing set credits = 8 where kind = 'game_restore';

update public.store_products set credits = 180, note = 'Pack pequeno: 180 tuercas (Play Console: 2,99 EUR)' where product_id = 'tuercas_300';
update public.store_products set credits = 660, note = 'Pack mediano: 660 tuercas (9,99 EUR)' where product_id = 'tuercas_1100';
update public.store_products set credits = 2000, note = 'Pack grande: 2.000 tuercas (29,99 EUR)' where product_id = 'tuercas_3600';
update public.store_products set tuercas_mes = 300,
  note = 'Suscripcion Taller: 300 tuercas al mes (4,99 EUR/mes o 54,99 EUR/ano)' where product_id = 'plan_taller';
update public.store_products set tuercas_mes = 1000,
  note = 'Suscripcion Taller Pro: 1.000 tuercas al mes y +10 % en packs (12,99 EUR/mes o 139,99 EUR/ano)' where product_id = 'plan_pro';

update public.settings set value = 120, note = 'Tuercas al verificar la cuenta: el juego de prueba (una vez por correo real)'
 where key = 'welcome_credits';
update public.settings set value = 2, note = 'Tuercas por anuncio bonificado (Google paga ~0,009 EUR; 2 tuercas valen ~0,009 EUR)'
 where key = 'reward_ad_credits';
update public.settings set value = 10, note = 'Taller Pro: % extra de tuercas en cada pack comprado'
 where key = 'plan_pro_bonus_packs';
update public.settings set value = 0.0082, note = 'Valor neto de 1 tuerca en el caso mas barato (Pro anual: 139,99 EUR / 12.000, sin IVA ni comision)'
 where key = 'credit_value_eur';

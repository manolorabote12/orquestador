-- Reparto de la galeria (14 nov 2026, decision del dueno): 60 % para el creador y 40 % para
-- Orquestador, sobre lo que pagan los anuncios del mes (los costes de servir los juegos los cubre
-- la parte de Orquestador; galeria_reparto sigue aceptando costes por si un mes salen disparados).
-- Compras dentro de los juegos en la web: comision de Orquestador del 10 % (sin contar lo que se
-- quede la pasarela de pago). En Google Play todo es del creador (cobra el en su consola).
update public.settings set value = 60 where key = 'galeria_reparto_pct';

insert into public.settings (key, value, note)
values ('web_compras_comision_pct', 10, 'Comision (%) de Orquestador en las compras dentro de los juegos jugados en la web')
on conflict (key) do update set value = excluded.value, note = excluded.note;

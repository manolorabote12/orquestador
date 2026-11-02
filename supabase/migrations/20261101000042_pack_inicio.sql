-- Pack de inicio (kit/store.gd): 2000 monedas + sin anuncios, una vez, 3,99 euros.
create or replace function public.iap_precio(p_producto text)
returns numeric
language sql
immutable
as $$
  select case p_producto when 'monedas_500' then 0.99 when 'monedas_3000' then 4.99
    when 'pase_temporada' then 3.99 when 'sin_anuncios' then 2.99 when 'pack_inicio' then 3.99 else 0 end::numeric;
$$;

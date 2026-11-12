-- Experimentos de la fabrica (migracion 067).
do $$
declare
  n int;
  h jsonb;
begin
  perform public.experimento_anotar('plataformas', '{"zoom": 1.15, "sprite": 1.0}'::jsonb, 7, array['fondo_vacio']);
  perform public.experimento_anotar('plataformas', '{"zoom": 1.0}'::jsonb, 12, null);
  perform public.experimento_anotar('runner', '{"zoom": 0.9}'::jsonb, 0, array['a','b','c','d','e','f','g']);
  select count(*) into n from public.experimentos_historial('plataformas');
  assert n = 2, 'historial del genero: ' || n;
  select x into h from public.experimentos_historial('plataformas') x offset 1 limit 1;
  assert (h->>'nota')::int = 10, 'nota acotada a 10';
  select x into h from public.experimentos_historial('runner') x limit 1;
  assert (h->>'nota')::int = 1 and jsonb_array_length(h->'problemas') = 6, 'nota minima 1 y como mucho 6 problemas';
  raise notice 'experimentos OK';
end;
$$;

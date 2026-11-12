-- Reloj de la base (migracion 066): tareas de la base y llamada a la funcion "reloj".
do $$
declare
  v jsonb;
begin
  v := public.reloj_bd();
  assert v ? 'lanzadera' and v ? 'reto' and v ? 'colgados', 'reloj_bd hace las tres tareas: ' || v::text;
  assert public.reloj_llamar(true) = false, 'sin direccion del proyecto no llama';
  assert public.reloj_configurar('http://malo') = false, 'solo direcciones https';
  assert public.reloj_configurar('https://x.supabase.co/') = true, 'guarda la direccion';
  assert (select url from public.reloj_privado) = 'https://x.supabase.co', 'sin barra final';
  assert length((select clave from public.reloj_privado)) = 64, 'clave aleatoria de 64';
  -- Sin cola y fuera de las 6 horas no hace ninguna llamada (no hace falta pg_net).
  delete from public.jobs where status = 'queued';
  assert public.reloj_llamar(false) = false, 'sin cola no llama';
  raise notice 'reloj OK';
end;
$$;

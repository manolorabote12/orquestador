-- Progreso en vivo: la app escucha los cambios de SU trabajo (la seguridad por filas sigue
-- mandando: cada usuario solo recibe sus propias filas). Si no hay tiempo real, la app
-- consulta cada 4 segundos, así que esto acelera pero no es imprescindible.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.jobs;
  end if;
exception when duplicate_object then null;
end;
$$;

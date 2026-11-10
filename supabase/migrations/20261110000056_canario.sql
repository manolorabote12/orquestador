-- Juego de prueba automatico cada semana (el "canario", 10 de noviembre de 2026).
--
-- Lunes de madrugada el workflow «Canario» encarga un juego pequeno (10 dibujos, sin fondos, sin ficha
-- ni clip) con una cuenta propia (canario@orquestador.invalid, sin correo real). Una hora despues
-- mira si salio bien y cuanto costo, avisa por correo si no, y borra todo lo que creo.
-- Si algo se rompe (Godot, RunPod, Supabase, Claude) te enteras tu antes que un cliente. ~0,10 $/semana.

create or replace function public.canario_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from auth.users where lower(email) = 'canario@orquestador.invalid' limit 1
$$;

create or replace function public.canario_encargar(p_idea text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := public.canario_id();
  v_job uuid;
begin
  if v_user is null then raise exception 'sin_canario'; end if;
  -- Sin cobro ni limites: es nuestro. La parada de emergencia (fabrica_pausada) si le aplica.
  insert into public.jobs (user_id, kind, cost, est_cost_usd, status, detail)
  values (v_user, 'game', 0, 0.15, 'queued', jsonb_build_object('idea', p_idea, 'canario', true))
  returning id into v_job;
  return v_job;
end;
$$;

-- Lo ultimo que encargo el canario, con lo que hace falta para juzgarlo.
create or replace function public.canario_estado()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select to_jsonb(x) from (
    select j.id, j.status, j.error, j.provider_cost_usd, j.created_at, j.started_at, j.finished_at,
           extract(epoch from (j.finished_at - j.started_at))::int as segundos,
           (select jsonb_agg(e) from jsonb_array_elements(j.progress) e
             where e ->> 'paso' in ('arte', 'validacion', 'prueba_bots', 'apk', 'web', 'subida', 'fin') and e ->> 'estado' in ('ok', 'aviso')) as pasos
      from public.jobs j
     where j.user_id = public.canario_id() and j.kind = 'game'
     order by j.created_at desc limit 1
  ) x
$$;

-- Limpieza: borra los proyectos del canario y devuelve las rutas de sus archivos para borrarlos del almacen.
create or replace function public.canario_limpiar()
returns text[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := public.canario_id();
  v_rutas text[];
begin
  if v_user is null then return '{}'; end if;
  select coalesce(array_agg(name), '{}') into v_rutas from storage.objects
   where bucket_id = 'juegos' and name like v_user::text || '/%';
  delete from public.projects where user_id = v_user;
  return v_rutas;
end;
$$;

revoke all on function public.canario_id() from public, anon, authenticated;
revoke all on function public.canario_encargar(text) from public, anon, authenticated;
revoke all on function public.canario_estado() from public, anon, authenticated;
revoke all on function public.canario_limpiar() from public, anon, authenticated;
grant execute on function public.canario_id() to service_role;
grant execute on function public.canario_encargar(text) to service_role;
grant execute on function public.canario_estado() to service_role;
grant execute on function public.canario_limpiar() to service_role;

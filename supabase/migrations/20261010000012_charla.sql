-- Charla en directo con los personajes del juego (el heroe, el rival y el jefe responden con la IA).
--   autor (su sesion) -> charla_activar: paga un paquete de mensajes con tuercas (precio en pricing).
--                     -> charla_estado: mensajes que le quedan y si esta activa; charla_pausar.
--   servidor (funcion "charla", con la clave de servicio) -> charla_reservar: comprueba cupo del
--                     juego y limite del dispositivo, descuenta un mensaje y devuelve el diseno
--                     (de ahi salen los personajes: nunca del jugador). charla_coste guarda lo gastado.
-- Del jugador solo se guarda el numero aleatorio de su dispositivo (como en la clasificacion).

insert into public.pricing (kind, label, credits, max_per_day, est_cost_usd, enabled) values
  ('charla_pack', 'Charla con personajes (500 mensajes)', 40, 5, 0.600, true)
on conflict (kind) do nothing;

insert into public.settings (key, value, note) values
  ('charla_mensajes_pack', 500, 'Mensajes que trae cada paquete de charla'),
  ('charla_por_sesion_dia', 30, 'Mensajes que un dispositivo puede mandar al dia en un juego')
on conflict (key) do nothing;

create table if not exists public.charla_cupos (
  project_id uuid primary key references public.projects (id) on delete cascade,
  mensajes   integer not null default 0 check (mensajes >= 0),
  activa     boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.charla_cupos enable row level security;

create table if not exists public.charla_envios (
  id         bigserial primary key,
  project_id uuid not null references public.projects (id) on delete cascade,
  sesion     text not null,
  cost_usd   numeric(10, 6),
  created_at timestamptz not null default now()
);
create index if not exists charla_envios_idx on public.charla_envios (project_id, sesion, created_at);
alter table public.charla_envios enable row level security;
-- Sin politicas: solo por las funciones de abajo.

create or replace function public.charla_activar(p_project uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_job  uuid;
  v_left integer;
  v_cost integer;
  v_n    integer;
begin
  if v_user is null then raise exception 'unauthorized'; end if;
  if not exists (select 1 from public.projects where id = p_project and user_id = v_user) then
    raise exception 'project_not_found';
  end if;
  select r.job_id, r.credits_left, r.cost into v_job, v_left, v_cost
    from public.reserve_job(v_user, 'charla_pack', jsonb_build_object('project', p_project)) r;
  perform public.finish_job(v_job, (select est_cost_usd from public.pricing where kind = 'charla_pack'));
  insert into public.charla_cupos (project_id, mensajes, activa)
  values (p_project, public.setting('charla_mensajes_pack')::integer, true)
  on conflict (project_id) do update
    set mensajes = charla_cupos.mensajes + public.setting('charla_mensajes_pack')::integer, activa = true, updated_at = now()
  returning mensajes into v_n;
  return jsonb_build_object('mensajes', v_n, 'tuercas', v_left, 'coste', v_cost);
end;
$$;

create or replace function public.charla_estado(p_project uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  c record;
  v_hoy integer;
begin
  if auth.uid() is null or not exists (select 1 from public.projects where id = p_project and user_id = auth.uid()) then
    raise exception 'project_not_found';
  end if;
  select * into c from public.charla_cupos where project_id = p_project;
  select count(*) into v_hoy from public.charla_envios where project_id = p_project and created_at > now() - interval '1 day';
  return jsonb_build_object('mensajes', coalesce(c.mensajes, 0), 'activa', coalesce(c.activa, false), 'hoy', v_hoy,
    'precio', (select credits from public.pricing where kind = 'charla_pack'),
    'por_paquete', public.setting('charla_mensajes_pack'));
end;
$$;

create or replace function public.charla_pausar(p_project uuid, p_activa boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.charla_cupos c set activa = p_activa, updated_at = now()
   from public.projects p
   where c.project_id = p_project and p.id = p_project and p.user_id = auth.uid();
  if not found then raise exception 'project_not_found'; end if;
end;
$$;

-- El juego pregunta si ensenar el boton de charla (sin datos de nadie: solo si/no).
create or replace function public.charla_activa(p_juego uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.charla_cupos c join public.projects p on p.id = c.project_id
                  where p.telemetria_id = p_juego and c.activa and c.mensajes > 0);
$$;

-- Solo la funcion del servidor. Devuelve el diseno del juego y el id del envio (para apuntar el coste).
create or replace function public.charla_reservar(p_juego uuid, p_sesion text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_project uuid;
  v_spec    jsonb;
  v_title   text;
  v_envio   bigint;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  select id, spec, title into v_project, v_spec, v_title from public.projects where telemetria_id = p_juego;
  if not found then raise exception 'unknown_game'; end if;
  -- Bloquea el cupo para que dos mensajes a la vez no gasten el mismo.
  perform 1 from public.charla_cupos where project_id = v_project and activa and mensajes > 0 for update;
  if not found then raise exception 'no_quota'; end if;
  if (select count(*) from public.charla_envios where project_id = v_project and sesion = p_sesion
        and created_at > now() - interval '1 day') >= public.setting('charla_por_sesion_dia') then
    raise exception 'rate_limited';
  end if;
  update public.charla_cupos set mensajes = mensajes - 1, updated_at = now() where project_id = v_project;
  insert into public.charla_envios (project_id, sesion) values (v_project, p_sesion) returning id into v_envio;
  return jsonb_build_object('spec', v_spec, 'title', v_title, 'envio', v_envio);
end;
$$;

-- Si la IA falla, el mensaje se devuelve al cupo.
create or replace function public.charla_coste(p_envio bigint, p_cost_usd numeric, p_ok boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_project uuid;
begin
  update public.charla_envios set cost_usd = p_cost_usd where id = p_envio returning project_id into v_project;
  if not p_ok and v_project is not null then
    update public.charla_cupos set mensajes = mensajes + 1 where project_id = v_project;
  end if;
end;
$$;

revoke all on function public.charla_activar(uuid) from public, anon;
revoke all on function public.charla_estado(uuid) from public, anon;
revoke all on function public.charla_pausar(uuid, boolean) from public, anon;
grant execute on function public.charla_activar(uuid) to authenticated;
grant execute on function public.charla_activa(uuid) to anon, authenticated;
grant execute on function public.charla_estado(uuid) to authenticated;
grant execute on function public.charla_pausar(uuid, boolean) to authenticated;
revoke all on function public.charla_reservar(uuid, text) from public, anon, authenticated;
revoke all on function public.charla_coste(bigint, numeric, boolean) from public, anon, authenticated;
grant execute on function public.charla_reservar(uuid, text) to service_role;
grant execute on function public.charla_coste(bigint, numeric, boolean) to service_role;

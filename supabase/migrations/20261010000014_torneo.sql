-- Torneo semanal de cada juego: un nivel destacado por semana con su propia clasificacion.
--   juego (anon) -> torneo_info: semana, nivel destacado, segundos que quedan, tu mejor marca y,
--                   si quedaste en el podio la semana pasada, tu premio sin cobrar.
--                -> torneo_enviar: tu marca de esta semana (solo cuenta la mejor).
--                -> torneo_top: los mejores de la semana (y tu puesto).
--                -> torneo_reclamar: cobra el premio del podio (una vez).
-- El nivel de la semana sale de un numero fijo del juego y la semana: igual para todos, sin guardarlo.

create table if not exists public.torneo_marcas (
  id         bigserial primary key,
  juego      uuid not null,
  semana     text not null,
  sesion     text not null,
  alias      text not null,
  puntos     integer not null check (puntos > 0),
  reclamado  boolean not null default false,
  oculta     boolean not null default false,
  updated_at timestamptz not null default now(),
  unique (juego, semana, sesion)
);
create index if not exists torneo_top_idx on public.torneo_marcas (juego, semana, puntos desc) where not oculta;
alter table public.torneo_marcas enable row level security;

create table if not exists public.torneo_envios (
  sesion     text not null,
  created_at timestamptz not null default now()
);
create index if not exists torneo_envios_idx on public.torneo_envios (sesion, created_at);
alter table public.torneo_envios enable row level security;

insert into public.settings (key, value, note) values
  ('torneo_envios_hora', 40, 'Marcas de torneo que un dispositivo puede enviar por hora')
on conflict (key) do nothing;

create or replace function public.torneo_semana(p_cuando timestamptz default now())
returns text
language sql
stable
as $$ select to_char(p_cuando at time zone 'UTC', 'IYYY-"S"IW'); $$;

-- Nivel destacado: 0..niveles-1, distinto cada semana.
create or replace function public._torneo_nivel(p_juego uuid, p_semana text)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select (abs(hashtext(p_juego::text || p_semana)) % greatest(coalesce(jsonb_array_length(
           case when jsonb_typeof(spec -> 'niveles') = 'array' then spec -> 'niveles' end), 1), 1))::integer
    from public.projects where telemetria_id = p_juego;
$$;

create or replace function public.torneo_info(p_juego uuid, p_sesion text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_semana text := public.torneo_semana();
  v_pasada text := public.torneo_semana(now() - interval '7 days');
  v_nivel integer;
  v_mejor integer;
  v_puesto integer;
  v_fin timestamptz := date_trunc('week', now() at time zone 'UTC') at time zone 'UTC' + interval '7 days';
begin
  v_nivel := public._torneo_nivel(p_juego, v_semana);
  if v_nivel is null then raise exception 'unknown_game'; end if;
  select puntos into v_mejor from public.torneo_marcas where juego = p_juego and semana = v_semana and sesion = p_sesion;
  -- Podio de la semana pasada sin cobrar.
  select r.posicion into v_puesto from (
    select m.sesion, m.reclamado, (rank() over (order by m.puntos desc))::integer as posicion
      from public.torneo_marcas m where m.juego = p_juego and m.semana = v_pasada and not m.oculta) r
   where r.sesion = p_sesion and r.posicion <= 3 and not r.reclamado;
  return jsonb_build_object('semana', v_semana, 'nivel', v_nivel, 'segundos', greatest(extract(epoch from v_fin - now())::integer, 0),
    'mejor', coalesce(v_mejor, 0), 'premio', case v_puesto when 1 then 300 when 2 then 200 when 3 then 100 else 0 end,
    'puesto_pasado', coalesce(v_puesto, 0));
end;
$$;

create or replace function public.torneo_enviar(p_juego uuid, p_sesion text, p_alias text, p_puntos integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_semana text := public.torneo_semana();
  v_mejor integer;
  v_pos integer;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  if not public.alias_valido(p_alias) then raise exception 'bad_alias'; end if;
  if p_puntos is null or p_puntos < 1 or p_puntos > public.setting('marcador_max_puntos') then raise exception 'bad_score'; end if;
  if public._torneo_nivel(p_juego, v_semana) is null then raise exception 'unknown_game'; end if;
  if (select count(*) from public.torneo_envios where sesion = p_sesion and created_at > now() - interval '1 hour')
     >= public.setting('torneo_envios_hora') then
    raise exception 'rate_limited';
  end if;
  insert into public.torneo_envios (sesion) values (p_sesion);
  insert into public.torneo_marcas (juego, semana, sesion, alias, puntos)
  values (p_juego, v_semana, p_sesion, p_alias, p_puntos)
  on conflict (juego, semana, sesion) do update
    set puntos = greatest(torneo_marcas.puntos, excluded.puntos), alias = excluded.alias, updated_at = now()
  returning puntos into v_mejor;
  select count(*) + 1 into v_pos from public.torneo_marcas
   where juego = p_juego and semana = v_semana and not oculta and puntos > v_mejor;
  return jsonb_build_object('mejor', v_mejor, 'posicion', v_pos);
end;
$$;

create or replace function public.torneo_top(p_juego uuid, p_sesion text, p_limite integer default 10)
returns table (posicion integer, alias text, puntos integer, tuyo boolean)
language sql
stable
security definer
set search_path = public
as $$
  with r as (
    select m.alias, m.puntos, m.sesion = p_sesion as tuyo, (rank() over (order by m.puntos desc))::integer as posicion
      from public.torneo_marcas m
     where m.juego = p_juego and m.semana = public.torneo_semana() and not m.oculta
  )
  select posicion, alias, puntos, tuyo from r
   where posicion <= least(greatest(p_limite, 1), 50) or tuyo
   order by posicion limit 51;
$$;

create or replace function public.torneo_reclamar(p_juego uuid, p_sesion text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_info jsonb := public.torneo_info(p_juego, p_sesion);
  v_premio integer := (v_info ->> 'premio')::integer;
begin
  if v_premio <= 0 then return 0; end if;
  update public.torneo_marcas set reclamado = true
   where juego = p_juego and semana = public.torneo_semana(now() - interval '7 days') and sesion = p_sesion;
  return v_premio;
end;
$$;

-- Borrar el juego borra sus torneos.
create or replace function public._torneo_borrar_juego()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.torneo_marcas where juego = old.telemetria_id;
  return old;
end;
$$;
drop trigger if exists torneo_borrar_juego on public.projects;
create trigger torneo_borrar_juego after delete on public.projects for each row execute function public._torneo_borrar_juego();

revoke all on function public._torneo_nivel(uuid, text) from public, anon, authenticated;
revoke all on function public._torneo_borrar_juego() from public, anon, authenticated;
grant execute on function public.torneo_info(uuid, text) to anon, authenticated;
grant execute on function public.torneo_enviar(uuid, text, text, integer) to anon, authenticated;
grant execute on function public.torneo_top(uuid, text, integer) to anon, authenticated;
grant execute on function public.torneo_reclamar(uuid, text) to anon, authenticated;

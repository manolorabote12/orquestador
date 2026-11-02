-- Clasificacion online por nivel y retos entre amigos.
--   juego (anon)        -> marcador_enviar: valida apodo y marca, limita y guarda la mejor por dispositivo.
--                       -> marcador_top: los mejores del nivel y tu puesto (aunque no estes entre ellos).
--   autor (su sesion)   -> marcador_autor / marcador_ocultar: ve la clasificacion y oculta apodos feos.
-- El juego se identifica con projects.telemetria_id (el mismo que los datos de partida). Del
-- jugador solo se guarda el apodo que el elige y un numero aleatorio del dispositivo.

create table if not exists public.marcadores (
  id         bigserial primary key,
  juego      uuid not null,
  nivel      integer not null check (nivel between 0 and 99),
  sesion     text not null,
  alias      text not null,
  puntos     integer not null check (puntos > 0),
  oculta     boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (juego, nivel, sesion)
);
create index if not exists marcadores_top_idx on public.marcadores (juego, nivel, puntos desc) where not oculta;
alter table public.marcadores enable row level security;
-- Sin politicas: solo por las funciones de abajo.

create table if not exists public.marcador_envios (
  sesion     text not null,
  created_at timestamptz not null default now()
);
create index if not exists marcador_envios_idx on public.marcador_envios (sesion, created_at);
alter table public.marcador_envios enable row level security;

insert into public.settings (key, value, note) values
  ('marcadores_por_sesion_hora', 60, 'Marcas que un dispositivo puede enviar por hora'),
  ('marcador_max_puntos', 10000000, 'Puntos maximos creibles en un nivel')
on conflict (key) do nothing;

-- Apodo: 3 a 14 letras, numeros, espacio, punto, guion o guion bajo; sin palabrotas (tambien
-- escritas con numeros: p0ll4) ni nombres que se hagan pasar por la app.
create or replace function public.alias_valido(p_alias text)
returns boolean
language plpgsql
immutable
as $$
declare
  t text;
  w text;
begin
  if p_alias is null or char_length(p_alias) < 3 or char_length(p_alias) > 14 then return false; end if;
  if p_alias !~ '^[[:alnum:]áéíóúüñÁÉÍÓÚÜÑçÇ _.-]+$' then return false; end if;
  t := translate(lower(p_alias), '01345 _.-', 'oieas');
  foreach w in array array['puta', 'puto', 'mierda', 'polla', 'coño', 'cabron', 'maricon', 'nazi', 'hitler',
    'fuck', 'shit', 'bitch', 'nigger', 'nigga', 'cunt', 'admin', 'orquestador'] loop
    if position(w in t) > 0 then return false; end if;
  end loop;
  return true;
end;
$$;

create or replace function public.marcador_enviar(p_juego uuid, p_nivel integer, p_sesion text, p_alias text, p_puntos integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_niveles integer;
  v_mejor   integer;
  v_pos     integer;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  if not public.alias_valido(p_alias) then raise exception 'bad_alias'; end if;
  if p_puntos is null or p_puntos < 1 or p_puntos > public.setting('marcador_max_puntos') then raise exception 'bad_score'; end if;
  select coalesce(jsonb_array_length(case when jsonb_typeof(spec -> 'niveles') = 'array' then spec -> 'niveles' end), 100)
    into v_niveles from public.projects where telemetria_id = p_juego;
  if not found then raise exception 'unknown_game'; end if;
  if p_nivel is null or p_nivel < 0 or p_nivel >= least(v_niveles, 100) then raise exception 'bad_level'; end if;
  if (select count(*) from public.marcador_envios where sesion = p_sesion and created_at > now() - interval '1 hour')
     >= public.setting('marcadores_por_sesion_hora') then
    raise exception 'rate_limited';
  end if;
  insert into public.marcador_envios (sesion) values (p_sesion);
  delete from public.marcador_envios where created_at < now() - interval '1 day' and random() < 0.01;
  insert into public.marcadores (juego, nivel, sesion, alias, puntos)
  values (p_juego, p_nivel, p_sesion, p_alias, p_puntos)
  on conflict (juego, nivel, sesion) do update
    set puntos = greatest(public.marcadores.puntos, excluded.puntos),
        alias = excluded.alias,
        updated_at = case when excluded.puntos > public.marcadores.puntos then now() else public.marcadores.updated_at end
  returning puntos into v_mejor;
  select 1 + count(*) into v_pos from public.marcadores
    where juego = p_juego and nivel = p_nivel and not oculta and puntos > v_mejor;
  return jsonb_build_object('posicion', v_pos, 'mejor', v_mejor);
end;
$$;

-- Los mejores de un nivel y, si no estas entre ellos, tu fila al final (tuyo = true).
create or replace function public.marcador_top(p_juego uuid, p_nivel integer, p_sesion text default null, p_limite integer default 10)
returns table (posicion integer, alias text, puntos integer, tuyo boolean)
language sql
stable
security definer
set search_path = public
as $$
  with r as (
    select (rank() over (order by m.puntos desc))::integer as posicion, m.alias, m.puntos,
      coalesce(m.sesion = p_sesion, false) as tuyo,
      row_number() over (order by m.puntos desc, m.updated_at asc) as fila
    from public.marcadores m
    where m.juego = p_juego and m.nivel = p_nivel and not m.oculta
  )
  select posicion, alias, puntos, tuyo from r
  where fila <= greatest(1, least(coalesce(p_limite, 10), 50)) or tuyo
  order by fila;
$$;

-- Autor: la clasificacion completa de un nivel de su juego, con las filas ocultas.
create or replace function public.marcador_autor(p_project uuid, p_nivel integer)
returns table (id bigint, posicion integer, alias text, puntos integer, oculta boolean)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_juego uuid;
begin
  select pr.telemetria_id into v_juego from public.projects pr where pr.id = p_project and pr.user_id = auth.uid();
  if v_juego is null then raise exception 'project_not_found'; end if;
  return query
    select m.id, (rank() over (order by m.puntos desc))::integer, m.alias, m.puntos, m.oculta
    from public.marcadores m where m.juego = v_juego and m.nivel = p_nivel
    order by m.puntos desc limit 100;
end;
$$;

create or replace function public.marcador_ocultar(p_id bigint, p_oculta boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.marcadores m set oculta = coalesce(p_oculta, true)
  from public.projects p
  where m.id = p_id and p.telemetria_id = m.juego and p.user_id = auth.uid();
  if not found then raise exception 'not_found'; end if;
end;
$$;

revoke all on function public.marcador_enviar(uuid, integer, text, text, integer) from public;
revoke all on function public.marcador_top(uuid, integer, text, integer) from public;
revoke all on function public.marcador_autor(uuid, integer) from public;
revoke all on function public.marcador_ocultar(bigint, boolean) from public;
grant execute on function public.marcador_enviar(uuid, integer, text, text, integer) to anon, authenticated;
grant execute on function public.marcador_top(uuid, integer, text, integer) to anon, authenticated;
grant execute on function public.marcador_autor(uuid, integer) to authenticated;
grant execute on function public.marcador_ocultar(bigint, boolean) to authenticated;

-- Al borrar un juego (o la cuenta) su clasificacion desaparece con el.
create or replace function public.marcadores_al_borrar_juego()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.marcadores where juego = old.telemetria_id;
  return old;
end;
$$;
drop trigger if exists marcadores_borrar_juego on public.projects;
create trigger marcadores_borrar_juego after delete on public.projects
  for each row execute function public.marcadores_al_borrar_juego();

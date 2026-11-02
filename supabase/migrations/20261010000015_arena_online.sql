-- Arena en directo (juegos del genero arena): partidas de hasta 4 jugadores en tiempo real.
--   juego (anon) -> arena_buscar: entra en una sala abierta (o crea una) y te da tu puesto de salida.
--                -> arena_estado: quien hay y cuanto falta; a los 12 s (o con 4) empieza y lo que
--                   falte se rellena con bots. Mismo nivel y semilla para todos.
--                -> arena_resultado: tu puesto final (una vez) -> trofeos de la arena.
--                -> arena_top: ranking de trofeos del juego.
-- La partida va por el canal en directo de Supabase ("arena-<sala>"); aqui solo se empareja y se
-- apuntan resultados. Del jugador solo se guarda su apodo y el numero aleatorio del dispositivo.

create table if not exists public.arena_perfiles (
  juego      uuid not null,
  sesion     text not null,
  alias      text not null,
  trofeos    integer not null default 0 check (trofeos >= 0),
  partidas   integer not null default 0,
  victorias  integer not null default 0,
  oculta     boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (juego, sesion)
);
create index if not exists arena_perfiles_top_idx on public.arena_perfiles (juego, trofeos desc) where not oculta;
alter table public.arena_perfiles enable row level security;

create table if not exists public.arena_salas (
  id         uuid primary key default gen_random_uuid(),
  juego      uuid not null,
  nivel      integer not null default 0,
  semilla    integer not null default 0,
  created_at timestamptz not null default now(),
  inicio     timestamptz
);
create index if not exists arena_salas_abiertas_idx on public.arena_salas (juego, created_at) where inicio is null;
alter table public.arena_salas enable row level security;

create table if not exists public.arena_jugadores (
  sala       uuid not null references public.arena_salas (id) on delete cascade,
  sesion     text not null,
  alias      text not null,
  slot       integer not null check (slot between 0 and 3),
  puesto     integer check (puesto between 1 and 4),
  delta      integer,
  primary key (sala, sesion),
  unique (sala, slot)
);
alter table public.arena_jugadores enable row level security;
-- Sin politicas: solo por las funciones de abajo.

insert into public.settings (key, value, note) values
  ('arena_espera_s', 12, 'Segundos que espera una sala de arena antes de empezar con bots'),
  ('arena_partidas_hora', 40, 'Partidas de arena que un dispositivo puede empezar por hora')
on conflict (key) do nothing;

create or replace function public._arena_niveles(p_juego uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select case when coalesce(spec ->> 'genero', '') = 'arena'
    then greatest(coalesce(jsonb_array_length(case when jsonb_typeof(spec -> 'niveles') = 'array' then spec -> 'niveles' end), 1), 1)
    end
  from public.projects where telemetria_id = p_juego;
$$;

create or replace function public.arena_buscar(p_juego uuid, p_sesion text, p_alias text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_niveles integer;
  v_sala uuid;
  v_slot integer;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  if not public.alias_valido(p_alias) then raise exception 'bad_alias'; end if;
  v_niveles := public._arena_niveles(p_juego);
  if v_niveles is null then raise exception 'unknown_game'; end if;
  if (select count(*) from public.arena_jugadores j join public.arena_salas s on s.id = j.sala
       where j.sesion = p_sesion and s.created_at > now() - interval '1 hour') >= public.setting('arena_partidas_hora') then
    raise exception 'rate_limited';
  end if;
  insert into public.arena_perfiles (juego, sesion, alias) values (p_juego, p_sesion, p_alias)
  on conflict (juego, sesion) do update set alias = excluded.alias, updated_at = now();
  -- Sala abierta con sitio (la mas antigua); se bloquea para no repetir puesto.
  select s.id into v_sala from public.arena_salas s
   where s.juego = p_juego and s.inicio is null
     and s.created_at > now() - make_interval(secs => public.setting('arena_espera_s'))
     and (select count(*) from public.arena_jugadores j where j.sala = s.id) < 4
   order by s.created_at limit 1 for update skip locked;
  if v_sala is null then
    insert into public.arena_salas (juego, nivel, semilla)
    values (p_juego, floor(random() * v_niveles)::integer, floor(random() * 1000000)::integer) returning id into v_sala;
  end if;
  select slot into v_slot from public.arena_jugadores where sala = v_sala and sesion = p_sesion;
  if v_slot is null then
    select min(s) into v_slot from generate_series(0, 3) s
     where s not in (select slot from public.arena_jugadores where sala = v_sala);
    if v_slot is null then raise exception 'room_full'; end if;
    insert into public.arena_jugadores (sala, sesion, alias, slot) values (v_sala, p_sesion, p_alias, v_slot);
  end if;
  return jsonb_build_object('sala', v_sala, 'slot', v_slot);
end;
$$;

create or replace function public.arena_estado(p_sala uuid, p_sesion text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.arena_salas%rowtype;
  v_n integer;
  v_en numeric;
begin
  select * into s from public.arena_salas where id = p_sala for update;
  if not found then raise exception 'unknown_room'; end if;
  if not exists (select 1 from public.arena_jugadores where sala = p_sala and sesion = p_sesion) then raise exception 'not_in_room'; end if;
  select count(*) into v_n from public.arena_jugadores where sala = p_sala;
  -- Empieza a los N segundos de crearse o en cuanto hay 4 (con 3 s de cuenta atras para todos).
  if s.inicio is null and (v_n >= 4 or s.created_at <= now() - make_interval(secs => public.setting('arena_espera_s'))) then
    update public.arena_salas set inicio = now() + interval '3 seconds' where id = p_sala returning * into s;
  end if;
  v_en := case when s.inicio is null
    then extract(epoch from s.created_at + make_interval(secs => public.setting('arena_espera_s')) - now()) + 3
    else extract(epoch from s.inicio - now()) end;
  return jsonb_build_object('sala', s.id, 'nivel', s.nivel, 'semilla', s.semilla, 'empezada', s.inicio is not null,
    'en', round(greatest(v_en, 0), 2),
    'jugadores', (select coalesce(jsonb_agg(jsonb_build_object('sesion', j.sesion, 'alias', j.alias, 'slot', j.slot) order by j.slot), '[]'::jsonb)
                    from public.arena_jugadores j where j.sala = p_sala));
end;
$$;

-- Trofeos por puesto: 1.o +12, 2.o +5, 3.o -2, 4.o -6 (nunca por debajo de 0).
create or replace function public.arena_resultado(p_sala uuid, p_sesion text, p_puesto integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.arena_salas%rowtype;
  j public.arena_jugadores%rowtype;
  v_delta integer;
  v_trofeos integer;
begin
  select * into s from public.arena_salas where id = p_sala;
  if not found then raise exception 'unknown_room'; end if;
  select * into j from public.arena_jugadores where sala = p_sala and sesion = p_sesion for update;
  if not found then raise exception 'not_in_room'; end if;
  if s.inicio is null or s.inicio > now() then raise exception 'not_started'; end if;
  if s.inicio < now() - interval '30 minutes' then raise exception 'expired'; end if;
  if j.puesto is not null then raise exception 'already_closed'; end if;
  if p_puesto is null or p_puesto < 1 or p_puesto > 4 then raise exception 'bad_result'; end if;
  -- Dos jugadores no pueden decir que han quedado primeros.
  if p_puesto = 1 and exists (select 1 from public.arena_jugadores where sala = p_sala and puesto = 1) then
    raise exception 'bad_result';
  end if;
  v_delta := case p_puesto when 1 then 12 when 2 then 5 when 3 then -2 else -6 end;
  update public.arena_jugadores set puesto = p_puesto, delta = v_delta where sala = p_sala and sesion = p_sesion;
  update public.arena_perfiles set trofeos = greatest(trofeos + v_delta, 0), partidas = partidas + 1,
         victorias = victorias + (case when p_puesto = 1 then 1 else 0 end), updated_at = now()
   where juego = s.juego and sesion = p_sesion returning trofeos into v_trofeos;
  return jsonb_build_object('trofeos', coalesce(v_trofeos, 0), 'delta', v_delta);
end;
$$;

create or replace function public.arena_top(p_juego uuid, p_sesion text, p_limite integer default 10)
returns table (posicion integer, alias text, trofeos integer, tuyo boolean)
language sql
stable
security definer
set search_path = public
as $$
  with r as (
    select a.alias, a.trofeos, a.sesion = p_sesion as tuyo, (rank() over (order by a.trofeos desc))::integer as posicion
      from public.arena_perfiles a where a.juego = p_juego and not a.oculta
  )
  select posicion, alias, trofeos, tuyo from r
   where posicion <= least(greatest(p_limite, 1), 50) or tuyo
   order by posicion limit 51;
$$;

-- Limpieza: salas de mas de un dia (las llama el trabajador cada cierto tiempo).
create or replace function public.arena_limpiar()
returns integer
language sql
security definer
set search_path = public
as $$
  with d as (delete from public.arena_salas where created_at < now() - interval '1 day' returning 1)
  select count(*)::integer from d;
$$;

create or replace function public._arena_borrar_juego()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.arena_salas where juego = old.telemetria_id;
  delete from public.arena_perfiles where juego = old.telemetria_id;
  return old;
end;
$$;
drop trigger if exists arena_borrar_juego on public.projects;
create trigger arena_borrar_juego after delete on public.projects for each row execute function public._arena_borrar_juego();

revoke all on function public._arena_niveles(uuid) from public, anon, authenticated;
revoke all on function public._arena_borrar_juego() from public, anon, authenticated;
revoke all on function public.arena_limpiar() from public, anon, authenticated;
grant execute on function public.arena_limpiar() to service_role;
grant execute on function public.arena_buscar(uuid, text, text) to anon, authenticated;
grant execute on function public.arena_estado(uuid, text) to anon, authenticated;
grant execute on function public.arena_resultado(uuid, text, integer) to anon, authenticated;
grant execute on function public.arena_top(uuid, text, integer) to anon, authenticated;

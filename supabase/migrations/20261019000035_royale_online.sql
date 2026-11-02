-- Battle royale en directo: las mismas salas que la arena, pero de hasta 8 jugadores (el resto de
-- la isla son bots que mueve el anfitrion) y con trofeos por puesto final (hasta el 40).
--   * arena_salas.cupo: jugadores por sala (4 en la arena, 8 en el battle royale).
--   * arena_salas.modo: 'todos', 'coop' o 'royale' (el de los juegos de genero royale).
--   * arena_buscar / arena_privada_crear / arena_privada_unir / arena_estado / arena_resultado
--     usan el cupo y el modo de la sala; la arena de siempre no cambia.
-- Trofeos del battle royale: 1.o +15, 2.o-3.o +8, 4.o-5.o +4, 6.o-10.o +1 y el resto -4.

alter table public.arena_salas add column if not exists cupo integer not null default 4;
alter table public.arena_salas drop constraint if exists arena_salas_cupo_check;
alter table public.arena_salas add constraint arena_salas_cupo_check check (cupo between 2 and 16);
alter table public.arena_salas drop constraint if exists arena_salas_modo_check;
alter table public.arena_salas add constraint arena_salas_modo_check check (modo in ('todos', 'coop', 'royale'));
alter table public.arena_jugadores drop constraint if exists arena_jugadores_slot_check;
alter table public.arena_jugadores add constraint arena_jugadores_slot_check check (slot between 0 and 15);
alter table public.arena_jugadores drop constraint if exists arena_jugadores_puesto_check;
alter table public.arena_jugadores add constraint arena_jugadores_puesto_check check (puesto between 1 and 40);

insert into public.settings (key, value, note) values
  ('royale_espera_s', 20, 'Segundos que espera una sala de battle royale antes de empezar con bots'),
  ('royale_cupo', 8, 'Jugadores de verdad por sala de battle royale (el resto, bots)')
on conflict (key) do nothing;

-- Juegos con salas en directo: arena y battle royale.
create or replace function public._arena_niveles(p_juego uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select case when coalesce(spec ->> 'genero', '') in ('arena', 'royale')
    then greatest(coalesce(jsonb_array_length(case when jsonb_typeof(spec -> 'niveles') = 'array' then spec -> 'niveles' end), 1), 1)
    end
  from public.projects where telemetria_id = p_juego;
$$;

create or replace function public._arena_es_royale(p_juego uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select spec ->> 'genero' = 'royale' from public.projects where telemetria_id = p_juego), false);
$$;

create or replace function public._arena_espera(s public.arena_salas)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select case when s.modo = 'royale' then public.setting('royale_espera_s') else public.setting('arena_espera_s') end::integer;
$$;

-- Buscar partida publica: nunca te mete en una sala privada; el cupo depende del juego.
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
  v_royale boolean;
  v_cupo integer;
  v_espera integer;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  if not public.alias_valido(p_alias) then raise exception 'bad_alias'; end if;
  v_niveles := public._arena_niveles(p_juego);
  if v_niveles is null then raise exception 'unknown_game'; end if;
  if (select count(*) from public.arena_jugadores j join public.arena_salas s on s.id = j.sala
       where j.sesion = p_sesion and s.created_at > now() - interval '1 hour') >= public.setting('arena_partidas_hora') then
    raise exception 'rate_limited';
  end if;
  v_royale := public._arena_es_royale(p_juego);
  v_cupo := case when v_royale then least(greatest(public.setting('royale_cupo')::integer, 2), 16) else 4 end;
  v_espera := case when v_royale then public.setting('royale_espera_s') else public.setting('arena_espera_s') end::integer;
  insert into public.arena_perfiles (juego, sesion, alias) values (p_juego, p_sesion, p_alias)
  on conflict (juego, sesion) do update set alias = excluded.alias, updated_at = now();
  -- Sala abierta con sitio (la mas antigua); se bloquea para no repetir puesto.
  select s.id into v_sala from public.arena_salas s
   where s.juego = p_juego and s.inicio is null and s.codigo is null
     and s.created_at > now() - make_interval(secs => v_espera)
     and (select count(*) from public.arena_jugadores j where j.sala = s.id) < s.cupo
   order by s.created_at limit 1 for update skip locked;
  if v_sala is null then
    insert into public.arena_salas (juego, nivel, semilla, modo, cupo)
    values (p_juego, floor(random() * v_niveles)::integer, floor(random() * 1000000)::integer,
            case when v_royale then 'royale' else 'todos' end, v_cupo) returning id into v_sala;
  end if;
  select slot into v_slot from public.arena_jugadores where sala = v_sala and sesion = p_sesion;
  if v_slot is null then
    select min(g) into v_slot from generate_series(0, (select cupo from public.arena_salas where id = v_sala) - 1) g
     where g not in (select slot from public.arena_jugadores where sala = v_sala);
    if v_slot is null then raise exception 'room_full'; end if;
    insert into public.arena_jugadores (sala, sesion, alias, slot) values (v_sala, p_sesion, p_alias, v_slot);
  end if;
  return jsonb_build_object('sala', v_sala, 'slot', v_slot);
end;
$$;

-- Sala con amigos: en un battle royale el modo es siempre 'royale' (y cabe el cupo del royale).
create or replace function public.arena_privada_crear(p_juego uuid, p_sesion text, p_alias text, p_modo text default 'todos')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_niveles integer;
  v_sala uuid;
  v_codigo text;
  v_royale boolean;
  v_modo text;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  if not public.alias_valido(p_alias) then raise exception 'bad_alias'; end if;
  if coalesce(p_modo, '') not in ('todos', 'coop', 'royale') then raise exception 'bad_mode'; end if;
  v_niveles := public._arena_niveles(p_juego);
  if v_niveles is null then raise exception 'unknown_game'; end if;
  v_royale := public._arena_es_royale(p_juego);
  v_modo := case when v_royale then 'royale' when p_modo = 'royale' then 'todos' else p_modo end;
  insert into public.arena_perfiles (juego, sesion, alias) values (p_juego, p_sesion, p_alias)
  on conflict (juego, sesion) do update set alias = excluded.alias, updated_at = now();
  loop
    v_codigo := translate(upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6)), '01', 'KM');
    exit when not exists (select 1 from public.arena_salas where codigo = v_codigo and inicio is null);
  end loop;
  insert into public.arena_salas (juego, nivel, semilla, codigo, modo, cupo)
  values (p_juego, floor(random() * v_niveles)::integer, floor(random() * 1000000)::integer, v_codigo, v_modo,
          case when v_royale then least(greatest(public.setting('royale_cupo')::integer, 2), 16) else 4 end) returning id into v_sala;
  insert into public.arena_jugadores (sala, sesion, alias, slot) values (v_sala, p_sesion, p_alias, 0);
  return jsonb_build_object('sala', v_sala, 'slot', 0, 'codigo', v_codigo, 'modo', v_modo);
end;
$$;

create or replace function public.arena_privada_unir(p_juego uuid, p_sesion text, p_alias text, p_codigo text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sala uuid;
  v_slot integer;
  v_cupo integer;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  if not public.alias_valido(p_alias) then raise exception 'bad_alias'; end if;
  select id, cupo into v_sala, v_cupo from public.arena_salas
   where juego = p_juego and codigo = upper(trim(coalesce(p_codigo, ''))) and inicio is null
     and created_at > now() - interval '10 minutes' for update;
  if v_sala is null then raise exception 'unknown_room'; end if;
  insert into public.arena_perfiles (juego, sesion, alias) values (p_juego, p_sesion, p_alias)
  on conflict (juego, sesion) do update set alias = excluded.alias, updated_at = now();
  select slot into v_slot from public.arena_jugadores where sala = v_sala and sesion = p_sesion;
  if v_slot is null then
    select min(g) into v_slot from generate_series(0, v_cupo - 1) g where g not in (select slot from public.arena_jugadores where sala = v_sala);
    if v_slot is null then raise exception 'room_full'; end if;
    insert into public.arena_jugadores (sala, sesion, alias, slot) values (v_sala, p_sesion, p_alias, v_slot);
  end if;
  return jsonb_build_object('sala', v_sala, 'slot', v_slot, 'codigo', upper(trim(p_codigo)));
end;
$$;

-- Empieza con la sala llena o, si es publica, al acabar la espera (la del royale es mas larga).
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
  v_espera integer;
begin
  select * into s from public.arena_salas where id = p_sala for update;
  if not found then raise exception 'unknown_room'; end if;
  if not exists (select 1 from public.arena_jugadores where sala = p_sala and sesion = p_sesion) then raise exception 'not_in_room'; end if;
  select count(*) into v_n from public.arena_jugadores where sala = p_sala;
  v_espera := public._arena_espera(s);
  if s.inicio is null and (v_n >= s.cupo or (s.codigo is null and s.created_at <= now() - make_interval(secs => v_espera))) then
    update public.arena_salas set inicio = now() + interval '3 seconds' where id = p_sala returning * into s;
  end if;
  v_en := case when s.inicio is not null then extract(epoch from s.inicio - now())
    when s.codigo is not null then -1
    else extract(epoch from s.created_at + make_interval(secs => v_espera) - now()) + 3 end;
  return jsonb_build_object('sala', s.id, 'nivel', s.nivel, 'semilla', s.semilla, 'empezada', s.inicio is not null,
    'en', case when v_en < 0 and s.inicio is null then -1 else round(greatest(v_en, 0), 2) end,
    'privada', s.codigo is not null, 'codigo', s.codigo, 'modo', s.modo, 'cupo', s.cupo,
    'jugadores', (select coalesce(jsonb_agg(jsonb_build_object('sesion', j.sesion, 'alias', j.alias, 'slot', j.slot) order by j.slot), '[]'::jsonb)
                    from public.arena_jugadores j where j.sala = p_sala));
end;
$$;

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
  if p_puesto is null or p_puesto < 1 or p_puesto > (case when s.modo = 'royale' then 40 else 4 end) then raise exception 'bad_result'; end if;
  -- Cooperativo: se anota (para cerrar la sala) pero no mueve trofeos.
  if s.modo = 'coop' then
    update public.arena_jugadores set puesto = p_puesto, delta = 0 where sala = p_sala and sesion = p_sesion;
    select trofeos into v_trofeos from public.arena_perfiles where juego = s.juego and sesion = p_sesion;
    return jsonb_build_object('trofeos', coalesce(v_trofeos, 0), 'delta', 0, 'coop', true);
  end if;
  -- Dos jugadores no pueden decir que han quedado primeros.
  if p_puesto = 1 and exists (select 1 from public.arena_jugadores where sala = p_sala and puesto = 1) then
    raise exception 'bad_result';
  end if;
  if s.modo = 'royale' then
    v_delta := case when p_puesto = 1 then 15 when p_puesto <= 3 then 8 when p_puesto <= 5 then 4 when p_puesto <= 10 then 1 else -4 end;
  else
    v_delta := case p_puesto when 1 then 12 when 2 then 5 when 3 then -2 else -6 end;
  end if;
  update public.arena_jugadores set puesto = p_puesto, delta = v_delta where sala = p_sala and sesion = p_sesion;
  update public.arena_perfiles set trofeos = greatest(trofeos + v_delta, 0), partidas = partidas + 1,
         victorias = victorias + (case when p_puesto = 1 then 1 else 0 end), updated_at = now()
   where juego = s.juego and sesion = p_sesion returning trofeos into v_trofeos;
  return jsonb_build_object('trofeos', coalesce(v_trofeos, 0), 'delta', v_delta, 'royale', s.modo = 'royale');
end;
$$;

revoke execute on function public._arena_es_royale(uuid) from public, anon, authenticated;
revoke execute on function public._arena_espera(public.arena_salas) from public, anon, authenticated;

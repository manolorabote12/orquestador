-- Zombis 3D en cooperativo: los juegos de genero "zombis" tienen salas en directo (hasta 4
-- jugadores) siempre en modo 'coop': juntos contra las oleadas, sin trofeos.
--   * _arena_niveles: tambien los juegos de zombis.
--   * _arena_es_coop: el juego es de zombis.
--   * arena_buscar y arena_privada_crear: en un juego de zombis la sala es siempre cooperativa.

create or replace function public._arena_niveles(p_juego uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select case when coalesce(spec ->> 'genero', '') in ('arena', 'royale', 'zombis')
    then greatest(coalesce(jsonb_array_length(case when jsonb_typeof(spec -> 'niveles') = 'array' then spec -> 'niveles' end), 1), 1)
    end
  from public.projects where telemetria_id = p_juego;
$$;

create or replace function public._arena_es_coop(p_juego uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select spec ->> 'genero' = 'zombis' from public.projects where telemetria_id = p_juego), false);
$$;

-- Buscar partida publica: en un juego de zombis la sala es cooperativa.
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
  v_coop boolean;
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
  v_coop := public._arena_es_coop(p_juego);
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
            case when v_royale then 'royale' when v_coop then 'coop' else 'todos' end, v_cupo) returning id into v_sala;
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

-- Sala con amigos: en un juego de zombis siempre cooperativa.
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
  v_modo := case when v_royale then 'royale' when public._arena_es_coop(p_juego) then 'coop' when p_modo = 'royale' then 'todos' else p_modo end;
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

revoke execute on function public._arena_es_coop(uuid) from public, anon, authenticated;

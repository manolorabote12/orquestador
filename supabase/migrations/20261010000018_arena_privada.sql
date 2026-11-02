-- Salas privadas de arena: juegas con tus amigos con un codigo de 6 letras.
--   arena_privada_crear: crea la sala (tu eres el puesto 0) y te da el codigo para compartir.
--   arena_privada_unir: entra con el codigo (hasta 4).
--   arena_empezar: solo quien la creo; lo que falte se rellena con bots.
-- Una sala privada no empieza sola por tiempo (si a los 10 minutos nadie la empieza, caduca).

alter table public.arena_salas add column if not exists codigo text;
create unique index if not exists arena_salas_codigo_idx on public.arena_salas (codigo) where codigo is not null and inicio is null;

create or replace function public.arena_privada_crear(p_juego uuid, p_sesion text, p_alias text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_niveles integer;
  v_sala uuid;
  v_codigo text;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  if not public.alias_valido(p_alias) then raise exception 'bad_alias'; end if;
  v_niveles := public._arena_niveles(p_juego);
  if v_niveles is null then raise exception 'unknown_game'; end if;
  insert into public.arena_perfiles (juego, sesion, alias) values (p_juego, p_sesion, p_alias)
  on conflict (juego, sesion) do update set alias = excluded.alias, updated_at = now();
  loop
    v_codigo := translate(upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6)), '01', 'KM');
    exit when not exists (select 1 from public.arena_salas where codigo = v_codigo and inicio is null);
  end loop;
  insert into public.arena_salas (juego, nivel, semilla, codigo)
  values (p_juego, floor(random() * v_niveles)::integer, floor(random() * 1000000)::integer, v_codigo) returning id into v_sala;
  insert into public.arena_jugadores (sala, sesion, alias, slot) values (v_sala, p_sesion, p_alias, 0);
  return jsonb_build_object('sala', v_sala, 'slot', 0, 'codigo', v_codigo);
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
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  if not public.alias_valido(p_alias) then raise exception 'bad_alias'; end if;
  select id into v_sala from public.arena_salas
   where juego = p_juego and codigo = upper(trim(coalesce(p_codigo, ''))) and inicio is null
     and created_at > now() - interval '10 minutes' for update;
  if v_sala is null then raise exception 'unknown_room'; end if;
  insert into public.arena_perfiles (juego, sesion, alias) values (p_juego, p_sesion, p_alias)
  on conflict (juego, sesion) do update set alias = excluded.alias, updated_at = now();
  select slot into v_slot from public.arena_jugadores where sala = v_sala and sesion = p_sesion;
  if v_slot is null then
    select min(s) into v_slot from generate_series(0, 3) s where s not in (select slot from public.arena_jugadores where sala = v_sala);
    if v_slot is null then raise exception 'room_full'; end if;
    insert into public.arena_jugadores (sala, sesion, alias, slot) values (v_sala, p_sesion, p_alias, v_slot);
  end if;
  return jsonb_build_object('sala', v_sala, 'slot', v_slot, 'codigo', upper(trim(p_codigo)));
end;
$$;

create or replace function public.arena_empezar(p_sala uuid, p_sesion text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.arena_salas s set inicio = now() + interval '3 seconds'
   where s.id = p_sala and s.inicio is null and s.codigo is not null
     and exists (select 1 from public.arena_jugadores j where j.sala = p_sala and j.sesion = p_sesion and j.slot = 0);
  if not found then raise exception 'not_allowed'; end if;
end;
$$;

-- Buscar partida publica: nunca te mete en una sala privada.
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
   where s.juego = p_juego and s.inicio is null and s.codigo is null
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

-- Las salas privadas no empiezan solas por tiempo (si con 4 jugadores).
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
  if s.inicio is null and (v_n >= 4 or (s.codigo is null and s.created_at <= now() - make_interval(secs => public.setting('arena_espera_s')))) then
    update public.arena_salas set inicio = now() + interval '3 seconds' where id = p_sala returning * into s;
  end if;
  v_en := case when s.inicio is not null then extract(epoch from s.inicio - now())
    when s.codigo is not null then -1
    else extract(epoch from s.created_at + make_interval(secs => public.setting('arena_espera_s')) - now()) + 3 end;
  return jsonb_build_object('sala', s.id, 'nivel', s.nivel, 'semilla', s.semilla, 'empezada', s.inicio is not null,
    'en', case when v_en < 0 and s.inicio is null then -1 else round(greatest(v_en, 0), 2) end,
    'privada', s.codigo is not null, 'codigo', s.codigo,
    'jugadores', (select coalesce(jsonb_agg(jsonb_build_object('sesion', j.sesion, 'alias', j.alias, 'slot', j.slot) order by j.slot), '[]'::jsonb)
                    from public.arena_jugadores j where j.sala = p_sala));
end;
$$;

grant execute on function public.arena_privada_crear(uuid, text, text) to anon, authenticated;
grant execute on function public.arena_privada_unir(uuid, text, text, text) to anon, authenticated;
grant execute on function public.arena_empezar(uuid, text) to anon, authenticated;

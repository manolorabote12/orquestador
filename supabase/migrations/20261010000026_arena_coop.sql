-- Arena cooperativa: en una sala con amigos se puede elegir "coop": los jugadores juntos (sin
-- fuego amigo) contra oleadas de bots. No da ni quita trofeos (la clasificacion es del todos
-- contra todos).

alter table public.arena_salas add column if not exists modo text not null default 'todos' check (modo in ('todos', 'coop'));

drop function if exists public.arena_privada_crear(uuid, text, text);
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
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  if not public.alias_valido(p_alias) then raise exception 'bad_alias'; end if;
  if coalesce(p_modo, '') not in ('todos', 'coop') then raise exception 'bad_mode'; end if;
  v_niveles := public._arena_niveles(p_juego);
  if v_niveles is null then raise exception 'unknown_game'; end if;
  insert into public.arena_perfiles (juego, sesion, alias) values (p_juego, p_sesion, p_alias)
  on conflict (juego, sesion) do update set alias = excluded.alias, updated_at = now();
  loop
    v_codigo := translate(upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6)), '01', 'KM');
    exit when not exists (select 1 from public.arena_salas where codigo = v_codigo and inicio is null);
  end loop;
  insert into public.arena_salas (juego, nivel, semilla, codigo, modo)
  values (p_juego, floor(random() * v_niveles)::integer, floor(random() * 1000000)::integer, v_codigo, p_modo) returning id into v_sala;
  insert into public.arena_jugadores (sala, sesion, alias, slot) values (v_sala, p_sesion, p_alias, 0);
  return jsonb_build_object('sala', v_sala, 'slot', 0, 'codigo', v_codigo, 'modo', p_modo);
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
  if s.inicio is null and (v_n >= 4 or (s.codigo is null and s.created_at <= now() - make_interval(secs => public.setting('arena_espera_s')))) then
    update public.arena_salas set inicio = now() + interval '3 seconds' where id = p_sala returning * into s;
  end if;
  v_en := case when s.inicio is not null then extract(epoch from s.inicio - now())
    when s.codigo is not null then -1
    else extract(epoch from s.created_at + make_interval(secs => public.setting('arena_espera_s')) - now()) + 3 end;
  return jsonb_build_object('sala', s.id, 'nivel', s.nivel, 'semilla', s.semilla, 'empezada', s.inicio is not null,
    'en', case when v_en < 0 and s.inicio is null then -1 else round(greatest(v_en, 0), 2) end,
    'privada', s.codigo is not null, 'codigo', s.codigo, 'modo', s.modo,
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
  if p_puesto is null or p_puesto < 1 or p_puesto > 4 then raise exception 'bad_result'; end if;
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
  v_delta := case p_puesto when 1 then 12 when 2 then 5 when 3 then -2 else -6 end;
  update public.arena_jugadores set puesto = p_puesto, delta = v_delta where sala = p_sala and sesion = p_sesion;
  update public.arena_perfiles set trofeos = greatest(trofeos + v_delta, 0), partidas = partidas + 1,
         victorias = victorias + (case when p_puesto = 1 then 1 else 0 end), updated_at = now()
   where juego = s.juego and sesion = p_sesion returning trofeos into v_trofeos;
  return jsonb_build_object('trofeos', coalesce(v_trofeos, 0), 'delta', v_delta);
end;
$$;

grant execute on function public.arena_privada_crear(uuid, text, text, text) to anon, authenticated;

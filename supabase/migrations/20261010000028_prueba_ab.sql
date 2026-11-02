-- Pruebas A/B de un nivel: el juego apunta en cada intento del nivel probado que version jugo
-- ("g": a/b; kit/telemetry.gd). Nada mas: el grupo es una moneda al aire guardada en el movil.
--   prueba_ab_informe(p_project): para el autor, por version del juego: el nivel probado y, por
--   grupo, jugadores, intentos, ganados, abandonos, muertes medias y cuantos lo superan.

alter table public.partidas add column if not exists grupo text check (grupo in ('a', 'b'));

create or replace function public.registrar_partida(p_juego uuid, p_version integer, p_sesion text, p_eventos jsonb)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  e jsonb;
  n integer := 0;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{8,32}$' then raise exception 'bad_session'; end if;
  if jsonb_typeof(p_eventos) <> 'array' or jsonb_array_length(p_eventos) = 0 or jsonb_array_length(p_eventos) > 50 then
    raise exception 'bad_batch';
  end if;
  if p_version is null or p_version < 1 or p_version > 100000 then raise exception 'bad_version'; end if;
  if not exists (select 1 from public.projects where telemetria_id = p_juego) then raise exception 'unknown_game'; end if;
  if (select count(*) from public.partidas where sesion = p_sesion and created_at > now() - interval '1 hour')
     + jsonb_array_length(p_eventos) > public.setting('partidas_por_sesion_hora') then
    raise exception 'rate_limited';
  end if;
  if (select count(*) from public.partidas where juego = p_juego and created_at > now() - interval '1 day')
     >= public.setting('partidas_por_juego_dia') then
    raise exception 'rate_limited';
  end if;
  for e in select * from jsonb_array_elements(p_eventos) loop
    -- Lo que no tiene la forma exacta se ignora (sin convertir nada antes de comprobarlo).
    if jsonb_typeof(e) <> 'object'
       or coalesce(e ->> 'n', '') !~ '^[0-9]{1,2}$'
       or coalesce(e ->> 'r', '') not in ('gana', 'muere', 'sale', 'reintenta')
       or coalesce(e ->> 's', '') !~ '^[0-9]{1,4}(\.[0-9]{1,3})?$'
       or coalesce(e ->> 'm', '') !~ '^[0-9]{1,3}$'
       or coalesce(e ->> 'e', '0') !~ '^[0-3]$'
       or coalesce(e ->> 'g', 'a') not in ('a', 'b') then
      continue;
    end if;
    if (e ->> 's')::real > 7200 then
      continue;
    end if;
    insert into public.partidas (juego, version, sesion, nivel, resultado, segundos, muertes, estrellas, grupo)
    values (p_juego, p_version, p_sesion, (e ->> 'n')::int, e ->> 'r', (e ->> 's')::real, (e ->> 'm')::int, (e ->> 'e')::int, e ->> 'g');
    n := n + 1;
  end loop;
  return n;
end;
$$;


create or replace function public.prueba_ab_informe(p_project uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tel uuid;
  v_ab jsonb;
  v_nivel integer;
  v_version integer;
begin
  select telemetria_id, spec -> 'prueba_ab' into v_tel, v_ab from public.projects where id = p_project and user_id = auth.uid();
  if not found then raise exception 'project_not_found'; end if;
  if v_ab is null or jsonb_typeof(v_ab) <> 'object' then return null; end if;
  v_nivel := (v_ab ->> 'nivel')::int;
  -- La version mas nueva con datos de la prueba (las anteriores no la llevaban).
  select max(version) into v_version from public.partidas where juego = v_tel and nivel = v_nivel and grupo is not null;
  return jsonb_build_object(
    'nivel', v_nivel, 'hacia', v_ab ->> 'hacia', 'version', v_version,
    'grupos', coalesce((select jsonb_object_agg(grupo, jsonb_build_object(
        'jugadores', jugadores, 'intentos', intentos, 'ganados', ganados, 'salidas', salidas,
        'muertes', muertes, 'superan', superan))
      from (
        select p.grupo, count(distinct p.sesion)::int as jugadores, count(*)::int as intentos,
               count(*) filter (where p.resultado = 'gana')::int as ganados,
               count(*) filter (where p.resultado = 'sale')::int as salidas,
               round(avg(p.muertes)::numeric, 2) as muertes,
               count(distinct p.sesion) filter (where p.resultado = 'gana')::int as superan
          from public.partidas p
         where p.juego = v_tel and p.nivel = v_nivel and p.version = v_version and p.grupo is not null
         group by p.grupo
      ) x), '{}'::jsonb));
end;
$$;

revoke all on function public.prueba_ab_informe(uuid) from public, anon;
grant execute on function public.prueba_ab_informe(uuid) to authenticated;

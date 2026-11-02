-- Clasificaciones de los modos de juego (kit/time_attack.gd y kit/marathon.gd), en la misma tabla:
--   nivel 0..99        -> puntos del nivel (como siempre)
--   nivel 1000 + n     -> contrarreloj del nivel n; puntos = 3600000 - milisegundos (mas es mejor)
--   nivel 2000         -> maraton; puntos = niveles superados seguidos
alter table public.marcadores drop constraint if exists marcadores_nivel_check;
alter table public.marcadores add constraint marcadores_nivel_check
  check (nivel between 0 and 99 or nivel between 1000 and 1099 or nivel = 2000);

create or replace function public.marcador_enviar(p_juego uuid, p_nivel integer, p_sesion text, p_alias text, p_puntos integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_niveles integer;
  v_base    integer;
  v_mejor   integer;
  v_pos     integer;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  if not public.alias_valido(p_alias) then raise exception 'bad_alias'; end if;
  if p_puntos is null or p_puntos < 1 or p_puntos > public.setting('marcador_max_puntos') then raise exception 'bad_score'; end if;
  select coalesce(jsonb_array_length(case when jsonb_typeof(spec -> 'niveles') = 'array' then spec -> 'niveles' end), 100)
    into v_niveles from public.projects where telemetria_id = p_juego;
  if not found then raise exception 'unknown_game'; end if;
  -- Nivel del juego al que corresponde la marca (la maraton cuenta como el nivel 0).
  v_base := case when p_nivel = 2000 then 0 when p_nivel between 1000 and 1099 then p_nivel - 1000
    when p_nivel between 0 and 99 then p_nivel else -1 end;
  if v_base < 0 or v_base >= least(v_niveles, 100) then raise exception 'bad_level'; end if;
  -- Maraton: no se pueden superar mas niveles seguidos de los que tiene el juego.
  if p_nivel = 2000 and p_puntos > v_niveles then raise exception 'bad_score'; end if;
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

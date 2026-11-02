-- Repeticiones de los asaltos de la liga de aldeas: el atacante sube, al acabar, como fue su
-- asalto (mapa, fuerza de su ejercito y en que momento solto cada tropa; como mucho 64 KB) y el
-- defensor lo ve otra vez en su movil (el juego lo vuelve a simular igual).
--   liga_repeticion_subir (atacante, una vez, solo asaltos cerrados), liga_repeticion (atacante o
--   defensor) y liga_defensas ahora dice el id del asalto y si tiene repeticion.

alter table public.liga_ataques add column if not exists repeticion jsonb;

create or replace function public.liga_repeticion_subir(p_juego uuid, p_sesion text, p_ataque bigint, p_datos jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_datos is null or jsonb_typeof(p_datos) <> 'object' or jsonb_typeof(p_datos -> 'eventos') <> 'array'
     or octet_length(p_datos::text) > 65536 then
    raise exception 'bad_data';
  end if;
  update public.liga_ataques t set repeticion = p_datos
    from public.liga_aldeas yo
   where t.id = p_ataque and t.atacante = yo.id and yo.juego = p_juego and yo.sesion = p_sesion
     and t.cerrado_at is not null and t.repeticion is null;
  return found;
end;
$$;

create or replace function public.liga_repeticion(p_juego uuid, p_sesion text, p_ataque bigint)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select t.repeticion || jsonb_build_object('alias', atq.alias, 'estrellas', t.estrellas, 'destruccion', t.destruccion)
    from public.liga_ataques t
    join public.liga_aldeas atq on atq.id = t.atacante
    join public.liga_aldeas def on def.id = t.defensor
   where t.id = p_ataque and t.repeticion is not null and t.juego = p_juego
     and (atq.sesion = p_sesion or def.sesion = p_sesion);
$$;

drop function if exists public.liga_defensas(uuid, text);
create or replace function public.liga_defensas(p_juego uuid, p_sesion text)
returns table (alias text, estrellas integer, destruccion integer, trofeos integer, fecha timestamptz, ataque bigint, repeticion boolean)
language sql
stable
security definer
set search_path = public
as $$
  select atq.alias, t.estrellas, t.destruccion, t.delta, t.cerrado_at, t.id, t.repeticion is not null
    from public.liga_ataques t
    join public.liga_aldeas yo on yo.id = t.defensor and yo.juego = p_juego and yo.sesion = p_sesion
    join public.liga_aldeas atq on atq.id = t.atacante
   where t.cerrado_at is not null
   order by t.cerrado_at desc limit 10;
$$;

grant execute on function public.liga_defensas(uuid, text) to anon, authenticated;
grant execute on function public.liga_repeticion_subir(uuid, text, bigint, jsonb) to anon, authenticated;
grant execute on function public.liga_repeticion(uuid, text, bigint) to anon, authenticated;

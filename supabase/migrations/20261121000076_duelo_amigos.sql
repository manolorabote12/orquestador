-- Duelos entre amigos (21 nov): la lista de equipos de defensa de TUS amigos (los anadidos con su
-- codigo en amigo_anadir) para asaltarlos con duelo_empezar como a cualquier rival. Sin tablas nuevas.

create or replace function public.duelo_amigos(p_juego uuid, p_sesion text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v jsonb;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  select coalesce(jsonb_agg(x), '[]'::jsonb) into v from (
    select jsonb_build_object('id', e.id, 'alias', e.alias, 'equipo', e.equipo, 'poder', e.poder, 'puntos', e.puntos) as x
      from public.amigos a
      join public.duelo_equipos e on e.juego = a.juego and e.sesion = a.amigo and not e.oculta
     where a.juego = p_juego and a.sesion = p_sesion
     order by e.puntos desc
     limit 50) s;
  return v;
end;
$$;

revoke all on function public.duelo_amigos(uuid, text) from public;
grant execute on function public.duelo_amigos(uuid, text) to anon, authenticated;

-- Fantasmas: la carrera de otro jugador se ve en tu nivel como una sombra (plataformas, runner y volador).
--   fantasma_subir: guarda tu recorrido del nivel si es el de tu mejor marca (la de marcadores).
--   fantasma_bajar: el recorrido de quien va justo por delante de ti (o del primero), con su apodo.
-- Recorrido: lista de puntos [x, y] cada 0,1 s, como mucho 3000 (5 minutos).

alter table public.marcadores add column if not exists fantasma jsonb;

create or replace function public.fantasma_subir(p_juego uuid, p_nivel integer, p_sesion text, p_puntos integer, p_datos jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_datos is null or jsonb_typeof(p_datos) <> 'array' or jsonb_array_length(p_datos) < 2
     or jsonb_array_length(p_datos) > 3000 or pg_column_size(p_datos) > 120000 then
    raise exception 'bad_ghost';
  end if;
  if exists (select 1 from jsonb_array_elements(p_datos) e
              where jsonb_typeof(e) <> 'array' or jsonb_array_length(e) <> 2
                 or jsonb_typeof(e -> 0) <> 'number' or jsonb_typeof(e -> 1) <> 'number') then
    raise exception 'bad_ghost';
  end if;
  update public.marcadores set fantasma = p_datos
   where juego = p_juego and nivel = p_nivel and sesion = p_sesion and puntos = p_puntos;
  return found;
end;
$$;

create or replace function public.fantasma_bajar(p_juego uuid, p_nivel integer, p_sesion text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_mio integer;
  r record;
begin
  select puntos into v_mio from public.marcadores where juego = p_juego and nivel = p_nivel and sesion = p_sesion;
  -- El que va justo por delante (si eres el primero o no tienes marca: el primero que no seas tu).
  select alias, puntos, fantasma into r from public.marcadores
   where juego = p_juego and nivel = p_nivel and not oculta and fantasma is not null and sesion <> coalesce(p_sesion, '')
     and (v_mio is null or puntos > v_mio)
   order by puntos asc limit 1;
  if r.fantasma is null then
    select alias, puntos, fantasma into r from public.marcadores
     where juego = p_juego and nivel = p_nivel and not oculta and fantasma is not null and sesion <> coalesce(p_sesion, '')
     order by puntos desc limit 1;
  end if;
  if r.fantasma is null then return null; end if;
  return jsonb_build_object('alias', r.alias, 'puntos', r.puntos, 'datos', r.fantasma);
end;
$$;

grant execute on function public.fantasma_subir(uuid, integer, text, integer, jsonb) to anon, authenticated;
grant execute on function public.fantasma_bajar(uuid, integer, text) to anon, authenticated;

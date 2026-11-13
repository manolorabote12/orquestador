-- Portal web de juegos (13 nov 2026), tipo Poki / CrazyGames: la web publica lista los juegos del
-- escaparate con su enlace de Google Play cuando el autor lo ha publicado en produccion.
-- Solo se expone el nombre del paquete (publico en Google Play); nada mas del autor.

create or replace function public.portal_play(p_project uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select p.play ->> 'paquete'
    from public.projects p
    join public.escaparate e on e.project_id = p.id and not e.oculto
   where p.id = p_project
     and p.play ->> 'paquete' is not null
     and p.play ->> 'estado' in ('subido', 'produccion', 'publicado')
     and coalesce(p.play ->> 'pista', '') = 'production';
$$;

create or replace function public.portal_lista(p_orden text default 'top', p_genero text default null)
returns table (project_id uuid, titulo text, genero text, resumen text, autor text, version integer,
  jugadas integer, megusta integer, remixes integer, publicado_en timestamptz, play text)
language sql
stable
security definer
set search_path = public
as $$
  select l.project_id, l.titulo, l.genero, l.resumen, l.autor, l.version, l.jugadas, l.megusta, l.remixes, l.publicado_en,
         public.portal_play(l.project_id)
    from public.escaparate_lista(p_orden, p_genero) l;
$$;

revoke all on function public.portal_play(uuid) from public;
revoke all on function public.portal_lista(text, text) from public;
grant execute on function public.portal_play(uuid) to anon, authenticated;
grant execute on function public.portal_lista(text, text) to anon, authenticated;

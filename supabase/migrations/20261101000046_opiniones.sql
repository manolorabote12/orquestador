-- Opiniones privadas: el juego pregunta "¿Te esta gustando?" en un buen momento. Con un si, lleva a
-- valorar en Google Play; con un no, pide que cuente que mejorar y eso le llega solo al autor
-- (no a la ficha de la tienda). Una opinion por jugador y juego (la ultima cuenta).
--   juego (anon) -> opinion_enviar   autor (app) -> opiniones_autor (ultimas 50 y el recuento)
create table if not exists public.juego_opiniones (
  juego      uuid not null,
  sesion     text not null,
  gusta      boolean not null,
  texto      text not null default '' check (char_length(texto) <= 300),
  nivel      integer not null default 0,
  version    integer not null default 0,
  created_at timestamptz not null default now(),
  primary key (juego, sesion)
);
alter table public.juego_opiniones enable row level security;
create index if not exists juego_opiniones_reciente on public.juego_opiniones (juego, created_at desc);

create or replace function public.opinion_enviar(p_juego uuid, p_sesion text, p_gusta boolean, p_texto text default '',
  p_nivel integer default 0, p_version integer default 0)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  if p_gusta is null then raise exception 'bad_opinion'; end if;
  if not exists (select 1 from public.projects where telemetria_id = p_juego) then raise exception 'not_found'; end if;
  p_texto := left(regexp_replace(btrim(coalesce(p_texto, '')), '[<>{}\\]', '', 'g'), 300);
  insert into public.juego_opiniones (juego, sesion, gusta, texto, nivel, version)
  values (p_juego, p_sesion, p_gusta, p_texto, greatest(coalesce(p_nivel, 0), 0), greatest(coalesce(p_version, 0), 0))
  on conflict (juego, sesion) do update set gusta = excluded.gusta, texto = excluded.texto, nivel = excluded.nivel,
    version = excluded.version, created_at = now();
end;
$$;

create or replace function public.opiniones_autor(p_project uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_juego uuid;
begin
  select telemetria_id into v_juego from public.projects where id = p_project and user_id = auth.uid();
  if not found then raise exception 'project_not_found'; end if;
  return jsonb_build_object(
    'gusta', (select count(*) from public.juego_opiniones where juego = v_juego and gusta),
    'no_gusta', (select count(*) from public.juego_opiniones where juego = v_juego and not gusta),
    'ultimas', coalesce((select jsonb_agg(jsonb_build_object('gusta', o.gusta, 'texto', o.texto, 'nivel', o.nivel,
        'version', o.version, 'fecha', o.created_at) order by o.created_at desc)
      from (select * from public.juego_opiniones where juego = v_juego and texto <> '' order by created_at desc limit 50) o), '[]'::jsonb));
end;
$$;

grant execute on function public.opinion_enviar(uuid, text, boolean, text, integer, integer) to anon, authenticated;
revoke all on function public.opiniones_autor(uuid) from public, anon;
grant execute on function public.opiniones_autor(uuid) to authenticated;

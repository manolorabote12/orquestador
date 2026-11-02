-- Juego regalo: un juego hecho para una persona ("Para Lucia, de Dani") con un mensaje secreto que
-- aparece al superar el nivel que elija el autor, y un enlace privado (no sale en el escaparate).
--   autor (app)   -> regalo_guardar (para vacio = quitarlo) y regalo_autor (si ya lo abrio y lo leyo).
--   web (anon)    -> regalo_ficha (titulo, para y de; nunca el mensaje) y regalo_abierto.
--   juego (anon)  -> regalo_juego (por el id del juego) y regalo_leido al ver el mensaje.
-- Los archivos los sube la funcion escaparate (accion "regalo") a la misma carpeta publica.
create table if not exists public.juego_regalos (
  project_id  uuid primary key references public.projects (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  para        text not null check (char_length(para) between 1 and 20),
  de          text not null check (char_length(de) between 1 and 20),
  mensaje     text not null check (char_length(mensaje) between 1 and 400),
  tras_nivel  integer not null default 0 check (tras_nivel between 0 and 50),
  abierto_en  timestamptz,
  leido_en    timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
alter table public.juego_regalos enable row level security;

create or replace function public._regalo_ok(p text, n integer)
returns boolean
language sql
immutable
as $$
  select p is not null and char_length(btrim(p)) between 1 and n and p !~ '[<>{}\\]';
$$;

create or replace function public.regalo_guardar(p_project uuid, p_para text, p_de text, p_mensaje text, p_tras_nivel integer default 0)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'unknown_user'; end if;
  if not exists (select 1 from public.projects where id = p_project and user_id = auth.uid()) then raise exception 'project_not_found'; end if;
  if coalesce(btrim(p_para), '') = '' then
    delete from public.juego_regalos where project_id = p_project;
    return null;
  end if;
  if not public._regalo_ok(p_para, 20) or not public._regalo_ok(p_de, 20) then raise exception 'bad_name'; end if;
  if not public._regalo_ok(p_mensaje, 400) then raise exception 'bad_message'; end if;
  if p_tras_nivel is null or p_tras_nivel < 0 or p_tras_nivel > 50 then raise exception 'bad_level'; end if;
  insert into public.juego_regalos (project_id, user_id, para, de, mensaje, tras_nivel)
  values (p_project, auth.uid(), btrim(p_para), btrim(p_de), btrim(p_mensaje), p_tras_nivel)
  on conflict (project_id) do update set para = excluded.para, de = excluded.de, mensaje = excluded.mensaje,
    tras_nivel = excluded.tras_nivel, updated_at = now();
  return public.regalo_autor(p_project);
end;
$$;

create or replace function public.regalo_autor(p_project uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object('para', r.para, 'de', r.de, 'mensaje', r.mensaje, 'tras_nivel', r.tras_nivel,
    'abierto_en', r.abierto_en, 'leido_en', r.leido_en)
    from public.juego_regalos r where r.project_id = p_project and r.user_id = auth.uid();
$$;

-- Para la pagina del enlace: quien lo regala y para quien (el mensaje solo lo ensena el juego).
create or replace function public.regalo_ficha(p_project uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object('titulo', p.title, 'para', r.para, 'de', r.de, 'version', p.version)
    from public.juego_regalos r join public.projects p on p.id = r.project_id where r.project_id = p_project;
$$;

create or replace function public.regalo_abierto(p_project uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.juego_regalos set abierto_en = now() where project_id = p_project and abierto_en is null;
$$;

create or replace function public.regalo_juego(p_juego uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object('para', r.para, 'de', r.de, 'mensaje', r.mensaje, 'tras_nivel', r.tras_nivel)
    from public.juego_regalos r join public.projects p on p.id = r.project_id where p.telemetria_id = p_juego;
$$;

create or replace function public.regalo_leido(p_juego uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.juego_regalos r set leido_en = now(), abierto_en = coalesce(r.abierto_en, now())
    from public.projects p where p.id = r.project_id and p.telemetria_id = p_juego and r.leido_en is null;
$$;

revoke all on function public.regalo_guardar(uuid, text, text, text, integer) from public, anon;
grant execute on function public.regalo_guardar(uuid, text, text, text, integer) to authenticated;
revoke all on function public.regalo_autor(uuid) from public, anon;
grant execute on function public.regalo_autor(uuid) to authenticated;
grant execute on function public.regalo_ficha(uuid), public.regalo_abierto(uuid), public.regalo_juego(uuid), public.regalo_leido(uuid) to anon, authenticated;

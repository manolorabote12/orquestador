-- Orquestador: subir los videos de marketing al canal de YouTube del usuario.
--
-- El usuario conecta su canal una vez (OAuth de Google, permiso youtube.upload). La funcion
-- youtube guarda el refresh token aqui; nadie lo lee salvo el servidor (la fabrica lo usa para
-- subir los Shorts y el trailer cuando el usuario lo pide al encargar los videos).

create table if not exists public.youtube_cuentas (
  user_id       uuid primary key references public.profiles (id) on delete cascade,
  refresh_token text not null,
  canal         text not null default '',
  canal_id      text not null default '',
  created_at    timestamptz not null default now()
);
alter table public.youtube_cuentas enable row level security;
-- Sin politicas: ni la app ni nadie con la clave publica puede leer el token.

create or replace function public.youtube_guardar(p_user uuid, p_refresh text, p_canal text, p_canal_id text)
returns void language sql security definer set search_path = public as $$
  insert into public.youtube_cuentas (user_id, refresh_token, canal, canal_id)
  values (p_user, p_refresh, left(coalesce(p_canal, ''), 120), left(coalesce(p_canal_id, ''), 60))
  on conflict (user_id) do update set refresh_token = excluded.refresh_token, canal = excluded.canal,
    canal_id = excluded.canal_id, created_at = now()
$$;

create or replace function public.youtube_token(p_user uuid)
returns text language sql stable security definer set search_path = public as $$
  select refresh_token from public.youtube_cuentas where user_id = p_user
$$;

create or replace function public.youtube_estado()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce((select jsonb_build_object('conectado', true, 'canal', canal) from public.youtube_cuentas where user_id = auth.uid()),
    jsonb_build_object('conectado', false))
$$;

create or replace function public.youtube_desconectar()
returns void language sql security definer set search_path = public as $$
  delete from public.youtube_cuentas where user_id = auth.uid()
$$;

-- Los videos pueden encargarse con subida a YouTube: 'no', 'oculto' (unlisted) o 'publico'.
drop function if exists public.queue_marketing(uuid, uuid);
create or replace function public.queue_marketing(p_user uuid, p_project uuid, p_youtube text default 'no')
returns table (job_id uuid, credits_left integer, cost integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_version integer;
begin
  if p_youtube not in ('no', 'oculto', 'publico') then raise exception 'bad_youtube'; end if;
  if p_youtube <> 'no' and not exists (select 1 from public.youtube_cuentas where user_id = p_user) then
    raise exception 'youtube_not_connected';
  end if;
  select version into v_version from public.projects where id = p_project and user_id = p_user;
  if not found then raise exception 'project_not_found'; end if;
  if exists (select 1 from public.jobs where project_id = p_project and status in ('queued', 'running')) then
    raise exception 'project_busy';
  end if;
  select * into r from public.reserve_job(p_user, 'game_marketing', jsonb_build_object('version', v_version, 'youtube', p_youtube));
  update public.jobs set status = 'queued', project_id = p_project where id = r.job_id;
  return query select r.job_id, r.credits_left, r.cost;
end;
$$;

revoke all on function public.youtube_guardar(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.youtube_guardar(uuid, text, text, text) to service_role;
revoke all on function public.youtube_token(uuid) from public, anon, authenticated;
grant execute on function public.youtube_token(uuid) to service_role;
revoke all on function public.youtube_estado() from public, anon;
grant execute on function public.youtube_estado() to authenticated;
revoke all on function public.youtube_desconectar() from public, anon;
grant execute on function public.youtube_desconectar() to authenticated;
revoke all on function public.queue_marketing(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.queue_marketing(uuid, uuid, text) to service_role;

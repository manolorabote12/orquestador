-- Orquestador: modo experto (15 nov 2026). El autor baja el proyecto de Godot, lo cambia a mano (con
-- Chispa dentro del editor: addons/chispa) y lo sube. La fabrica lo revisa (fabrica/experto.py), le
-- pasa los bots y saca el APK y la version nueva, como cualquier cambio (se puede volver atras).
--
-- El plugin de Godot no tiene la sesion de la app: usa un codigo de enlace (uno por juego, 30 dias),
-- que se crea desde la app y se puede cambiar cuando se quiera (el viejo deja de valer).

insert into public.pricing (kind, label, credits, max_per_day, est_cost_usd, enabled) values
  ('game_expert', 'Subir cambios hechos a mano en Godot', 25, 15, 0.050, true)
on conflict (kind) do update set label = excluded.label, credits = excluded.credits, est_cost_usd = excluded.est_cost_usd,
  max_per_day = excluded.max_per_day, enabled = excluded.enabled;

-- Proyectos subidos: privado; solo escribe el servidor (URL firmada) y lo borra la fabrica al usarlo.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('experto', 'experto', false, 157286400, array['application/zip', 'application/x-zip-compressed', 'application/octet-stream'])
on conflict (id) do update set file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.experto_enlaces (
  code        text primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  project_id  uuid not null references public.projects (id) on delete cascade,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '30 days',
  dia         date not null default current_date,
  preguntas   integer not null default 0,
  unique (user_id, project_id)
);
alter table public.experto_enlaces enable row level security;
-- Sin politicas: solo el servidor (funcion «experto») lo lee y lo escribe.

-- Codigo nuevo para un juego (el anterior deja de valer).
create or replace function public.experto_enlazar(p_user uuid, p_project uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
begin
  if not exists (select 1 from public.projects where id = p_project and user_id = p_user) then raise exception 'project_not_found'; end if;
  v_code := upper(substr(md5(gen_random_uuid()::text || clock_timestamp()::text), 1, 12));
  insert into public.experto_enlaces (code, user_id, project_id) values (v_code, p_user, p_project)
  on conflict (user_id, project_id) do update set code = excluded.code, created_at = now(),
    expires_at = now() + interval '30 days', dia = current_date, preguntas = 0;
  return v_code;
end;
$$;

-- Quien es el codigo (y cuenta una pregunta a Chispa si p_pregunta: 40 al dia por juego).
create or replace function public.experto_codigo(p_code text, p_pregunta boolean default false)
returns table (user_id uuid, project_id uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  e public.experto_enlaces%rowtype;
begin
  select * into e from public.experto_enlaces where code = upper(trim(coalesce(p_code, ''))) for update;
  if not found or e.expires_at < now() then raise exception 'bad_code'; end if;
  if p_pregunta then
    if e.dia <> current_date then
      update public.experto_enlaces set dia = current_date, preguntas = 1 where code = e.code;
    elsif e.preguntas >= 40 then
      raise exception 'daily_limit';
    else
      update public.experto_enlaces set preguntas = preguntas + 1 where code = e.code;
    end if;
  end if;
  return query select e.user_id, e.project_id;
end;
$$;

-- Encargar la version con lo subido. Se cobra como 'game_expert' y va a la fabrica como un cambio
-- (kind game_change con detail.experto: la ruta en el bucket «experto»).
create or replace function public.queue_expert(p_user uuid, p_project uuid, p_path text)
returns table (job_id uuid, credits_left integer, cost integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  if p_path is null or p_path not like (p_user::text || '/' || p_project::text || '/%.zip') or p_path like '%..%' then
    raise exception 'bad_path';
  end if;
  if not exists (select 1 from public.projects where id = p_project and user_id = p_user) then raise exception 'project_not_found'; end if;
  if exists (select 1 from public.jobs where project_id = p_project and status in ('queued', 'running')) then
    raise exception 'project_busy';
  end if;
  if not exists (select 1 from storage.objects where bucket_id = 'experto' and name = p_path) then raise exception 'not_uploaded'; end if;
  select * into r from public.reserve_job(p_user, 'game_expert',
    jsonb_build_object('experto', p_path, 'instruccion', 'Cambios hechos a mano en Godot'));
  update public.jobs set status = 'queued', project_id = p_project, kind = 'game_change' where id = r.job_id;
  return query select r.job_id, r.credits_left, r.cost;
end;
$$;

revoke all on function public.experto_enlazar(uuid, uuid) from public, anon, authenticated;
revoke all on function public.experto_codigo(text, boolean) from public, anon, authenticated;
revoke all on function public.queue_expert(uuid, uuid, text) from public, anon, authenticated;

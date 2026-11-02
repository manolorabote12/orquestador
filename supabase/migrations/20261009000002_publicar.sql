-- Orquestador: publicar en Google Play desde la app.
--
-- Flujo:
--   app -> play-setup({estudio, correo}): guarda los datos de publicacion del usuario.
--   app -> publish-game({project_id, modo, pista}): queue_publish encola (gratis, con tope diario).
--     modo 'primer_aab': el trabajador prepara el .aab firmado, la ficha, la politica de privacidad
--                        (publica, bucket 'legal') y la guia con cada dato para Play Console.
--     modo 'subir'     : el trabajador lo sube por la API de Google (cuenta de servicio de Orquestador).
--   trabajador -> complete_publish_job guarda el estado en projects.play y los archivos en files.publicar.
--
-- La llave de subida de cada usuario va cifrada en el bucket privado 'llaves' (solo el servidor).

-- ============ Precio ============

insert into public.pricing (kind, label, credits, max_per_day, est_cost_usd, enabled) values
  ('game_publish', 'Publicar en Google Play', 0, 10, 0.020, true)
on conflict (kind) do update
  set label = excluded.label, credits = excluded.credits, max_per_day = excluded.max_per_day,
      est_cost_usd = excluded.est_cost_usd, enabled = excluded.enabled;

-- ============ Datos de publicacion del usuario ============

create table if not exists public.play_cuentas (
  user_id       uuid primary key references public.profiles (id) on delete cascade,
  estudio       text not null check (char_length(estudio) between 2 and 40),
  correo        text not null check (correo ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  llave_huella  text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
alter table public.play_cuentas enable row level security;
create policy "ver mi cuenta de publicacion" on public.play_cuentas
  for select to authenticated using (user_id = auth.uid());

alter table public.projects add column if not exists play jsonb;

create or replace function public.save_play_account(p_user uuid, p_estudio text, p_correo text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.play_cuentas (user_id, estudio, correo) values (p_user, trim(p_estudio), lower(trim(p_correo)))
  on conflict (user_id) do update set estudio = excluded.estudio, correo = excluded.correo, updated_at = now();
end;
$$;

create or replace function public.set_play_key(p_user uuid, p_huella text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.play_cuentas set llave_huella = p_huella, updated_at = now() where user_id = p_user;
$$;

-- ============ Encolar ============

create or replace function public.queue_publish(p_user uuid, p_project uuid, p_modo text, p_pista text)
returns table (job_id uuid, credits_left integer, cost integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_cuenta public.play_cuentas%rowtype;
  v_play jsonb;
begin
  if p_modo not in ('primer_aab', 'subir') then raise exception 'bad_mode'; end if;
  if p_pista not in ('internal', 'alpha', 'beta', 'production') then raise exception 'bad_track'; end if;
  select * into v_cuenta from public.play_cuentas where user_id = p_user;
  if not found then raise exception 'play_setup_missing'; end if;
  select play into v_play from public.projects where id = p_project and user_id = p_user;
  if not found then raise exception 'project_not_found'; end if;
  if p_modo = 'subir' and coalesce(v_play ->> 'paquete', '') = '' then raise exception 'first_aab_missing'; end if;
  if exists (select 1 from public.jobs where project_id = p_project and status in ('queued', 'running')) then
    raise exception 'project_busy';
  end if;
  select * into r from public.reserve_job(p_user, 'game_publish', jsonb_build_object(
    'modo', p_modo, 'pista', p_pista, 'estudio', v_cuenta.estudio, 'correo', v_cuenta.correo,
    'paquete', v_play ->> 'paquete', 'version_code', coalesce((v_play ->> 'version_code')::int, 0)));
  update public.jobs set status = 'queued', project_id = p_project where id = r.job_id;
  return query select r.job_id, r.credits_left, r.cost;
end;
$$;

-- ============ Trabajador ============

create or replace function public.claim_game_job(p_worker text)
returns table (job_id uuid, user_id uuid, kind text, project_id uuid, idea text, detail jsonb, project_files jsonb, project_version integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  select j.id into v_id from public.jobs j
   where j.kind in ('game', 'game_change', 'game_restore', 'game_marketing', 'game_publish') and j.status = 'queued'
   order by j.created_at
   for update skip locked
   limit 1;
  if v_id is null then return; end if;
  update public.jobs set status = 'running', started_at = now(), worker = left(p_worker, 80) where id = v_id;
  return query
    select j.id, j.user_id, j.kind, j.project_id, j.detail ->> 'idea', j.detail, p.files, p.version
      from public.jobs j left join public.projects p on p.id = j.project_id
     where j.id = v_id;
end;
$$;

create or replace function public.complete_publish_job(p_job uuid, p_cost_usd numeric, p_play jsonb, p_files jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job public.jobs%rowtype;
begin
  select * into v_job from public.jobs where id = p_job and status = 'running' and kind = 'game_publish' for update;
  if not found then raise exception 'job_not_running'; end if;
  update public.projects
     set play = coalesce(play, '{}'::jsonb) || p_play,
         files = coalesce(files, '{}'::jsonb) || jsonb_build_object('publicar', p_files),
         updated_at = now()
   where id = v_job.project_id;
  update public.jobs set result = jsonb_build_object('publicar', p_files, 'play', p_play) where id = p_job;
  perform public.finish_job(p_job, p_cost_usd, null, null, 1);
end;
$$;

create or replace function public.expire_stuck_jobs()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  n integer := 0;
  largos text[] := array['game', 'game_change', 'game_restore', 'game_marketing', 'game_publish'];
begin
  for r in select id, est_cost_usd from public.jobs
            where status = 'running' and not (kind = any (largos))
              and created_at < now() - interval '10 minutes'
  loop
    perform public.fail_job(r.id, 'timeout', r.est_cost_usd, true);
    n := n + 1;
  end loop;
  for r in select id, est_cost_usd from public.jobs
            where status = 'running' and kind = any (largos)
              and started_at < now() - make_interval(mins => public.setting('game_timeout_minutes')::int)
  loop
    perform public.fail_job(r.id, 'timeout', r.est_cost_usd, true);
    n := n + 1;
  end loop;
  for r in select id, user_id, cost from public.jobs
            where status = 'queued'
              and created_at < now() - make_interval(mins => public.setting('queue_timeout_minutes')::int)
            for update skip locked
  loop
    if r.cost > 0 then
      update public.profiles set credits = credits + r.cost where id = r.user_id;
      insert into public.credit_ledger (user_id, amount, reason, ref) values (r.user_id, r.cost, 'refund', r.id::text);
    end if;
    update public.jobs set status = 'failed', finished_at = now(), error = 'queue_timeout',
           provider_cost_usd = 0, refunded = true
     where id = r.id;
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- ============ Almacenes ============

-- Politicas de privacidad: publicas (Google tiene que poder leerlas sin sesion). Nadie escribe salvo el servidor.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('legal', 'legal', true, 1048576, array['text/html'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "leer politicas" on storage.objects;
create policy "leer politicas" on storage.objects for select to anon, authenticated using (bucket_id = 'legal');

-- Llaves de subida cifradas: privadas del todo (sin politica de lectura: solo la clave de servicio).
insert into storage.buckets (id, name, public, file_size_limit)
values ('llaves', 'llaves', false, 65536)
on conflict (id) do update set public = false;

-- ============ Permisos ============

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.save_play_account(uuid, text, text)',
    'public.set_play_key(uuid, text)',
    'public.queue_publish(uuid, uuid, text, text)',
    'public.claim_game_job(text)',
    'public.complete_publish_job(uuid, numeric, jsonb, jsonb)',
    'public.expire_stuck_jobs()'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end;
$$;

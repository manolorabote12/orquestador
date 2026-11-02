-- Orquestador: trabajos de "juego completo" que hace la fábrica (trabajador en GPU/PC).
--
-- Flujo:
--   app -> función create-game -> queue_game() cobra y deja el trabajo en cola ('queued')
--   trabajador -> claim_game_job() lo toma ('running') -> job_progress() va contando el avance
--             -> complete_game_job() guarda proyecto, versión y archivos   (o fail_job: devuelve)
--   app -> lee su trabajo (progreso en vivo) y descarga APK y capturas con URLs firmadas.
--
-- El dinero sigue el mismo camino blindado de la economía: se cobra al encolar, el coste real
-- se guarda al terminar y los fallos nuestros se devuelven (con el tope diario).

-- ============ Precio ============

insert into public.pricing (kind, label, credits, max_per_day, est_cost_usd, enabled) values
  ('game', 'Juego completo (diseño, niveles, arte, sonido y APK)', 60, 5, 0.300, true)
on conflict (kind) do update
  set label = excluded.label, credits = excluded.credits, max_per_day = excluded.max_per_day,
      est_cost_usd = excluded.est_cost_usd, enabled = excluded.enabled;

-- El primer juego es gratis: la bienvenida cubre exactamente un juego completo.
update public.settings set value = 60, note = 'Créditos al verificar la cuenta (= un juego completo gratis)'
 where key = 'welcome_credits';

insert into public.settings (key, value, note) values
  ('game_timeout_minutes', 30, 'Un juego en marcha más tiempo que esto se da por fallido y se devuelve'),
  ('queue_timeout_minutes', 180, 'Un juego en cola más tiempo que esto (sin trabajador) se cancela y se devuelve')
on conflict (key) do nothing;

-- ============ Trabajos: cola, progreso y resultado ============

alter table public.jobs drop constraint if exists jobs_status_check;
alter table public.jobs add constraint jobs_status_check
  check (status in ('queued', 'running', 'done', 'failed'));

alter table public.jobs
  add column if not exists started_at  timestamptz,
  add column if not exists worker      text,
  add column if not exists progress    jsonb not null default '[]'::jsonb,
  add column if not exists result      jsonb,
  add column if not exists project_id  uuid references public.projects (id) on delete set null;

create index if not exists jobs_queue_idx on public.jobs (created_at) where status = 'queued';

-- ============ Encolar (lo llama create-game con la sesión ya comprobada) ============

create or replace function public.queue_game(p_user uuid, p_idea text)
returns table (job_id uuid, credits_left integer, cost integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  if char_length(coalesce(p_idea, '')) not between 15 and 600 then
    raise exception 'bad_idea';
  end if;
  select * into r from public.reserve_job(p_user, 'game', jsonb_build_object('idea', p_idea));
  update public.jobs set status = 'queued' where id = r.job_id;
  return query select r.job_id, r.credits_left, r.cost;
end;
$$;

-- ============ Trabajador ============

-- Toma el trabajo más antiguo de la cola. SKIP LOCKED: varios trabajadores a la vez sin pisarse.
create or replace function public.claim_game_job(p_worker text)
returns table (job_id uuid, user_id uuid, idea text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  select id into v_id from public.jobs
   where kind = 'game' and status = 'queued'
   order by created_at
   for update skip locked
   limit 1;
  if v_id is null then return; end if;
  update public.jobs set status = 'running', started_at = now(), worker = left(p_worker, 80)
   where id = v_id;
  return query select j.id, j.user_id, j.detail ->> 'idea' from public.jobs j where j.id = v_id;
end;
$$;

-- Añade un evento de progreso (lo que Chispa cuenta en vivo). Se guardan los últimos 60.
create or replace function public.job_progress(p_job uuid, p_event jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.jobs
     set progress = (
       select coalesce(jsonb_agg(e order by n), '[]'::jsonb)
         from (select e, n from jsonb_array_elements(progress || jsonb_build_array(p_event)) with ordinality as t(e, n)
               order by n desc limit 60) last
     )
   where id = p_job and status = 'running';
end;
$$;

-- Cierra con éxito: crea el proyecto (o nueva versión), guarda los archivos y el coste real.
create or replace function public.complete_game_job(
  p_job uuid, p_cost_usd numeric, p_units numeric, p_title text, p_spec jsonb, p_files jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job     public.jobs%rowtype;
  v_project uuid;
begin
  select * into v_job from public.jobs where id = p_job and status = 'running' for update;
  if not found then raise exception 'job_not_running'; end if;
  insert into public.projects (user_id, title, spec)
  values (v_job.user_id, left(p_title, 60), p_spec)
  returning id into v_project;
  insert into public.project_versions (project_id, version, spec, prompt)
  values (v_project, 1, p_spec, coalesce(v_job.detail ->> 'idea', ''));
  update public.jobs set result = p_files, project_id = v_project where id = p_job;
  perform public.finish_job(p_job, p_cost_usd, null, null, p_units);
  return v_project;
end;
$$;

-- fail_job también acepta trabajos en cola (cancelados por tiempo sin trabajador).
create or replace function public.fail_job(
  p_job uuid, p_error text, p_cost_usd numeric default null, p_refund boolean default true)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job      public.jobs%rowtype;
  v_refunds  integer;
  v_refund   boolean := false;
begin
  select * into v_job from public.jobs where id = p_job and status in ('queued', 'running') for update;
  if not found then raise exception 'job_not_running'; end if;

  if p_refund and v_job.cost > 0 then
    select count(*) into v_refunds from public.jobs
     where user_id = v_job.user_id and refunded and coalesce(error, '') <> 'queue_timeout'
       and created_at >= date_trunc('day', now());
    if v_refunds < public.setting('max_refunds_per_day') then
      update public.profiles set credits = credits + v_job.cost where id = v_job.user_id;
      insert into public.credit_ledger (user_id, amount, reason, ref)
      values (v_job.user_id, v_job.cost, 'refund', v_job.id::text);
      v_refund := true;
    end if;
  end if;

  update public.jobs
     set status = 'failed', finished_at = now(), error = left(p_error, 500),
         provider_cost_usd = coalesce(p_cost_usd, 0), refunded = v_refund
   where id = p_job;

  return v_refund;
end;
$$;

-- Caducidad: los rápidos a los 10 minutos; los juegos según sus propios ajustes.
-- Un juego en cola sin trabajador no le cuesta nada al usuario: se le devuelve siempre.
create or replace function public.expire_stuck_jobs()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  n integer := 0;
begin
  for r in select id, est_cost_usd from public.jobs
            where status = 'running' and kind <> 'game' and created_at < now() - interval '10 minutes'
  loop
    perform public.fail_job(r.id, 'timeout', r.est_cost_usd, true);
    n := n + 1;
  end loop;
  for r in select id, est_cost_usd from public.jobs
            where status = 'running' and kind = 'game'
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
    -- Sin trabajador no ha sido culpa suya: se devuelve siempre y no gasta sus devoluciones del dia.
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

-- ============ Archivos de los juegos (APK, capturas, informe) ============

insert into storage.buckets (id, name, public, file_size_limit)
values ('juegos', 'juegos', false, 104857600)
on conflict (id) do nothing;

-- Ruta: <user_id>/<project_id>/<archivo>. Cada usuario solo ve lo suyo; escribe el servidor.
drop policy if exists "ver mis archivos de juegos" on storage.objects;
create policy "ver mis archivos de juegos" on storage.objects
  for select to authenticated
  using (bucket_id = 'juegos' and (storage.foldername(name))[1] = auth.uid()::text);

-- ============ Permisos ============

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.queue_game(uuid, text)',
    'public.claim_game_job(text)',
    'public.job_progress(uuid, jsonb)',
    'public.complete_game_job(uuid, numeric, numeric, text, jsonb, jsonb)',
    'public.fail_job(uuid, text, numeric, boolean)',
    'public.expire_stuck_jobs()'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end;
$$;

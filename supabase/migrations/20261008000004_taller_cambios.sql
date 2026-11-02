-- Orquestador: taller por instrucciones (cambios sobre un juego ya fabricado) y versiones.
--
-- Flujo:
--   app -> plan-change: la IA propone un plan; el SERVIDOR calcula su coste y lo guarda (change_plans).
--   app -> apply-change(plan_id): queue_change cobra EXACTAMENTE ese coste y encola el cambio.
--   trabajador -> claim_game_job (ahora tambien cambios y restauraciones) -> complete_change_job
--             crea la version nueva del proyecto con sus archivos (o fail_job devuelve).
--   app -> restore-version: queue_restore encola volver a una version (gratis, con tope diario).

-- ============ Precios ============

insert into public.pricing (kind, label, credits, max_per_day, est_cost_usd, enabled) values
  ('plan',         'Chispa propone un cambio',                0, 80, 0.004, true),
  ('game_change',  'Aplicar un cambio (precio según el plan)', 0, 40, 0.060, true),
  ('game_restore', 'Volver a una versión anterior',           0, 15, 0.010, true)
on conflict (kind) do update
  set label = excluded.label, credits = excluded.credits, max_per_day = excluded.max_per_day,
      est_cost_usd = excluded.est_cost_usd, enabled = excluded.enabled;

-- Bienvenida: un juego completo y un par de cambios para probar el taller.
update public.settings set value = 90, note = 'Créditos al verificar la cuenta (= un juego completo + un par de cambios)'
 where key = 'welcome_credits';

insert into public.settings (key, value, note) values
  ('plan_minutes', 30, 'Minutos que vale un plan propuesto antes de caducar')
on conflict (key) do nothing;

-- ============ Planes propuestos ============

create table public.change_plans (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  project_id  uuid not null references public.projects (id) on delete cascade,
  instruction text not null check (char_length(instruction) between 2 and 400),
  plan        jsonb not null,
  credits     integer not null check (credits >= 0),
  used        boolean not null default false,
  created_at  timestamptz not null default now()
);
create index change_plans_project_idx on public.change_plans (project_id, created_at desc);

alter table public.change_plans enable row level security;
create policy "ver mis planes" on public.change_plans
  for select to authenticated using (user_id = auth.uid());

-- ============ Archivos por version y del proyecto ============

alter table public.project_versions add column if not exists files jsonb;
alter table public.projects add column if not exists files jsonb;

-- El primer juego ya guarda sus archivos en la version 1 y en el proyecto.
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
  insert into public.projects (user_id, title, spec, files)
  values (v_job.user_id, left(p_title, 60), p_spec, p_files)
  returning id into v_project;
  insert into public.project_versions (project_id, version, spec, prompt, files)
  values (v_project, 1, p_spec, coalesce(v_job.detail ->> 'idea', ''), p_files);
  update public.jobs set result = p_files, project_id = v_project where id = p_job;
  perform public.finish_job(p_job, p_cost_usd, null, null, p_units);
  return v_project;
end;
$$;

-- ============ Encolar un cambio con el coste del plan ============

create or replace function public.queue_change(p_user uuid, p_plan uuid)
returns table (job_id uuid, credits_left integer, cost integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan    public.change_plans%rowtype;
  v_credits integer;
  r         record;
begin
  select * into v_plan from public.change_plans where id = p_plan and user_id = p_user for update;
  if not found then raise exception 'plan_not_found'; end if;
  if v_plan.used then raise exception 'plan_used'; end if;
  if v_plan.created_at < now() - make_interval(mins => public.setting('plan_minutes')::int) then
    raise exception 'plan_expired';
  end if;
  if jsonb_array_length(coalesce(v_plan.plan -> 'operaciones', '[]'::jsonb)) = 0 then
    raise exception 'plan_empty';
  end if;
  if exists (select 1 from public.jobs where project_id = v_plan.project_id and status in ('queued', 'running')) then
    raise exception 'project_busy';
  end if;

  -- Límites, presupuesto y bloqueo del perfil (precio base 0) ...
  select * into r from public.reserve_job(p_user, 'game_change',
    jsonb_build_object('plan_id', v_plan.id, 'plan', v_plan.plan, 'instruccion', v_plan.instruction));
  -- ... y el cobro exacto del plan, en la misma transacción.
  select credits into v_credits from public.profiles where id = p_user;
  if v_credits < v_plan.credits then raise exception 'insufficient_credits'; end if;
  if v_plan.credits > 0 then
    update public.profiles set credits = credits - v_plan.credits where id = p_user returning credits into v_credits;
    insert into public.credit_ledger (user_id, amount, reason, ref)
    values (p_user, -v_plan.credits, 'game_change', r.job_id::text);
  end if;
  update public.jobs set status = 'queued', cost = v_plan.credits, project_id = v_plan.project_id where id = r.job_id;
  update public.change_plans set used = true where id = v_plan.id;
  return query select r.job_id, v_credits, v_plan.credits;
end;
$$;

-- ============ Encolar volver a una version ============

create or replace function public.queue_restore(p_user uuid, p_project uuid, p_version integer)
returns table (job_id uuid, credits_left integer, cost integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  if not exists (select 1 from public.projects where id = p_project and user_id = p_user) then
    raise exception 'project_not_found';
  end if;
  if not exists (select 1 from public.project_versions where project_id = p_project and version = p_version) then
    raise exception 'version_not_found';
  end if;
  if exists (select 1 from public.jobs where project_id = p_project and status in ('queued', 'running')) then
    raise exception 'project_busy';
  end if;
  select * into r from public.reserve_job(p_user, 'game_restore', jsonb_build_object('version', p_version));
  update public.jobs set status = 'queued', project_id = p_project where id = r.job_id;
  return query select r.job_id, r.credits_left, r.cost;
end;
$$;

-- ============ Trabajador: toma juegos, cambios y restauraciones ============

drop function if exists public.claim_game_job(text);
create function public.claim_game_job(p_worker text)
returns table (job_id uuid, user_id uuid, kind text, project_id uuid, idea text, detail jsonb, project_files jsonb, project_version integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  select j.id into v_id from public.jobs j
   where j.kind in ('game', 'game_change', 'game_restore') and j.status = 'queued'
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

-- Cierra un cambio o una restauración: versión nueva del proyecto con sus archivos.
create or replace function public.complete_change_job(
  p_job uuid, p_cost_usd numeric, p_units numeric, p_title text, p_spec jsonb, p_files jsonb, p_version integer)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job public.jobs%rowtype;
  v_prompt text;
begin
  select * into v_job from public.jobs where id = p_job and status = 'running' for update;
  if not found then raise exception 'job_not_running'; end if;
  if v_job.project_id is null then raise exception 'job_without_project'; end if;
  if exists (select 1 from public.project_versions where project_id = v_job.project_id and version = p_version) then
    raise exception 'version_exists';
  end if;
  v_prompt := case v_job.kind
    when 'game_restore' then 'Volver a la versión ' || (v_job.detail ->> 'version')
    else coalesce(v_job.detail ->> 'instruccion', '') end;
  insert into public.project_versions (project_id, version, spec, prompt, files)
  values (v_job.project_id, p_version, p_spec, v_prompt, p_files);
  update public.projects
     set title = left(p_title, 60), spec = p_spec, version = p_version, files = p_files, updated_at = now()
   where id = v_job.project_id;
  update public.jobs set result = p_files where id = p_job;
  perform public.finish_job(p_job, p_cost_usd, null, null, p_units);
  return p_version;
end;
$$;

-- Los cambios en marcha caducan como los juegos.
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
            where status = 'running' and kind not in ('game', 'game_change', 'game_restore')
              and created_at < now() - interval '10 minutes'
  loop
    perform public.fail_job(r.id, 'timeout', r.est_cost_usd, true);
    n := n + 1;
  end loop;
  for r in select id, est_cost_usd from public.jobs
            where status = 'running' and kind in ('game', 'game_change', 'game_restore')
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

-- ============ Permisos ============

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.complete_game_job(uuid, numeric, numeric, text, jsonb, jsonb)',
    'public.queue_change(uuid, uuid)',
    'public.queue_restore(uuid, uuid, integer)',
    'public.claim_game_job(text)',
    'public.complete_change_job(uuid, numeric, numeric, text, jsonb, jsonb, integer)',
    'public.expire_stuck_jobs()'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end;
$$;

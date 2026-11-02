-- Orquestador: estudio de marketing con IA (3 clips para TikTok, Shorts y Reels por juego).
--
-- Flujo:
--   app -> create-marketing(project_id): queue_marketing cobra el precio fijo y encola.
--   trabajador -> claim_game_job (ahora tambien 'game_marketing') -> fabrica/marketing/estudio.py
--             -> complete_marketing_job guarda los videos y textos en projects.files.marketing
--             y en la version actual (o fail_job devuelve).

-- ============ Precio ============
-- Coste real: guion con Claude (modelo barato, ~0,01 $) + voz en off de 3 guiones
-- (ElevenLabs ~0,10 $; con Piper, 0 $) + GPU/CPU del trabajador. 20 tuercas lo cubren de sobra.

insert into public.pricing (kind, label, credits, max_per_day, est_cost_usd, enabled) values
  ('game_marketing', 'Vídeos para redes con IA (3 clips)', 20, 6, 0.150, true)
on conflict (kind) do update
  set label = excluded.label, credits = excluded.credits, max_per_day = excluded.max_per_day,
      est_cost_usd = excluded.est_cost_usd, enabled = excluded.enabled;

-- ============ Encolar ============

create or replace function public.queue_marketing(p_user uuid, p_project uuid)
returns table (job_id uuid, credits_left integer, cost integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_version integer;
begin
  select version into v_version from public.projects where id = p_project and user_id = p_user;
  if not found then raise exception 'project_not_found'; end if;
  if exists (select 1 from public.jobs where project_id = p_project and status in ('queued', 'running')) then
    raise exception 'project_busy';
  end if;
  select * into r from public.reserve_job(p_user, 'game_marketing', jsonb_build_object('version', v_version));
  update public.jobs set status = 'queued', project_id = p_project where id = r.job_id;
  return query select r.job_id, r.credits_left, r.cost;
end;
$$;

-- ============ Trabajador: tambien toma los de marketing ============

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
   where j.kind in ('game', 'game_change', 'game_restore', 'game_marketing') and j.status = 'queued'
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

-- Guarda los videos en el proyecto y en su version actual (no crea version nueva: el juego no cambia).
create or replace function public.complete_marketing_job(p_job uuid, p_cost_usd numeric, p_files jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job public.jobs%rowtype;
  v_version integer;
begin
  select * into v_job from public.jobs where id = p_job and status = 'running' and kind = 'game_marketing' for update;
  if not found then raise exception 'job_not_running'; end if;
  update public.projects
     set files = coalesce(files, '{}'::jsonb) || jsonb_build_object('marketing', p_files), updated_at = now()
   where id = v_job.project_id
  returning version into v_version;
  update public.project_versions
     set files = coalesce(files, '{}'::jsonb) || jsonb_build_object('marketing', p_files)
   where project_id = v_job.project_id and version = v_version;
  update public.jobs set result = jsonb_build_object('marketing', p_files) where id = p_job;
  perform public.finish_job(p_job, p_cost_usd, null, null, 3);
end;
$$;

-- ============ Caducidad: marketing cuenta como trabajo largo ============

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
            where status = 'running' and kind not in ('game', 'game_change', 'game_restore', 'game_marketing')
              and created_at < now() - interval '10 minutes'
  loop
    perform public.fail_job(r.id, 'timeout', r.est_cost_usd, true);
    n := n + 1;
  end loop;
  for r in select id, est_cost_usd from public.jobs
            where status = 'running' and kind in ('game', 'game_change', 'game_restore', 'game_marketing')
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
    'public.queue_marketing(uuid, uuid)',
    'public.claim_game_job(text)',
    'public.complete_marketing_job(uuid, numeric, jsonb)',
    'public.expire_stuck_jobs()'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end;
$$;

-- Orquestador: el agente programador (cambios que el taller no sabe hacer, programados como mods).
--
-- El usuario pide algo nuevo ("que suelte chispas al saltar"); si el planificador del taller no lo
-- sabe hacer, la app ofrece "Que Chispa lo programe". Claude escribe un mod, la fabrica lo revisa,
-- lo compila, lo juega con bots y solo entonces crea la version nueva (con volver atras, como siempre).

insert into public.pricing (kind, label, credits, max_per_day, est_cost_usd, enabled) values
  ('game_mod', 'Programar un cambio nuevo (agente programador)', 30, 10, 0.200, true)
on conflict (kind) do update set label = excluded.label, credits = excluded.credits, est_cost_usd = excluded.est_cost_usd,
  enabled = excluded.enabled;

create or replace function public.queue_mod(p_user uuid, p_project uuid, p_instruccion text)
returns table (job_id uuid, credits_left integer, cost integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  p_instruccion := trim(coalesce(p_instruccion, ''));
  if length(p_instruccion) < 8 or length(p_instruccion) > 400 then raise exception 'bad_instruction'; end if;
  if not exists (select 1 from public.projects where id = p_project and user_id = p_user) then raise exception 'project_not_found'; end if;
  if exists (select 1 from public.jobs where project_id = p_project and status in ('queued', 'running')) then
    raise exception 'project_busy';
  end if;
  select * into r from public.reserve_job(p_user, 'game_mod', jsonb_build_object('instruccion', p_instruccion));
  update public.jobs set status = 'queued', project_id = p_project where id = r.job_id;
  return query select r.job_id, r.credits_left, r.cost;
end;
$$;

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
   where j.kind in ('game', 'game_change', 'game_restore', 'game_marketing', 'game_publish', 'game_mod') and j.status = 'queued'
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

create or replace function public.expire_stuck_jobs()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  n integer := 0;
  largos text[] := array['game', 'game_change', 'game_restore', 'game_marketing', 'game_publish', 'game_ios', 'game_mod'];
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

revoke all on function public.queue_mod(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.queue_mod(uuid, uuid, text) to service_role;

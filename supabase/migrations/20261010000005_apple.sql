-- Orquestador: publicar en la App Store de Apple.
--
-- Apple solo compila en Mac: el trabajo 'game_ios' NO lo coge la fabrica de RunPod; lo hace un Mac
-- en la nube de GitHub Actions (.github/workflows/ios.yml), que la funcion publish-ios lanza.
-- El usuario pone una vez su equipo de Apple y una clave de la API de App Store Connect (.p8);
-- la clave se guarda CIFRADA (AES-GCM) en el almacen privado 'llaves' y solo la descifra el Mac.

insert into public.pricing (kind, label, credits, max_per_day, est_cost_usd, enabled) values
  ('game_ios', 'Publicar en la App Store', 0, 5, 0.300, true)
on conflict (kind) do update set label = excluded.label, est_cost_usd = excluded.est_cost_usd, enabled = excluded.enabled;

create table if not exists public.apple_cuentas (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  equipo     text not null,
  clave_id   text not null,
  emisor     text not null,
  clave_ruta text not null,
  updated_at timestamptz not null default now()
);
alter table public.apple_cuentas enable row level security;
create policy "ver mi cuenta de apple" on public.apple_cuentas for select to authenticated using (user_id = auth.uid());
-- (la app ve equipo e ids para mostrarlos; la clave .p8 nunca sale del almacen privado)

alter table public.projects add column if not exists ios jsonb;

create or replace function public.save_apple_account(p_user uuid, p_equipo text, p_clave_id text, p_emisor text, p_ruta text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_equipo !~ '^[A-Z0-9]{10}$' then raise exception 'bad_team'; end if;
  if p_clave_id !~ '^[A-Z0-9]{10}$' then raise exception 'bad_key_id'; end if;
  if p_emisor !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then raise exception 'bad_issuer'; end if;
  insert into public.apple_cuentas (user_id, equipo, clave_id, emisor, clave_ruta) values (p_user, p_equipo, p_clave_id, p_emisor, p_ruta)
  on conflict (user_id) do update set equipo = excluded.equipo, clave_id = excluded.clave_id, emisor = excluded.emisor,
    clave_ruta = excluded.clave_ruta, updated_at = now();
end;
$$;

create or replace function public.queue_ios(p_user uuid, p_project uuid)
returns table (job_id uuid, credits_left integer, cost integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_apple public.apple_cuentas%rowtype;
  v_p public.projects%rowtype;
  v_cuenta public.play_cuentas%rowtype;
  v_bundle text;
begin
  select * into v_apple from public.apple_cuentas where user_id = p_user;
  if not found then raise exception 'apple_setup_missing'; end if;
  select * into v_p from public.projects where id = p_project and user_id = p_user;
  if not found then raise exception 'project_not_found'; end if;
  if exists (select 1 from public.jobs where project_id = p_project and status in ('queued', 'running')) then
    raise exception 'project_busy';
  end if;
  -- Mismo identificador que en Google Play si ya existe; si no, se deriva del estudio y del titulo.
  select * into v_cuenta from public.play_cuentas where user_id = p_user;
  v_bundle := coalesce(v_p.ios ->> 'bundle', v_p.play ->> 'paquete');
  select * into r from public.reserve_job(p_user, 'game_ios', jsonb_build_object(
    'equipo', v_apple.equipo, 'clave_id', v_apple.clave_id, 'emisor', v_apple.emisor, 'clave_ruta', v_apple.clave_ruta,
    'bundle', v_bundle, 'estudio', coalesce(v_cuenta.estudio, ''), 'build', coalesce((v_p.ios ->> 'build')::int, 0) + 1));
  -- 'en_mac': no lo coge claim_game_job (solo lo atiende el Mac de GitHub con claim_ios_job).
  update public.jobs set status = 'queued', project_id = p_project where id = r.job_id;
  return query select r.job_id, r.credits_left, r.cost;
end;
$$;

-- El Mac de GitHub toma SU trabajo (por id) y recibe lo necesario para compilar.
create or replace function public.claim_ios_job(p_job uuid, p_worker text)
returns table (job_id uuid, user_id uuid, project_id uuid, detail jsonb, project_files jsonb, project_version integer, titulo text)
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.jobs set status = 'running', started_at = now(), worker = left(p_worker, 80)
   where id = p_job and kind = 'game_ios' and status = 'queued';
  if not found then raise exception 'job_not_queued'; end if;
  return query
    select j.id, j.user_id, j.project_id, j.detail, p.files, p.version, p.title
      from public.jobs j join public.projects p on p.id = j.project_id where j.id = p_job;
end;
$$;

create or replace function public.complete_ios_job(p_job uuid, p_cost_usd numeric, p_ios jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job public.jobs%rowtype;
begin
  select * into v_job from public.jobs where id = p_job and status = 'running' and kind = 'game_ios' for update;
  if not found then raise exception 'job_not_running'; end if;
  update public.projects set ios = coalesce(ios, '{}'::jsonb) || p_ios, updated_at = now() where id = v_job.project_id;
  update public.jobs set result = jsonb_build_object('ios', p_ios) where id = p_job;
  perform public.finish_job(p_job, p_cost_usd, null, null, 1);
end;
$$;

-- La fabrica de RunPod no debe coger trabajos de Mac.
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

-- Compilar en Mac tarda: entra en la lista de trabajos largos.
create or replace function public.expire_stuck_jobs()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  n integer := 0;
  largos text[] := array['game', 'game_change', 'game_restore', 'game_marketing', 'game_publish', 'game_ios'];
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

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.save_apple_account(uuid, text, text, text, text)',
    'public.queue_ios(uuid, uuid)',
    'public.claim_ios_job(uuid, text)',
    'public.complete_ios_job(uuid, numeric, jsonb)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end;
$$;

-- Vigilante y boton de parada (noviembre de 2026): que un susto de gasto no pueda durar horas.
--
-- 1 - fabrica_pausada (0/1): con 1 no se aceptan trabajos nuevos de la fabrica (el jugador ve
--     "la fabrica esta a tope, no se te ha cobrado nada"), no se empieza nada de la cola y lo que
--     este en marcha se para en su siguiente paso (y se devuelve). Se pone y se quita con
--     pausar_fabrica(), desde el workflow "Fabrica: pausar o reanudar" o el vigilante del Reloj.
-- 2 - vigilancia(): en una sola llamada lo que mira el vigilante cada 15 minutos (gasto de la
--     ultima hora y del dia, trabajos caros, fallos, cola) para avisar y pausar si algo se dispara.

insert into public.settings (key, value, note) values
  ('fabrica_pausada', 0, '1 = fabrica parada: ni trabajos nuevos ni de la cola; lo que este en marcha para y se devuelve')
on conflict (key) do nothing;

create or replace function public.fabrica_pausada()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce((select value from public.settings where key = 'fabrica_pausada'), 0) >= 1
$$;

-- 1a - Sin trabajos nuevos de la fabrica mientras este pausada (reserve_job falla y no cobra nada).
create or replace function public.parar_si_pausada()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.kind like 'game%' and public.fabrica_pausada() then
    raise exception 'budget_exceeded';
  end if;
  return new;
end;
$$;

revoke all on function public.parar_si_pausada() from public, anon, authenticated;
revoke all on function public.fabrica_pausada() from public, anon;

drop trigger if exists parar_si_pausada on public.jobs;
create trigger parar_si_pausada before insert on public.jobs
  for each row execute function public.parar_si_pausada();

-- 1b - La fabrica no coge nada de la cola mientras este pausada.
create or replace function public.claim_game_job(p_worker text)
returns table (job_id uuid, user_id uuid, kind text, project_id uuid, idea text, detail jsonb, project_files jsonb, project_version integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if public.fabrica_pausada() then return; end if;
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

revoke all on function public.claim_game_job(text) from public, anon, authenticated;
grant execute on function public.claim_game_job(text) to service_role;

-- 1c - Lo que este en marcha se entera en su siguiente paso (la fabrica para, falla y devuelve).
create or replace function public.job_progress(p_job uuid, p_event jsonb)
returns boolean
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
  -- false: el trabajo ya no esta en marcha (caducado o cerrado) o la fabrica esta pausada.
  return found and not public.fabrica_pausada();
end;
$$;

revoke all on function public.job_progress(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.job_progress(uuid, jsonb) to service_role;

create or replace function public.pausar_fabrica(p_pausa boolean, p_motivo text default null)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.settings
     set value = case when p_pausa then 1 else 0 end,
         note = case when p_pausa then 'PARADA ' || to_char(now(), 'YYYY-MM-DD HH24:MI') || ' UTC: ' || coalesce(left(p_motivo, 200), 'a mano')
                     else '1 = fabrica parada: ni trabajos nuevos ni de la cola; lo que este en marcha para y se devuelve' end
   where key = 'fabrica_pausada';
  return p_pausa;
end;
$$;

revoke all on function public.pausar_fabrica(boolean, text) from public, anon, authenticated;
grant execute on function public.pausar_fabrica(boolean, text) to service_role;

-- 2 - Lo que mira el vigilante. Coste: el real de lo cerrado y el estimado de lo que sigue en marcha.
create or replace function public.vigilancia(p_caro_usd numeric default 0.8, p_minutos integer default 20)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'pausada', public.fabrica_pausada(),
    'nota_pausa', (select note from public.settings where key = 'fabrica_pausada'),
    'hora_usd', (select round(coalesce(sum(coalesce(provider_cost_usd, est_cost_usd, 0)), 0), 3) from public.jobs
                  where created_at > now() - interval '1 hour' or (finished_at > now() - interval '1 hour')),
    'dia_usd', (select round(coalesce(sum(coalesce(provider_cost_usd, est_cost_usd, 0)), 0), 3) from public.jobs
                 where created_at >= date_trunc('day', now())),
    'presupuesto_dia_usd', public.setting('daily_budget_usd'),
    'en_marcha', (select count(*) from public.jobs where status = 'running'),
    'en_cola', (select count(*) from public.jobs where status = 'queued'),
    'juegos_dia', (select count(*) from public.jobs where kind like 'game%' and created_at >= date_trunc('day', now())),
    'fallidos_dia', (select count(*) from public.jobs where kind like 'game%' and status = 'failed' and created_at >= date_trunc('day', now())),
    'caros', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'kind', kind, 'usd', provider_cost_usd, 'status', status)), '[]'::jsonb)
                from public.jobs
               where provider_cost_usd >= p_caro_usd and finished_at > now() - make_interval(mins => p_minutos)),
    'fallos_recientes', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'kind', kind, 'error', left(error, 160), 'usd', provider_cost_usd)), '[]'::jsonb)
                from public.jobs
               where status = 'failed' and kind like 'game%' and finished_at > now() - make_interval(mins => p_minutos))
  )
$$;

revoke all on function public.vigilancia(numeric, integer) from public, anon, authenticated;
grant execute on function public.vigilancia(numeric, integer) to service_role;

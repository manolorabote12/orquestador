-- Vista previa gratis del diseno (10 de noviembre de 2026): ver el juego ANTES de pagar.
--
--   app -> create-game { idea, preview: true } -> queue_preview() (0 tuercas, en cola)
--   fabrica -> claim_game_job() la toma ANTES que los juegos (tarda un minuto) -> solo el diseno
--           -> complete_preview_job() deja el diseno en jobs.result.diseno
--   app -> ensena titulo, genero, heroe, enemigos y niveles -> «Fabricar este juego»
--       -> create-game { idea, preview_id } -> queue_game() cobra y encola con ESE diseno
--       -> la fabrica no vuelve a disenar: lo que viste es lo que se fabrica.
--
-- Cuesta ~0,01 $ (IA barata + un minuto de CPU). Limite: 15 al dia por persona.

insert into public.pricing (kind, label, credits, max_per_day, est_cost_usd, enabled) values
  ('game_preview', 'Vista previa del diseno (gratis)', 0, 15, 0.0100, true)
on conflict (kind) do update
  set label = excluded.label, credits = excluded.credits, max_per_day = excluded.max_per_day,
      est_cost_usd = excluded.est_cost_usd, enabled = excluded.enabled;

create or replace function public.queue_preview(p_user uuid, p_idea text)
returns table (job_id uuid, credits_left integer, cost integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  if char_length(coalesce(p_idea, '')) not between 15 and 700 then
    raise exception 'bad_idea';
  end if;
  select * into r from public.reserve_job(p_user, 'game_preview', jsonb_build_object('idea', p_idea));
  update public.jobs set status = 'queued' where id = r.job_id;
  return query select r.job_id, r.credits_left, r.cost;
end;
$$;

revoke all on function public.queue_preview(uuid, text) from public, anon, authenticated;
grant execute on function public.queue_preview(uuid, text) to service_role;

-- queue_game acepta una vista previa: el juego se fabrica con ESE diseno (el de la vista previa
-- es de esta persona, esta terminada y tiene menos de 2 dias). Sin vista previa, como siempre.
drop function if exists public.queue_game(uuid, text);
create or replace function public.queue_game(p_user uuid, p_idea text, p_preview uuid default null)
returns table (job_id uuid, credits_left integer, cost integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_detalle jsonb := jsonb_build_object('idea', p_idea);
  v_diseno jsonb;
begin
  if char_length(coalesce(p_idea, '')) not between 15 and 700 then
    raise exception 'bad_idea';
  end if;
  if p_preview is not null then
    select result -> 'diseno' into v_diseno from public.jobs
     where id = p_preview and user_id = p_user and kind = 'game_preview' and status = 'done'
       and created_at > now() - interval '2 days';
    if v_diseno is null or jsonb_typeof(v_diseno) <> 'object' then raise exception 'bad_preview'; end if;
    v_detalle := v_detalle || jsonb_build_object('diseno', v_diseno, 'preview', p_preview);
  end if;
  select * into r from public.reserve_job(p_user, 'game', v_detalle);
  update public.jobs set status = 'queued' where id = r.job_id;
  return query select r.job_id, r.credits_left, r.cost;
end;
$$;

revoke all on function public.queue_game(uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.queue_game(uuid, text, uuid) to service_role;

-- La fabrica coge primero las vistas previas (un minuto) para que nadie espere detras de un juego.
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
   where j.kind in ('game', 'game_change', 'game_restore', 'game_marketing', 'game_publish', 'game_mod', 'game_preview')
     and j.status = 'queued'
   order by (j.kind = 'game_preview') desc, j.created_at
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

create or replace function public.complete_preview_job(p_job uuid, p_spec jsonb, p_cost_usd numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_spec is null or jsonb_typeof(p_spec) <> 'object' then raise exception 'bad_spec'; end if;
  update public.jobs set result = jsonb_build_object('diseno', p_spec)
   where id = p_job and kind = 'game_preview' and status = 'running';
  if not found then raise exception 'job_not_running'; end if;
  perform public.finish_job(p_job, p_cost_usd, null, null, 0);
end;
$$;

revoke all on function public.complete_preview_job(uuid, jsonb, numeric) from public, anon, authenticated;
grant execute on function public.complete_preview_job(uuid, jsonb, numeric) to service_role;

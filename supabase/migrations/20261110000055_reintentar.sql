-- Reintentar sin volver a pagar el arte (10 de noviembre de 2026).
--
-- Si un juego falla, la fabrica deja su diseno en el trabajo (guardar_diseno). «Reintentar» en la app
-- encola un juego nuevo con ESE diseno (queue_game con p_preview = el trabajo fallido): la biblia sale
-- igual, asi que la fabrica recupera el arte de su cache en vez de volver a dibujarlo (GPU = 0).

create or replace function public.guardar_diseno(p_job uuid, p_spec jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_spec is null or jsonb_typeof(p_spec) <> 'object' then return; end if;
  update public.jobs set result = coalesce(result, '{}'::jsonb) || jsonb_build_object('diseno', p_spec)
   where id = p_job and kind = 'game' and status = 'running';
end;
$$;

revoke all on function public.guardar_diseno(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.guardar_diseno(uuid, jsonb) to service_role;

-- La vista previa puede ser tambien un juego fallido de la misma persona (de menos de 2 dias).
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
     where id = p_preview and user_id = p_user
       and ((kind = 'game_preview' and status = 'done') or (kind = 'game' and status = 'failed'))
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

-- Juego a medida (23 de noviembre de 2026): el Agente Estudio crea el juego entero desde la idea y
-- una entrevista corta, sin plantilla (fabrica/libre/agente.py). Daniel: «nada de plantillas, salen
-- genéricos; que el usuario vea cómo se va montando y pueda jugar mientras pide cosas».
--
--   app -> create-game { idea, modo: "libre", entrevista: {...} } -> queue_libre()
--       -> cobra el precio de 'game_libre' y deja el trabajo como 'game' con detail.modo = 'libre'
--          (así lo toman claim_game_job, job_progress y complete_game_job de siempre)
--   fabrica -> trabajador.atender_libre: el agente programa, pinta, prueba y juega con su bot;
--              cada paso llega a la app (texto, fotos del arte y de las pruebas, boceto jugable).
--
-- Precio y tope diario: en public.pricing ('game_libre'). Se pueden cambiar sin tocar código.

insert into public.pricing (kind, label, credits, max_per_day, est_cost_usd, enabled) values
  ('game_libre', 'Juego a medida (estudio, sin plantilla)', 150, 3, 4.0000, true)
on conflict (kind) do update
  set label = excluded.label, est_cost_usd = excluded.est_cost_usd;

create or replace function public.queue_libre(p_user uuid, p_idea text, p_entrevista jsonb default '{}'::jsonb)
returns table (job_id uuid, credits_left integer, cost integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_max integer;
  v_hoy integer;
begin
  if char_length(coalesce(p_idea, '')) not between 15 and 700 then
    raise exception 'bad_idea';
  end if;
  if p_entrevista is null or jsonb_typeof(p_entrevista) <> 'object' or char_length(p_entrevista::text) > 4000 then
    raise exception 'bad_idea';
  end if;
  -- Tope diario propio (el trabajo pasa a ser 'game' y reserve_job no lo contaría).
  select max_per_day into v_max from public.pricing where kind = 'game_libre';
  select count(*) into v_hoy from public.jobs
   where user_id = p_user and kind = 'game' and detail ->> 'modo' = 'libre'
     and created_at >= date_trunc('day', now());
  if v_hoy >= coalesce(v_max, 0) then raise exception 'daily_limit'; end if;
  select * into r from public.reserve_job(p_user, 'game_libre',
    jsonb_build_object('idea', p_idea, 'modo', 'libre', 'entrevista', p_entrevista));
  update public.jobs set kind = 'game', status = 'queued' where id = r.job_id;
  return query select r.job_id, r.credits_left, r.cost;
end;
$$;

revoke all on function public.queue_libre(uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.queue_libre(uuid, text, jsonb) to service_role;

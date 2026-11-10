-- Vista previa JUGABLE (10 de noviembre de 2026): jugar tu idea gratis en un minuto, antes de pagar.
--
-- La vista previa ya no es solo texto: la fabrica monta tambien el boceto (niveles de verdad con los
-- dibujos provisionales del kit, ~6 MB) y lo deja en jobs.result.boceto. Sin tarjeta grafica: cuesta
-- ~0,01 $. Los bocetos de mas de 2 dias se borran solos (limpiar_previas) para no llenar el almacen.

drop function if exists public.complete_preview_job(uuid, jsonb, numeric);
create or replace function public.complete_preview_job(p_job uuid, p_spec jsonb, p_cost_usd numeric, p_boceto text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_spec is null or jsonb_typeof(p_spec) <> 'object' then raise exception 'bad_spec'; end if;
  update public.jobs
     set result = jsonb_build_object('diseno', p_spec) || case when p_boceto is null then '{}'::jsonb else jsonb_build_object('boceto', p_boceto) end
   where id = p_job and kind = 'game_preview' and status = 'running';
  if not found then raise exception 'job_not_running'; end if;
  perform public.finish_job(p_job, p_cost_usd, null, null, 0);
end;
$$;

revoke all on function public.complete_preview_job(uuid, jsonb, numeric, text) from public, anon, authenticated;
grant execute on function public.complete_preview_job(uuid, jsonb, numeric, text) to service_role;

-- Rutas de los bocetos de vistas previas de mas de N dias; los da por borrados (la fabrica los borra).
create or replace function public.limpiar_previas(p_dias integer default 2)
returns text[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rutas text[];
begin
  with viejas as (
    update public.jobs set result = result - 'boceto'
     where id in (select id from public.jobs
                   where kind = 'game_preview' and result ? 'boceto'
                     and created_at < now() - make_interval(days => p_dias)
                   limit 200)
    returning (select o.result ->> 'boceto' from public.jobs o where o.id = jobs.id) as ruta
  )
  select coalesce(array_agg(ruta) filter (where ruta is not null), '{}') into v_rutas from viejas;
  return v_rutas;
end;
$$;

revoke all on function public.limpiar_previas(integer) from public, anon, authenticated;
grant execute on function public.limpiar_previas(integer) to service_role;

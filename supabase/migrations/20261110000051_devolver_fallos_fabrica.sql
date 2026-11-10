-- Un juego que falla en la fabrica se devuelve SIEMPRE (noviembre de 2026).
--
-- Antes: como mucho 3 devoluciones por usuario y dia (max_refunds_per_day) para todo. Un jugador
-- con mala suerte (4 juegos fallidos el mismo dia) perdia las tuercas del cuarto sin recibir nada:
-- eso es una resena de una estrella y una devolucion en Google Play que cuesta mas que el juego.
-- Ahora: lo que hace la fabrica (juegos, cambios, mods, videos, publicar) se devuelve siempre que
-- el fallo sea nuestro. El tope diario queda para lo barato y repetible (charla, plan, dibujos sueltos).
-- El abuso (pedir juegos que fallen a proposito) no le da nada al jugador y lo frena el presupuesto
-- diario de la nube (daily_budget_usd).

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
    if v_job.kind like 'game%' then
      -- Trabajo de la fabrica: el jugador no recibe nada, asi que se devuelve siempre.
      v_refund := true;
    else
      select count(*) into v_refunds from public.jobs
       where user_id = v_job.user_id and refunded and kind not like 'game%'
         and coalesce(error, '') <> 'queue_timeout'
         and created_at >= date_trunc('day', now());
      v_refund := v_refunds < public.setting('max_refunds_per_day');
    end if;
    if v_refund then
      update public.profiles set credits = credits + v_job.cost where id = v_job.user_id;
      insert into public.credit_ledger (user_id, amount, reason, ref)
      values (v_job.user_id, v_job.cost, 'refund', v_job.id::text);
    end if;
  end if;

  update public.jobs
     set status = 'failed', finished_at = now(), error = left(p_error, 500),
         provider_cost_usd = coalesce(p_cost_usd, 0), refunded = v_refund
   where id = p_job;

  return v_refund;
end;
$$;

revoke all on function public.fail_job(uuid, text, numeric, boolean) from public, anon, authenticated;
grant execute on function public.fail_job(uuid, text, numeric, boolean) to service_role;

update public.settings
   set note = 'Devoluciones automaticas por usuario y dia de lo barato (charla, plan, dibujos). Los trabajos de la fabrica (game*) se devuelven siempre'
 where key = 'max_refunds_per_day';

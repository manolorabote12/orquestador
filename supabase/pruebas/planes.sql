\set ON_ERROR_STOP 1
-- Planes mensuales: tuercas cada mes, tope de 2 meses, mejora a Pro, +10 % en packs, reembolso y prioridad en la cola.
do $$
declare
  u uuid; libre uuid; j_libre uuid; j_plan uuid; c record; r jsonb;
begin
  insert into auth.users (email, email_confirmed_at) values ('plan@example.com', now()) returning id into u;
  insert into auth.users (email, email_confirmed_at) values ('sinplan@example.com', now()) returning id into libre;
  update public.profiles set credits = 0 where id = u;
  -- 1 - Contratar Taller: 300 al momento (economia v3).
  r := public.grant_purchase(u, 'plan_taller', 'tok-plan-1', 'GPA.plan-1', now() + interval '1 month');
  assert (select credits from public.profiles where id = u) = 300, 'entrega al contratar';
  assert (select plan from public.profiles where id = u) = 'taller';
  assert (select premium_hasta > now() from public.profiles where id = u), 'Lanzadera incluida';
  assert exists (select 1 from public.credit_ledger where user_id = u and reason = 'purchase'), 'cuenta como compra';
  -- 2 - Mismo mes: nada mas.
  perform public.plan_entregar();
  perform public.grant_purchase(u, 'plan_taller', 'tok-plan-1', 'GPA.plan-1', now() + interval '1 month');
  assert (select credits from public.profiles where id = u) = 300, 'una vez al mes';
  -- 3 - Mes siguiente: otras 300; el tercero topa en 2 meses (600).
  update public.profiles set plan_entrega = now() - interval '1 second' where id = u;
  perform public.plan_entregar();
  assert (select credits from public.profiles where id = u) = 600, 'segundo mes';
  update public.profiles set plan_entrega = now() - interval '1 second' where id = u;
  perform public.plan_entregar();
  assert (select credits from public.profiles where id = u) = 600, 'tope de 2 meses';
  assert (select plan_entrega > now() + interval '20 days' from public.profiles where id = u), 'siguiente en un mes';
  -- 4 - Gasta y mejora a Pro: 1.000 al momento.
  update public.profiles set credits = 100 where id = u;
  perform public.grant_purchase(u, 'plan_pro', 'tok-plan-2', 'GPA.plan-2', now() + interval '1 month');
  assert (select credits from public.profiles where id = u) = 1100, 'mejora: entrega ya';
  assert (select plan from public.profiles where id = u) = 'pro';
  -- 5 - Pro: +10 % en packs (el pequeno da 180).
  r := public.grant_purchase(u, 'tuercas_300', 'tok-plan-3', 'GPA.plan-3');
  assert (r ->> 'sumadas')::int = 198, r::text;
  -- 6 - Reembolso del plan: fuera el plan y la ultima entrega.
  assert public.revoke_purchase('tok-plan-2') = 'revoked';
  assert (select plan is null and credits = 1298 - 1000 from public.profiles where id = u), (select credits::text from public.profiles where id = u);
  -- 7 - Plan caducado: no entrega.
  update public.profiles set plan = 'taller', plan_hasta = now() - interval '1 day', plan_entrega = now() - interval '1 day' where id = u;
  perform public.plan_entregar();
  assert (select credits from public.profiles where id = u) = 298, 'caducado: nada';
  -- 8 - Prioridad en la cola: el juego de quien tiene plan va antes que uno gratis mas antiguo.
  update public.profiles set plan = 'taller', plan_hasta = now() + interval '1 month', plan_entrega = now() + interval '1 month' where id = u;
  delete from public.jobs where status = 'queued';
  insert into public.jobs (user_id, kind, cost, status, created_at) values (libre, 'game', 80, 'queued', now() - interval '5 minutes') returning id into j_libre;
  insert into public.jobs (user_id, kind, cost, status) values (u, 'game', 80, 'queued') returning id into j_plan;
  select * into c from public.claim_game_job('prueba');
  assert c.job_id = j_plan, 'con plan, primero';
  select * into c from public.claim_game_job('prueba');
  assert c.job_id = j_libre;
  update public.jobs set status = 'failed', finished_at = now() where id in (j_plan, j_libre);
  -- 9 - Seguridad.
  assert not has_function_privilege('authenticated', 'public.plan_entregar(uuid)', 'execute');
  assert not has_function_privilege('authenticated', 'public.grant_purchase(uuid, text, text, text, timestamptz)', 'execute');
  assert not (select active from public.store_products where product_id = 'premium_mensual'), 'premium antiguo retirado';
  raise notice 'planes OK';
end;
$$;

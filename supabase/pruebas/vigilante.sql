\set ON_ERROR_STOP 1
-- Boton de parada y vigilancia.
do $$
declare
  u uuid; j uuid; v jsonb; n integer;
begin
  insert into auth.users (email, email_confirmed_at) values ('vigilado@example.com', now()) returning id into u;
  update public.profiles set credits = 500 where id = u;
  assert not public.fabrica_pausada();
  -- En marcha: sigue mientras no se pause.
  insert into public.jobs (user_id, kind, cost, status, started_at, est_cost_usd) values (u, 'game', 80, 'running', now(), 0.35) returning id into j;
  assert public.job_progress(j, '{"paso":"arte"}'::jsonb), 'sigue';
  -- Un trabajo caro que acaba de terminar sale en la vigilancia.
  insert into public.jobs (user_id, kind, cost, status, started_at, finished_at, provider_cost_usd)
  values (u, 'game', 80, 'done', now() - interval '30 minutes', now(), 1.20);
  v := public.vigilancia(0.8, 20);
  assert jsonb_array_length(v -> 'caros') = 1, v::text;
  assert (v ->> 'en_marcha')::int >= 1 and (v ->> 'hora_usd')::numeric >= 1.55, v::text;
  -- Parada: lo que esta en marcha se entera, la cola no se coge y no se aceptan juegos nuevos.
  perform public.pausar_fabrica(true, 'prueba');
  assert public.fabrica_pausada();
  assert not public.job_progress(j, '{"paso":"arte"}'::jsonb), 'en marcha: para';
  insert into public.jobs (user_id, kind, cost, status) values (u, 'design', 2, 'queued');
  select count(*) into n from public.claim_game_job('prueba');
  assert n = 0, 'pausada: no coge nada';
  begin
    perform public.reserve_job(u, 'game', '{"idea":"x"}'::jsonb);
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%budget_exceeded%', sqlerrm; end;
  assert (select credits from public.profiles where id = u) = 500, 'no se cobra nada';
  assert (select note from public.settings where key = 'fabrica_pausada') like 'PARADA%prueba%';
  -- Reanudar.
  perform public.pausar_fabrica(false);
  assert not public.fabrica_pausada();
  perform public.reserve_job(u, 'game', '{"idea":"x"}'::jsonb);
  assert (select credits from public.profiles where id = u) = 420, 'reanudada: cobra y encola';
  assert not has_function_privilege('authenticated', 'public.pausar_fabrica(boolean, text)', 'execute');
  assert not has_function_privilege('authenticated', 'public.vigilancia(numeric, integer)', 'execute');
  assert not has_function_privilege('anon', 'public.claim_game_job(text)', 'execute');
  raise notice 'vigilante OK';
end;
$$;
-- Embudo y correos.
do $$
declare
  a uuid; b uuid; e jsonb; v jsonb;
begin
  insert into auth.users (email, email_confirmed_at) values ('embudo.a@example.com', now()) returning id into a;
  insert into auth.users (email, email_confirmed_at) values ('embudo.b@example.com', null) returning id into b;
  insert into public.jobs (user_id, kind, cost, status, finished_at) values (a, 'game', 80, 'done', now());
  insert into public.credit_ledger (user_id, amount, reason) values (a, 300, 'purchase');
  e := public.embudo(30);
  assert (e ->> 'registros')::int >= 2 and (e ->> 'compradores')::int >= 1 and (e ->> 'juego_terminado')::int >= 1, e::text;
  assert (e ->> 'pct_compran')::numeric > 0, e::text;
  v := public.vigilancia(0.8, 20);
  assert (v ->> 'correos_24h')::int >= 2, v::text;
  assert not has_function_privilege('authenticated', 'public.embudo(integer)', 'execute');
  raise notice 'embudo OK';
end;
$$;

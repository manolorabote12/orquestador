\set ON_ERROR_STOP 1
-- Vista previa gratis: se ve el diseno antes de pagar y se fabrica ESE diseno.
do $$
declare
  u uuid; otro uuid; p uuid; j uuid; c record; n integer;
begin
  insert into auth.users (email, email_confirmed_at) values ('previa@example.com', now()) returning id into u;
  insert into auth.users (email, email_confirmed_at) values ('ajeno@example.com', now()) returning id into otro;
  update public.profiles set credits = 100 where id = u;
  -- 1 - Pedir la vista previa no cobra nada.
  select r.job_id into p from public.queue_preview(u, 'un orco que defiende su torre de cartas') r;
  assert (select credits from public.profiles where id = u) = 100, 'gratis';
  assert (select status from public.jobs where id = p) = 'queued';
  -- 2 - La fabrica la coge antes que un juego que ya estaba en cola.
  update public.profiles set credits = 1000 where id = otro;
  perform public.queue_game(otro, 'un juego que ya estaba esperando en la cola');
  update public.jobs set created_at = now() - interval '5 minutes' where user_id = otro and kind = 'game';
  select * into c from public.claim_game_job('prueba');
  assert c.job_id = p and c.kind = 'game_preview', 'la vista previa primero';
  -- 3 - Termina con su diseno.
  perform public.complete_preview_job(p, '{"titulo":"Torre Orca","genero":"duelo"}'::jsonb, 0.008);
  assert (select result -> 'diseno' ->> 'titulo' from public.jobs where id = p) = 'Torre Orca';
  assert (select status from public.jobs where id = p) = 'done';
  -- 4 - Fabricar con esa vista previa: cobra y el trabajo lleva el diseno.
  select r.job_id into j from public.queue_game(u, 'un orco que defiende su torre de cartas', p) r;
  assert (select credits from public.profiles where id = u) = 20, 'cobra 80';
  assert (select detail -> 'diseno' ->> 'titulo' from public.jobs where id = j) = 'Torre Orca', 'con su diseno';
  -- 5 - La vista previa de otro no vale.
  begin
    perform public.queue_game(otro, 'quiero usar el diseno de otra persona', p);
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_preview%', sqlerrm; end;
  -- 6 - Limite diario de vistas previas.
  for n in 1..14 loop
    update public.jobs set created_at = greatest(date_trunc('day', now()), now() - interval '2 minutes') where user_id = u;
    perform public.queue_preview(u, 'otra idea distinta numero ' || n || ' para probar');
  end loop;
  update public.jobs set created_at = greatest(date_trunc('day', now()), now() - interval '2 minutes') where user_id = u;
  begin
    perform public.queue_preview(u, 'una idea mas por encima del limite de hoy');
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%daily_limit%', sqlerrm; end;
  assert not has_function_privilege('authenticated', 'public.queue_preview(uuid, text)', 'execute');
  assert not has_function_privilege('authenticated', 'public.complete_preview_job(uuid, jsonb, numeric, text)', 'execute');
  raise notice 'vista_previa OK';
end;
$$;
-- Reintentar un juego fallido con su mismo diseno.
do $$
declare
  u uuid; j uuid; r uuid;
begin
  insert into auth.users (email, email_confirmed_at) values ('reintento@example.com', now()) returning id into u;
  update public.profiles set credits = 200 where id = u;
  select q.job_id into j from public.queue_game(u, 'un caballero que salta castillos de nubes') q;
  update public.jobs set status = 'running', started_at = now() where id = j;
  perform public.guardar_diseno(j, '{"titulo":"Caballero de Nubes"}'::jsonb);
  perform public.fail_job(j, 'fallo despues del arte', 0.2, true);
  assert (select credits from public.profiles where id = u) = 200, 'devuelto';
  update public.jobs set created_at = now() - interval '2 minutes' where user_id = u;
  select q.job_id into r from public.queue_game(u, 'un caballero que salta castillos de nubes', j) q;
  assert (select detail -> 'diseno' ->> 'titulo' from public.jobs where id = r) = 'Caballero de Nubes', 'mismo diseno';
  assert not has_function_privilege('authenticated', 'public.guardar_diseno(uuid, jsonb)', 'execute');
  raise notice 'reintentar OK';
end;
$$;
-- Vista previa jugable: el boceto queda en el resultado y los viejos se limpian.
do $$
declare
  u uuid; p uuid; rutas text[];
begin
  insert into auth.users (email, email_confirmed_at) values ('boceto@example.com', now()) returning id into u;
  select r.job_id into p from public.queue_preview(u, 'un pulpo cocinero que reparte sushi en patines') r;
  update public.jobs set status = 'running', started_at = now() where id = p;
  perform public.complete_preview_job(p, '{"titulo":"Pulpo Sushi"}'::jsonb, 0.01, u::text || '/' || p::text || '/boceto/index.pck');
  assert (select result ->> 'boceto' from public.jobs where id = p) like '%/boceto/index.pck';
  assert public.limpiar_previas(2) = '{}', 'reciente: no se borra';
  update public.jobs set created_at = now() - interval '3 days' where id = p;
  rutas := public.limpiar_previas(2);
  assert array_length(rutas, 1) = 1 and rutas[1] like '%/boceto/index.pck', rutas::text;
  assert not (select result ? 'boceto' from public.jobs where id = p), 'ya no lo ofrece';
  assert (select result -> 'diseno' ->> 'titulo' from public.jobs where id = p) = 'Pulpo Sushi', 'el diseno sigue';
  assert public.limpiar_previas(2) = '{}';
  raise notice 'boceto previa OK';
end;
$$;

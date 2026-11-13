\set ON_ERROR_STOP 1
-- Guardar gratis el boceto de una vista previa y fabricarlo despues.
do $$
declare
  u uuid; otro uuid; p uuid; pr uuid; pr2 uuid; j uuid; i integer; rutas text[];
begin
  insert into auth.users (email, email_confirmed_at) values ('borrador@example.com', now()) returning id into u;
  insert into auth.users (email, email_confirmed_at) values ('fisgon@example.com', now()) returning id into otro;
  update public.profiles set credits = 140 where id = u;
  insert into public.jobs (user_id, kind, cost, status, finished_at, created_at, detail, result)
  values (u, 'game_preview', 0, 'done', now(), now() - interval '5 days', '{"idea":"una rana que salta nenufares gigantes"}'::jsonb,
          jsonb_build_object('diseno', '{"titulo":"Rana Saltarina","genero":"plataformas"}'::jsonb, 'boceto', u::text || '/x/boceto/index.pck'))
  returning id into p;
  -- Otro usuario no puede guardarlo.
  perform set_config('request.jwt.claim.sub', otro::text, false);
  begin
    perform public.guardar_boceto(p);
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_preview%', sqlerrm; end;
  -- Su dueno si: sin cobrar nada.
  perform set_config('request.jwt.claim.sub', u::text, false);
  pr := public.guardar_boceto(p);
  assert (select credits from public.profiles where id = u) = 140, 'gratis';
  assert (select title from public.projects where id = pr) = 'Rana Saltarina';
  assert (select files ->> 'borrador' from public.projects where id = pr) = 'true';
  assert (select files ->> 'web' from public.projects where id = pr) like '%/boceto/index.pck';
  assert (select count(*) from public.project_versions where project_id = pr) = 1;
  -- Guardarlo dos veces devuelve el mismo juego.
  pr2 := public.guardar_boceto(p);
  assert pr2 = pr, 'idempotente';
  -- La limpieza de vistas previas ya no toca ese boceto (aunque tenga 5 dias).
  rutas := public.limpiar_previas(2);
  assert not (u::text || '/x/boceto/index.pck' = any(rutas)), rutas::text;
  -- Y se puede fabricar el juego completo desde el, aunque hayan pasado los 2 dias.
  select q.job_id into j from public.queue_game(u, 'una rana que salta nenufares gigantes', p) q;
  assert (select detail -> 'diseno' ->> 'titulo' from public.jobs where id = j) = 'Rana Saltarina';
  assert (select credits from public.profiles where id = u) = 20;
  -- Como mucho 3 borradores.
  for i in 1..2 loop
    insert into public.jobs (user_id, kind, cost, status, finished_at, detail, result)
    values (u, 'game_preview', 0, 'done', now(), '{"idea":"otra idea distinta de prueba"}'::jsonb,
            jsonb_build_object('diseno', '{"titulo":"Otro"}'::jsonb, 'boceto', u::text || '/y' || i || '/boceto/index.pck')) returning id into p;
    perform public.guardar_boceto(p);
  end loop;
  insert into public.jobs (user_id, kind, cost, status, finished_at, detail, result)
  values (u, 'game_preview', 0, 'done', now(), '{"idea":"la cuarta idea de prueba"}'::jsonb,
          jsonb_build_object('diseno', '{"titulo":"Cuarto"}'::jsonb, 'boceto', u::text || '/z/boceto/index.pck')) returning id into p;
  begin
    perform public.guardar_boceto(p);
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%too_many_drafts%', sqlerrm; end;
  -- Borrar un borrador deja sitio y devuelve el boceto a la limpieza.
  perform public.borrar_boceto(pr);
  assert not exists (select 1 from public.projects where id = pr);
  assert (select count(*) from public.jobs where user_id = u and kind = 'game_preview' and result ->> 'boceto' = u::text || '/x/boceto/index.pck') = 1;
  perform public.guardar_boceto(p);
  begin
    perform public.borrar_boceto((select id from public.projects where user_id = otro limit 1));
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  perform set_config('request.jwt.claim.sub', '', false);
  delete from public.jobs where user_id = u and status = 'queued';
  -- Sin restos para las demas pruebas.
  delete from public.projects where user_id = u;
  delete from public.jobs where user_id = u;
  assert not has_function_privilege('anon', 'public.guardar_boceto(uuid)', 'execute');
  raise notice 'guardar_boceto OK';
end;
$$;

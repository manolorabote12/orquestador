\set ON_ERROR_STOP 1
do $$
declare
  u uuid; p uuid; r record; tel uuid; n int; c int;
begin
  insert into auth.users (email, email_confirmed_at) values ('ana@x.com', now()) returning id into u;
  update public.profiles set credits = 500 where id = u;
  select * into r from public.queue_game(u, 'un gato ninja que salta por tejados de noche');
  select * into r from public.claim_game_job('w1');
  p := public.complete_game_job(r.job_id, 0.1, 10, 'Bigotes', '{"titulo":"Bigotes","genero":"plataformas","dificultad":"normal","niveles":["a","b","c","d"]}'::jsonb, '{}'::jsonb);
  select telemetria_id into tel from public.projects where id = p;
  assert tel = r.job_id, 'telemetria_id = id del trabajo';
  n := public.registrar_partida(tel, 1, 'abcdef0123456789', '[{"n":0,"r":"gana","s":40.5,"m":1,"e":3},{"n":2,"r":"sale","s":90,"m":5},{"n":2,"r":"muere","s":-3,"m":1},{"n":"x"}]'::jsonb);
  assert n = 2, 'solo los validos: ' || n;
  begin
    perform public.registrar_partida(gen_random_uuid(), 1, 'abcdef0123456789', '[{"n":0,"r":"gana","s":1,"m":0}]'::jsonb);
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%unknown_game%', sqlerrm; end;
  begin
    perform public.registrar_partida(tel, 1, 'NO VALE', '[{"n":0,"r":"gana","s":1,"m":0}]'::jsonb);
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_session%', sqlerrm; end;
  update public.settings set value = 3 where key = 'partidas_por_sesion_hora';
  begin
    perform public.registrar_partida(tel, 1, 'abcdef0123456789', '[{"n":1,"r":"gana","s":1,"m":0},{"n":1,"r":"gana","s":1,"m":0}]'::jsonb);
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%rate_limited%', sqlerrm; end;
  update public.settings set value = 300 where key = 'partidas_por_sesion_hora';
  for c in 1..30 loop
    perform public.registrar_partida(tel, 1, lpad(to_hex(c), 8, '0'), '[{"n":3,"r":"sale","s":60,"m":4},{"n":0,"r":"gana","s":30,"m":0,"e":3}]'::jsonb);
  end loop;
  perform set_config('request.jwt.claim.sub', u::text, true);
  select * into r from public.informe_jugadores(p) where nivel = 3;
  assert r.intentos = 30 and r.salidas = 30 and r.sesiones = 30, 'informe nivel 3';
  perform set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
  begin
    perform public.informe_jugadores(p);
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  select * into r from public.estadisticas_globales() where tramo = 4;
  assert r.genero = 'plataformas' and r.tasa_abandono = 1, 'global tramo 4: ' || r::text;
  raise notice 'APRENDIZAJE OK';
end $$;

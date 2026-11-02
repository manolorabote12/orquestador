\set ON_ERROR_STOP 1
do $$
declare
  u uuid; otro uuid; p uuid; r record; v jsonb; j jsonb;
begin
  insert into auth.users (email, email_confirmed_at) values ('ads@x.com', now()) returning id into u;
  insert into auth.users (email, email_confirmed_at) values ('otro@x.com', now()) returning id into otro;
  update public.profiles set credits = 500 where id = u;
  select * into r from public.queue_game(u, 'un gato ninja que salta por tejados de noche');
  select * into r from public.claim_game_job('w1');
  p := public.complete_game_job(r.job_id, 0.1, 10, 'Bigotes', '{"titulo":"Bigotes"}'::jsonb, '{}'::jsonb);
  perform set_config('request.jwt.claim.sub', u::text, false);
  begin perform public.set_project_admob(p, 'malo', 'x', 'y'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_app_id%', sqlerrm; end;
  begin perform public.set_project_admob(p, 'ca-app-pub-1234567890123456~1234567890', 'ca-app-pub-1234567890123456/123', 'x'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_ad_unit%', sqlerrm; end;
  begin perform public.set_project_admob(p, 'ca-app-pub-1234567890123456~1234567890', 'ca-app-pub-9999999999999999/1234567890', 'ca-app-pub-1234567890123456/1234567891'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%mixed_accounts%', sqlerrm; end;
  begin perform public.set_project_admob(p, 'ca-app-pub-3940256099942544~3347511713', 'ca-app-pub-3940256099942544/1033173712', 'ca-app-pub-3940256099942544/5224354917'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%test_ids%', sqlerrm; end;
  v := public.set_project_admob(p, 'ca-app-pub-1234567890123456~1234567890', 'ca-app-pub-1234567890123456/1111111111', 'ca-app-pub-1234567890123456/2222222222');
  assert v ->> 'rewarded' = 'ca-app-pub-1234567890123456/2222222222';
  assert not (v ? 'banner') and not (v ? 'perfil'), 'sin banner ni perfil si no se ponen';
  -- Banner, apertura de app y perfil (opcionales, de la misma cuenta)
  v := public.set_project_admob(p, 'ca-app-pub-1234567890123456~1234567890', 'ca-app-pub-1234567890123456/1111111111',
    'ca-app-pub-1234567890123456/2222222222', 'ca-app-pub-1234567890123456/3333333333', 'ca-app-pub-1234567890123456/4444444444', 'puzle');
  assert v ->> 'banner' = 'ca-app-pub-1234567890123456/3333333333' and v ->> 'app_open' = 'ca-app-pub-1234567890123456/4444444444' and v ->> 'perfil' = 'puzle', v::text;
  begin perform public.set_project_admob(p, 'ca-app-pub-1234567890123456~1234567890', 'ca-app-pub-1234567890123456/1111111111',
    'ca-app-pub-1234567890123456/2222222222', 'ca-app-pub-9999999999999999/3333333333'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%mixed_accounts%', sqlerrm; end;
  begin perform public.set_project_admob(p, 'ca-app-pub-1234567890123456~1234567890', 'ca-app-pub-1234567890123456/1111111111',
    'ca-app-pub-1234567890123456/2222222222', '', '', 'mafia'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_profile%', sqlerrm; end;
  perform set_config('request.jwt.claim.sub', otro::text, false);
  begin perform public.set_project_admob(p, 'ca-app-pub-1234567890123456~1234567890', 'ca-app-pub-1234567890123456/1111111111', 'ca-app-pub-1234567890123456/2222222222'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  perform public.save_play_account(u, 'Daniel Studio', 'dani@x.com');
  select * into r from public.queue_publish(u, p, 'primer_aab', 'internal');
  select detail into j from public.jobs where id = r.job_id;
  assert j -> 'admob' ->> 'app_id' = 'ca-app-pub-1234567890123456~1234567890', 'la publicacion lleva los ids: ' || j::text;
  -- Se cierra el trabajo para no dejarlo en la cola de las demas pruebas.
  update public.jobs set status = 'failed' where id = r.job_id;
  perform set_config('request.jwt.claim.sub', u::text, false);
  perform public.set_project_admob(p, '', '', '');
  assert (select admob from public.projects where id = p) is null, 'quitar anuncios';
  raise notice 'ANUNCIOS OK';
end $$;
select 'ANUNCIOS OK';

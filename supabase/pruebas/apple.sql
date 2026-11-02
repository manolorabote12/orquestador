\set ON_ERROR_STOP 1
do $$
declare
  u uuid; p uuid; r record; j record; c int;
begin
  insert into auth.users (email, email_confirmed_at) values ('ios@x.com', now()) returning id into u;
  update public.profiles set credits = 500 where id = u;
  select * into r from public.queue_game(u, 'un gato ninja que salta por tejados de noche');
  select * into r from public.claim_game_job('w1');
  p := public.complete_game_job(r.job_id, 0.1, 10, 'Bigotes', '{"titulo":"Bigotes"}'::jsonb, '{"proyecto":"x.zip"}'::jsonb);
  begin perform public.queue_ios(u, p); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%apple_setup_missing%', sqlerrm; end;
  begin perform public.save_apple_account(u, 'malo', 'ABCDE12345', '69a6de70-0000-47e3-e053-5b8c7c11a4d1', 'apple/x.bin'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_team%', sqlerrm; end;
  perform public.save_apple_account(u, 'A1B2C3D4E5', 'ABCDE12345', '69a6de70-0000-47e3-e053-5b8c7c11a4d1', 'apple/' || u || '.bin');
  update public.projects set play = '{"paquete": "com.danielstudio.bigotes"}' where id = p;
  select * into r from public.queue_ios(u, p);
  -- La fabrica de RunPod no lo coge: es para el Mac.
  select count(*) into c from public.claim_game_job('runpod-1');
  assert c = 0, 'la fabrica no coge trabajos de Mac';
  select * into j from public.claim_ios_job(r.job_id, 'mac-github');
  assert j.detail ->> 'bundle' = 'com.danielstudio.bigotes' and (j.detail ->> 'build')::int = 1, j.detail::text;
  begin perform public.claim_ios_job(r.job_id, 'otro'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%job_not_queued%', sqlerrm; end;
  perform public.complete_ios_job(r.job_id, 0.2, '{"bundle": "com.danielstudio.bigotes", "build": 1, "estado": "subido"}');
  assert (select ios ->> 'estado' from public.projects where id = p) = 'subido';
  select * into r from public.queue_ios(u, p);
  select detail into j from public.jobs where id = r.job_id;
  assert (j.detail ->> 'build')::int = 2, 'el numero de build sube';
  update public.jobs set status = 'failed' where id = r.job_id;
  raise notice 'APPLE OK';
end $$;
select 'APPLE OK';

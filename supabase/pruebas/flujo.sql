\set ON_ERROR_STOP 1
do $$
declare
  u uuid; j uuid; p uuid; r record; c int; ok boolean;
begin
  insert into auth.users (email, email_confirmed_at) values ('dani@x.com', now()) returning id into u;
  select credits into c from public.profiles where id = u;
  raise notice 'creditos iniciales %', c;
  update public.profiles set credits = 200 where id = u;
  -- juego
  select * into r from public.queue_game(u, 'un gato ninja que salta por tejados de noche');
  select * into r from public.claim_game_job('w1');
  p := public.complete_game_job(r.job_id, 0.1, 10, 'Bigotes', '{"titulo":"Bigotes"}'::jsonb, '{"proyecto":"x.zip"}'::jsonb);
  -- marketing
  select * into r from public.queue_marketing(u, p);
  select credits into c from public.profiles where id = u;
  assert c = 200 - (select credits from public.pricing where kind='game') - 20, 'cobro marketing';
  begin
    perform public.queue_marketing(u, p);
    raise exception 'debia fallar project_busy';
  exception when others then
    assert sqlerrm like '%project_busy%', sqlerrm;
  end;
  select * into r from public.claim_game_job('w1');
  assert r.kind = 'game_marketing', 'kind';
  perform public.complete_marketing_job(r.job_id, 0.05, '{"videos":[1,2,3]}'::jsonb);
  assert (select files -> 'marketing' -> 'videos' from public.projects where id = p) = '[1,2,3]'::jsonb, 'files marketing';
  assert (select files ->> 'proyecto' from public.projects where id = p) = 'x.zip', 'conserva files';
  -- publicar
  begin
    perform public.queue_publish(u, p, 'subir', 'alpha');
    raise exception 'debia fallar setup';
  exception when others then
    assert sqlerrm like '%play_setup_missing%', sqlerrm;
  end;
  perform public.save_play_account(u, 'Daniel Studio', 'Dani@X.com');
  begin
    perform public.queue_publish(u, p, 'subir', 'alpha');
    raise exception 'debia fallar first_aab';
  exception when others then
    assert sqlerrm like '%first_aab_missing%', sqlerrm;
  end;
  select * into r from public.queue_publish(u, p, 'primer_aab', 'internal');
  select * into r from public.claim_game_job('w1');
  assert r.kind = 'game_publish' and r.detail ->> 'estudio' = 'Daniel Studio' and r.detail ->> 'correo' = 'dani@x.com', 'detalle publicar';
  perform public.complete_publish_job(r.job_id, 0.01, '{"paquete":"com.danielstudio.bigotes","version_code":100,"estado":"primer_aab"}'::jsonb, '{"aab":"a.aab"}'::jsonb);
  select * into r from public.queue_publish(u, p, 'subir', 'alpha');
  select * into r from public.claim_game_job('w1');
  assert (r.detail ->> 'version_code')::int = 100 and r.detail ->> 'paquete' = 'com.danielstudio.bigotes', 'version previa';
  perform public.complete_publish_job(r.job_id, 0.0, '{"version_code":101,"estado":"subido","pista":"alpha"}'::jsonb, '{"aab":"b.aab"}'::jsonb);
  assert (select play ->> 'paquete' from public.projects where id = p) = 'com.danielstudio.bigotes', 'conserva paquete';
  assert (select (play ->> 'version_code')::int from public.projects where id = p) = 101, 'version 101';
  begin
    perform public.queue_publish(u, p, 'subir', 'luna');
    raise exception 'debia fallar pista';
  exception when others then
    assert sqlerrm like '%bad_track%', sqlerrm;
  end;
  raise notice 'FLUJO OK';
end $$;

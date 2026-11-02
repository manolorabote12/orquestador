\set ON_ERROR_STOP 1
do $$
declare
  u uuid; p uuid; r record; j record; c int;
begin
  insert into auth.users (email, email_confirmed_at) values ('mods@x.com', now()) returning id into u;
  update public.profiles set credits = 500 where id = u;
  select * into r from public.queue_game(u, 'un gato ninja que salta por tejados de noche');
  select * into r from public.claim_game_job('w1');
  p := public.complete_game_job(r.job_id, 0.1, 10, 'Bigotes', '{"titulo":"Bigotes"}'::jsonb, '{"proyecto":"x.zip"}'::jsonb);
  select credits into c from public.profiles where id = u;
  begin perform public.queue_mod(u, p, 'corto'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_instruction%', sqlerrm; end;
  select * into r from public.queue_mod(u, p, 'que el gato suelte chispas al saltar');
  assert (select credits from public.profiles where id = u) = c - 30, 'cobra 30 tuercas';
  select * into j from public.claim_game_job('runpod-1');
  assert j.kind = 'game_mod' and j.detail ->> 'instruccion' = 'que el gato suelte chispas al saltar', j::text;
  perform public.complete_change_job(j.job_id, 0.12, 0, 'Bigotes', '{"titulo":"Bigotes"}'::jsonb, '{"proyecto":"y.zip"}'::jsonb, 2);
  assert (select prompt from public.project_versions where project_id = p and version = 2) = 'que el gato suelte chispas al saltar';
  raise notice 'MODS OK';
end $$;
select 'MODS OK';

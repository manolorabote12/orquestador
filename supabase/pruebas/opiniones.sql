\set ON_ERROR_STOP 1
do $$
declare
  u uuid; otro uuid; p uuid; j uuid; r jsonb;
begin
  insert into auth.users (email, email_confirmed_at) values ('opi-a@x.com', now()) returning id into u;
  insert into auth.users (email, email_confirmed_at) values ('opi-b@x.com', now()) returning id into otro;
  insert into public.projects (user_id, title, spec, files) values (u, 'Bigotes', '{}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  begin perform public.opinion_enviar(j, 'mala', true); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_session%', sqlerrm; end;
  begin perform public.opinion_enviar(gen_random_uuid(), 'abcdefabcdef0001', true); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_found%', sqlerrm; end;
  perform public.opinion_enviar(j, 'abcdefabcdef0001', true);
  perform public.opinion_enviar(j, 'abcdefabcdef0002', false, 'El nivel 4 es <b>imposible</b>', 4, 2);
  perform public.opinion_enviar(j, 'abcdefabcdef0003', false, repeat('x', 500));
  perform public.opinion_enviar(j, 'abcdefabcdef0003', true, '');
  perform set_config('request.jwt.claim.sub', u::text, false);
  r := public.opiniones_autor(p);
  assert (r ->> 'gusta')::int = 2 and (r ->> 'no_gusta')::int = 1, r::text;
  assert jsonb_array_length(r -> 'ultimas') = 1 and r -> 'ultimas' -> 0 ->> 'texto' = 'El nivel 4 es bimposible/b'
    and (r -> 'ultimas' -> 0 ->> 'nivel')::int = 4, r::text;
  perform set_config('request.jwt.claim.sub', otro::text, false);
  begin perform public.opiniones_autor(p); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  raise notice 'OPINIONES OK';
end $$;
select 'OPINIONES OK';

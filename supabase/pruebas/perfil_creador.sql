\set ON_ERROR_STOP 1
do $$
declare
  a uuid; p uuid; r jsonb;
begin
  insert into auth.users (email, email_confirmed_at) values ('perfil-a@x.com', now()) returning id into a;
  perform set_config('request.jwt.claim.sub', a::text, false);
  r := public.perfil_creador();
  assert (r ->> 'juegos')::int = 0 and (r ->> 'jugadas')::int = 0, r::text;
  insert into public.projects (user_id, title, spec, files, version, play) values (a, 'Uno', '{"titulo":"Uno","genero":"golf"}'::jsonb, '{"web":"a/1/web/index.pck"}'::jsonb, 1, '{"estado":"subido"}'::jsonb) returning id into p;
  perform public.escaparate_publicar(a, p, 'Ana');
  for i in 1..4 loop perform public.escaparate_jugada(p); end loop;
  insert into public.credit_ledger (user_id, amount, reason, ref) values (a, 150, 'weekly_challenge', '40:1'), (a, 50, 'weekly_challenge', '41:3');
  r := public.perfil_creador();
  assert (r ->> 'juegos')::int = 1 and (r ->> 'publicados')::int = 1 and (r ->> 'jugadas')::int = 4 and (r ->> 'en_tienda')::int = 1, r::text;
  assert (r ->> 'podios')::int = 2 and (r ->> 'victorias')::int = 1, r::text;
  assert not has_function_privilege('anon', 'public.perfil_creador()', 'execute');
  raise notice 'perfil_creador OK';
end;
$$;

\set ON_ERROR_STOP 1
do $$
declare
  a uuid; b uuid; c uuid; pa uuid; pb uuid; pc uuid; r jsonb; ca int; cb int; n int; sem int; x record;
begin
  insert into auth.users (email, email_confirmed_at) values ('reto-a@x.com', now()) returning id into a;
  insert into auth.users (email, email_confirmed_at) values ('reto-b@x.com', now()) returning id into b;
  insert into auth.users (email, email_confirmed_at) values ('reto-c@x.com', now()) returning id into c;
  insert into public.projects (user_id, title, spec, files, version) values (a, 'Pirata A', '{"titulo":"Pirata A","genero":"plataformas"}'::jsonb, '{"web":"a/1/web/index.pck"}'::jsonb, 1) returning id into pa;
  insert into public.projects (user_id, title, spec, files, version) values (b, 'Pirata B', '{"titulo":"Pirata B","genero":"golf"}'::jsonb, '{"web":"b/1/web/index.pck"}'::jsonb, 1) returning id into pb;
  insert into public.projects (user_id, title, spec, files, version) values (c, 'Sin compartir', '{}'::jsonb, '{}'::jsonb, 1) returning id into pc;
  -- 1 - Tema por fecha: el mismo para todos y cambia cada semana.
  r := public.reto_actual();
  sem := (r ->> 'semana')::int;
  assert r ->> 'tema' = public.reto_tema(sem) and public.reto_tema(sem) <> public.reto_tema(sem + 1), r::text;
  assert (r -> 'premios' ->> 0)::int = 150 and (r ->> 'termina')::timestamptz > now(), r::text;
  -- 2 - Solo juegos propios y compartidos.
  perform set_config('request.jwt.claim.sub', c::text, false);
  begin perform public.reto_participar(pc); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_shared%', sqlerrm; end;
  perform public.escaparate_publicar(a, pa, 'Ana');
  perform public.escaparate_publicar(b, pb, 'Beto');
  begin perform public.reto_participar(pa); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_shared%', sqlerrm; end;
  perform set_config('request.jwt.claim.sub', a::text, false);
  r := public.reto_participar(pa);
  assert (public.reto_actual() ->> 'mi_proyecto')::uuid = pa;
  perform set_config('request.jwt.claim.sub', b::text, false);
  perform public.reto_participar(pb);
  assert (public.reto_actual() ->> 'participantes')::int = 2;
  -- Ranking: jugadas y me gusta de esta semana (el me gusta vale 10).
  for i in 1..5 loop perform public.escaparate_jugada(pa); end loop;
  perform set_config('request.jwt.claim.sub', c::text, false);
  perform public.escaparate_megusta(pb);
  select * into x from public.reto_ranking() limit 1;
  assert x.project_id = pb and x.puntos = 10 and x.puesto = 1, x::text;
  -- 3 - Premiar: la semana en curso no; la pasada si, una sola vez.
  begin perform public.reto_premiar(sem); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_finished%', sqlerrm; end;
  -- Llevamos las entradas y los datos a la semana pasada para premiarla.
  update public.reto_entradas set semana = sem - 1 where semana = sem;
  update public.escaparate_dia set dia = dia - 7;
  select credits into ca from public.profiles where id = a;
  select credits into cb from public.profiles where id = b;
  n := public.reto_premiar_anterior();
  assert n = 2, n::text;
  assert (select credits from public.profiles where id = b) = cb + 150 and (select credits from public.profiles where id = a) = ca + 100;
  assert public.reto_premiar_anterior() = 0;
  assert (select credits from public.profiles where id = b) = cb + 150;
  assert (public.reto_actual() -> 'ganadores_anterior' -> 0 ->> 'titulo') = 'Pirata B', public.reto_actual()::text;
  -- Permisos: nadie mas que el servidor premia.
  assert not has_function_privilege('authenticated', 'public.reto_premiar(integer)', 'execute');
  assert not has_function_privilege('anon', 'public.reto_participar(uuid)', 'execute');
  assert has_function_privilege('anon', 'public.reto_actual()', 'execute');
  raise notice 'reto_semana OK';
end;
$$;

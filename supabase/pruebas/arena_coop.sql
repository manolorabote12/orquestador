\set ON_ERROR_STOP 1
do $$
declare
  a uuid; p uuid; j uuid; r jsonb; s jsonb;
  s1 text := 'aaaaaaaaaaaaaaa1'; s2 text := 'bbbbbbbbbbbbbbb2';
begin
  insert into auth.users (email, email_confirmed_at) values ('coop-a@x.com', now()) returning id into a;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Coop', '{"titulo":"Coop","genero":"arena","niveles":["uno","dos"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  begin perform public.arena_privada_crear(j, s1, 'Dani', 'raro'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_mode%', sqlerrm; end;
  r := public.arena_privada_crear(j, s1, 'Dani', 'coop');
  assert r ->> 'modo' = 'coop', r::text;
  perform public.arena_privada_unir(j, s2, 'Lucia', r ->> 'codigo');
  s := public.arena_estado((r ->> 'sala')::uuid, s2);
  assert s ->> 'modo' = 'coop' and jsonb_array_length(s -> 'jugadores') = 2, s::text;
  perform public.arena_empezar((r ->> 'sala')::uuid, s1);
  update public.arena_salas set inicio = now() - interval '5 seconds' where id = (r ->> 'sala')::uuid;
  -- Los dos "primeros" (ganan juntos) y sin trofeos
  assert (public.arena_resultado((r ->> 'sala')::uuid, s1, 1) ->> 'delta')::int = 0;
  assert (public.arena_resultado((r ->> 'sala')::uuid, s2, 1) ->> 'delta')::int = 0;
  -- Sin modo: todos contra todos, como antes
  r := public.arena_privada_crear(j, s1, 'Dani');
  assert r ->> 'modo' = 'todos', r::text;
  delete from public.projects where id = p;
  raise notice 'ARENA COOP OK';
end;
$$;

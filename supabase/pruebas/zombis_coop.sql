\set ON_ERROR_STOP 1
do $$
declare
  a uuid; j uuid; ja uuid; r jsonb; sala uuid; k int; s text;
begin
  insert into auth.users (email, email_confirmed_at) values ('zom-a@x.com', now()) returning id into a;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Noche', '{"titulo":"Noche","genero":"zombis","niveles":["uno","dos","tres"]}'::jsonb, '{}'::jsonb) returning telemetria_id into j;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Robots', '{"titulo":"Robots","genero":"arena","niveles":["uno"]}'::jsonb, '{}'::jsonb) returning telemetria_id into ja;
  -- Partida publica de zombis: sala cooperativa de 4
  r := public.arena_buscar(j, 'c000000000000000', 'Dani');
  sala := (r ->> 'sala')::uuid;
  r := public.arena_estado(sala, 'c000000000000000');
  assert (r ->> 'modo') = 'coop' and (r ->> 'cupo')::int = 4, r::text;
  for k in 1..3 loop
    perform public.arena_buscar(j, 'c00000000000000' || k::text, 'Amigo' || k::text);
  end loop;
  assert (public.arena_estado(sala, 'c000000000000000') ->> 'empezada')::boolean, 'con 4 empieza';
  -- Sin trofeos: el resultado se anota pero no suma ni resta
  update public.arena_salas set inicio = now() - interval '1 minute' where id = sala;
  r := public.arena_resultado(sala, 'c000000000000000', 1);
  assert (r ->> 'delta')::int = 0 and (r ->> 'coop')::boolean, r::text;
  r := public.arena_resultado(sala, 'c000000000000001', 1);
  assert (r ->> 'delta')::int = 0, 'en cooperativo todos pueden ganar juntos';
  -- Sala con amigos: cooperativa aunque se pida todos contra todos
  r := public.arena_privada_crear(j, 'd000000000000000', 'Lucia', 'todos');
  assert (r ->> 'modo') = 'coop', r::text;
  -- La arena de siempre no cambia
  r := public.arena_buscar(ja, 'e000000000000000', 'Ana');
  assert (public.arena_estado((r ->> 'sala')::uuid, 'e000000000000000') ->> 'modo') = 'todos';
  r := public.arena_privada_crear(ja, 'e000000000000001', 'Eva', 'todos');
  assert (r ->> 'modo') = 'todos', r::text;
  assert not has_function_privilege('anon', 'public._arena_es_coop(uuid)', 'execute');
  delete from public.projects where user_id = a;
  raise notice 'ZOMBIS COOP OK';
end;
$$;

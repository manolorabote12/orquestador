\set ON_ERROR_STOP 1
do $$
declare
  a uuid; p uuid; j uuid; ja uuid; r jsonb; r2 jsonb; sala uuid; sala_a uuid; k int; s text;
begin
  insert into auth.users (email, email_confirmed_at) values ('roy-a@x.com', now()) returning id into a;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Isla', '{"titulo":"Isla","genero":"royale","niveles":["uno","dos"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Robots', '{"titulo":"Robots","genero":"arena","niveles":["uno"]}'::jsonb, '{}'::jsonb) returning telemetria_id into ja;
  -- Battle royale: salas de 8 (el resto de la isla son bots) y modo royale
  r := public.arena_buscar(j, 'f000000000000000', 'Dani');
  sala := (r ->> 'sala')::uuid;
  r := public.arena_estado(sala, 'f000000000000000');
  assert (r ->> 'modo') = 'royale' and (r ->> 'cupo')::int = 8 and not (r ->> 'empezada')::boolean, r::text;
  for k in 1..6 loop
    r := public.arena_buscar(j, 'f00000000000000' || k::text, 'Jugador' || k::text);
    assert (r ->> 'sala')::uuid = sala and (r ->> 'slot')::int = k, r::text;
  end loop;
  r := public.arena_estado(sala, 'f000000000000000');
  assert not (r ->> 'empezada')::boolean and jsonb_array_length(r -> 'jugadores') = 7, 'con 7 aun espera';
  perform public.arena_buscar(j, 'f000000000000007', 'Jugador7');
  r := public.arena_estado(sala, 'f000000000000000');
  assert (r ->> 'empezada')::boolean, 'con 8 empieza';
  r2 := public.arena_buscar(j, 'f000000000000008', 'Jugador8');
  assert (r2 ->> 'sala')::uuid <> sala, 'el noveno va a otra sala';
  -- La arena de siempre sigue siendo de 4
  r := public.arena_buscar(ja, 'a000000000000000', 'Ana');
  sala_a := (r ->> 'sala')::uuid;
  assert (public.arena_estado(sala_a, 'a000000000000000') ->> 'cupo')::int = 4;
  -- Puestos del royale hasta el 40, con sus trofeos
  update public.arena_salas set inicio = now() - interval '1 minute' where id = sala;
  r := public.arena_resultado(sala, 'f000000000000000', 1);
  assert (r ->> 'delta')::int = 15, r::text;
  r := public.arena_resultado(sala, 'f000000000000001', 3);
  assert (r ->> 'delta')::int = 8, r::text;
  r := public.arena_resultado(sala, 'f000000000000002', 9);
  assert (r ->> 'delta')::int = 1, r::text;
  r := public.arena_resultado(sala, 'f000000000000003', 25);
  assert (r ->> 'delta')::int = -4 and (r ->> 'trofeos')::int = 0, r::text;
  begin perform public.arena_resultado(sala, 'f000000000000004', 41); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_result%', sqlerrm; end;
  begin perform public.arena_resultado(sala, 'f000000000000004', 1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_result%', sqlerrm; end;
  -- En la arena el puesto 5 no existe
  update public.arena_salas set inicio = now() - interval '1 minute' where id = sala_a;
  begin perform public.arena_resultado(sala_a, 'a000000000000000', 5); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_result%', sqlerrm; end;
  -- Sala con amigos del royale: modo royale y cupo 8 aunque se pida otro modo
  r := public.arena_privada_crear(j, 'b000000000000000', 'Lucia', 'todos');
  assert (r ->> 'modo') = 'royale', r::text;
  s := r ->> 'codigo';
  for k in 1..7 loop
    r2 := public.arena_privada_unir(j, 'b00000000000000' || k::text, 'Amigo' || k::text, s);
    assert (r2 ->> 'slot')::int = k, r2::text;
  end loop;
  begin perform public.arena_privada_unir(j, 'b000000000000009', 'Amigo9', s); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%room_full%', sqlerrm; end;
  assert not has_function_privilege('anon', 'public._arena_es_royale(uuid)', 'execute');
  delete from public.projects where user_id = a;
  raise notice 'ROYALE ONLINE OK';
end;
$$;

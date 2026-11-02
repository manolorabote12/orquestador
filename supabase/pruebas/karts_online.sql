\set ON_ERROR_STOP 1
do $$
declare
  a uuid; j uuid; jt uuid; r jsonb; sala uuid; k int; ok boolean;
begin
  insert into auth.users (email, email_confirmed_at) values ('kart-a@x.com', now()) returning id into a;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Turbo', '{"titulo":"Turbo","genero":"karts","niveles":["uno","dos","tres","cuatro"]}'::jsonb, '{}'::jsonb) returning telemetria_id into j;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Raqueta', '{"titulo":"Raqueta","genero":"tenis","niveles":["uno"]}'::jsonb, '{}'::jsonb) returning telemetria_id into jt;
  -- Partida publica de karts: sala de 4, todos contra todos, en uno de sus circuitos
  r := public.arena_buscar(j, 'f000000000000000', 'Dani');
  sala := (r ->> 'sala')::uuid;
  r := public.arena_estado(sala, 'f000000000000000');
  assert (r ->> 'modo') = 'todos' and (r ->> 'cupo')::int = 4, r::text;
  assert (r ->> 'nivel')::int between 0 and 3, r::text;
  for k in 1..3 loop
    perform public.arena_buscar(j, 'f00000000000000' || k::text, 'Piloto' || k::text);
  end loop;
  assert (public.arena_estado(sala, 'f000000000000000') ->> 'empezada')::boolean, 'con 4 empieza';
  -- Trofeos por puesto entre personas; dos no pueden ser primeros
  update public.arena_salas set inicio = now() - interval '1 minute' where id = sala;
  r := public.arena_resultado(sala, 'f000000000000000', 1);
  assert (r ->> 'delta')::int = 12, r::text;
  ok := false;
  begin
    perform public.arena_resultado(sala, 'f000000000000001', 1);
  exception when others then ok := true;
  end;
  assert ok, 'dos primeros no';
  r := public.arena_resultado(sala, 'f000000000000001', 2);
  assert (r ->> 'delta')::int = 5, r::text;
  -- Sala con amigos: codigo y todos contra todos
  r := public.arena_privada_crear(j, 'f100000000000000', 'Lucia', 'todos');
  assert (r ->> 'modo') = 'todos' and length(r ->> 'codigo') > 0, r::text;
  r := public.arena_privada_unir(j, 'f100000000000001', 'Marta', r ->> 'codigo');
  assert (r ->> 'slot')::int = 1, r::text;
  -- Un juego sin directo sigue sin salas
  ok := false;
  begin
    perform public.arena_buscar(jt, 'f200000000000000', 'Ana');
  exception when others then ok := sqlerrm = 'unknown_game';
  end;
  assert ok, 'tenis sin salas';
  delete from public.projects where user_id = a;
  raise notice 'KARTS ONLINE OK';
end;
$$;

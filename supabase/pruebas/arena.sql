\set ON_ERROR_STOP 1
do $$
declare
  a uuid; p uuid; j uuid; r jsonb; r2 jsonb; n int; rec record; sala uuid;
  s1 text := 'aaaaaaaaaaaaaaa1'; s2 text := 'bbbbbbbbbbbbbbb2'; s3 text := 'ccccccccccccccc3'; s4 text := 'ddddddddddddddd4'; s5 text := 'eeeeeeeeeeeeeee5';
begin
  insert into auth.users (email, email_confirmed_at) values ('are-a@x.com', now()) returning id into a;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Robots', '{"titulo":"Robots","genero":"arena","niveles":["uno","dos","tres"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  -- Buscar: valida y junta a los jugadores en la misma sala, cada uno con su puesto de salida
  begin perform public.arena_buscar(j, s1, 'p0lla'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_alias%', sqlerrm; end;
  r := public.arena_buscar(j, s1, 'Dani');
  sala := (r ->> 'sala')::uuid;
  assert (r ->> 'slot')::int = 0;
  r := public.arena_buscar(j, s2, 'Lucia');
  assert (r ->> 'sala')::uuid = sala and (r ->> 'slot')::int = 1, r::text;
  r := public.arena_buscar(j, s1, 'Dani');
  assert (r ->> 'sala')::uuid = sala and (r ->> 'slot')::int = 0, 'volver a buscar no duplica';
  -- Estado: aun no empieza; quien no esta, no ve nada
  r := public.arena_estado(sala, s1);
  assert not (r ->> 'empezada')::boolean and jsonb_array_length(r -> 'jugadores') = 2 and (r ->> 'nivel')::int between 0 and 2, r::text;
  begin perform public.arena_estado(sala, s5); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_in_room%', sqlerrm; end;
  -- Con 4 empieza (3 s de cuenta atras) y el quinto va a otra sala
  perform public.arena_buscar(j, s3, 'Pepe');
  perform public.arena_buscar(j, s4, 'Ana');
  r := public.arena_estado(sala, s2);
  assert (r ->> 'empezada')::boolean and (r ->> 'en')::numeric between 2 and 3, r::text;
  r2 := public.arena_buscar(j, s5, 'Iker');
  assert (r2 ->> 'sala')::uuid <> sala;
  -- Resultado: solo despues de empezar, una vez, y un solo primero
  begin perform public.arena_resultado(sala, s1, 1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_started%', sqlerrm; end;
  update public.arena_salas set inicio = now() - interval '1 minute' where id = sala;
  r := public.arena_resultado(sala, s1, 1);
  assert (r ->> 'trofeos')::int = 12 and (r ->> 'delta')::int = 12, r::text;
  begin perform public.arena_resultado(sala, s1, 1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%already_closed%', sqlerrm; end;
  begin perform public.arena_resultado(sala, s2, 1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_result%', sqlerrm; end;
  r := public.arena_resultado(sala, s2, 4);
  assert (r ->> 'trofeos')::int = 0, 'nunca por debajo de 0';
  perform public.arena_resultado(sala, s3, 2);
  select * into rec from public.arena_top(j, s3, 1) where tuyo;
  assert rec.alias = 'Pepe' and rec.posicion = 2 and rec.trofeos = 5, rec::text;
  -- Una sala vieja empieza sola (con bots)
  update public.arena_salas set created_at = now() - interval '30 seconds' where id = (r2 ->> 'sala')::uuid;
  r := public.arena_estado((r2 ->> 'sala')::uuid, s5);
  assert (r ->> 'empezada')::boolean and jsonb_array_length(r -> 'jugadores') = 1, r::text;
  -- Solo juegos de arena
  insert into public.projects (user_id, title, spec, files) values (a, 'Otro', '{"genero":"plataformas"}'::jsonb, '{}'::jsonb) returning telemetria_id into j;
  begin perform public.arena_buscar(j, s1, 'Dani'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%unknown_game%', sqlerrm; end;
  assert not has_function_privilege('anon', 'public.arena_limpiar()', 'execute');
  delete from public.projects where id = p;
  assert not exists (select 1 from public.arena_perfiles where alias = 'Dani');
  raise notice 'ARENA OK';
end;
$$;

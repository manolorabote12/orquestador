\set ON_ERROR_STOP 1
do $$
declare
  a uuid; p uuid; j uuid; r jsonb; sala uuid; cod text;
  s1 text := 'aaaaaaaaaaaaaaa1'; s2 text := 'bbbbbbbbbbbbbbb2'; s3 text := 'ccccccccccccccc3';
begin
  insert into auth.users (email, email_confirmed_at) values ('apr-a@x.com', now()) returning id into a;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Robots', '{"titulo":"Robots","genero":"arena","niveles":["uno","dos"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  r := public.arena_privada_crear(j, s1, 'Dani');
  sala := (r ->> 'sala')::uuid; cod := r ->> 'codigo';
  assert (r ->> 'slot')::int = 0 and char_length(cod) = 6;
  -- Las publicas no entran en la privada
  r := public.arena_buscar(j, s3, 'Pepe');
  assert (r ->> 'sala')::uuid <> sala;
  r := public.arena_privada_unir(j, s2, 'Lucia', lower(cod));
  assert (r ->> 'sala')::uuid = sala and (r ->> 'slot')::int = 1, r::text;
  begin perform public.arena_privada_unir(j, s3, 'Pepe', 'ZZZZZZ'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%unknown_room%', sqlerrm; end;
  -- No empieza sola por tiempo
  update public.arena_salas set created_at = now() - interval '1 minute' where id = sala;
  r := public.arena_estado(sala, s2);
  assert not (r ->> 'empezada')::boolean and (r ->> 'privada')::boolean and (r ->> 'en')::numeric = -1, r::text;
  -- Solo quien la creo la empieza
  begin perform public.arena_empezar(sala, s2); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_allowed%', sqlerrm; end;
  perform public.arena_empezar(sala, s1);
  r := public.arena_estado(sala, s2);
  assert (r ->> 'empezada')::boolean and jsonb_array_length(r -> 'jugadores') = 2, r::text;
  -- Ya empezada: el codigo no sirve
  begin perform public.arena_privada_unir(j, s3, 'Pepe', cod); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%unknown_room%', sqlerrm; end;
  delete from public.projects where id = p;
  raise notice 'ARENA PRIVADA OK';
end;
$$;

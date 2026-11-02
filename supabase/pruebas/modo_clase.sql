\set ON_ERROR_STOP 1
do $$
declare
  u uuid; otro uuid; p uuid; j uuid; cod text; r jsonb; s1 text := 'abcdefabcdef0001'; s2 text := 'abcdefabcdef0002';
begin
  insert into auth.users (email, email_confirmed_at) values ('clase-a@x.com', now()) returning id into u;
  insert into auth.users (email, email_confirmed_at) values ('clase-b@x.com', now()) returning id into otro;
  insert into public.projects (user_id, title, spec, files) values (u, 'Tablas', '{}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  perform set_config('request.jwt.claim.sub', u::text, false);
  cod := public.clase_crear(p, '3º B');
  assert cod ~ '^[A-Z2-9]{6}$', cod;
  begin perform public.clase_unirse(j, 'ZZZZZZ', s1, 'Lucia'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_code%', sqlerrm; end;
  begin perform public.clase_unirse(gen_random_uuid(), cod, s1, 'Lucia'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_code%', sqlerrm; end;
  r := public.clase_unirse(j, lower(cod), s1, 'Lucia');
  assert r ->> 'nombre' = '3º B', r::text;
  perform public.clase_unirse(j, cod, s2, 'Marcos');
  perform public.clase_progreso(j, cod, s1, 5, 12, 30);
  perform public.clase_progreso(j, cod, s1, 3, 2, 10);
  begin perform public.clase_progreso(j, cod, 'abcdefabcdef0009', 1, 1, 1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_joined%', sqlerrm; end;
  r := public.clases_autor(p);
  assert jsonb_array_length(r) = 1 and jsonb_array_length(r -> 0 -> 'alumnos') = 2, r::text;
  assert r -> 0 -> 'alumnos' -> 0 ->> 'alias' = 'Lucia' and (r -> 0 -> 'alumnos' -> 0 ->> 'niveles')::int = 5
    and (r -> 0 -> 'alumnos' -> 0 ->> 'minutos')::int = 30, 'el progreso nunca baja';
  perform public.clase_progreso(j, cod, s2, 3, 6, 12, 4, 7);
  r := public.clases_autor(p);
  assert (r -> 0 -> 'alumnos' -> 1 ->> 'nivel_actual')::int = 4 and (r -> 0 -> 'alumnos' -> 1 ->> 'intentos')::int = 7, r::text;
  perform set_config('request.jwt.claim.sub', otro::text, false);
  assert public.clases_autor(p) = '[]'::jsonb, 'otro no ve la clase';
  begin perform public.clase_vaciar(cod); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_found%', sqlerrm; end;
  perform set_config('request.jwt.claim.sub', u::text, false);
  perform public.clase_vaciar(lower(cod));
  r := public.clases_autor(p);
  assert jsonb_array_length(r) = 1 and jsonb_array_length(r -> 0 -> 'alumnos') = 0, 'vaciar deja la clase sin alumnos';
  perform set_config('request.jwt.claim.sub', otro::text, false);
  begin perform public.clase_crear(p, 'X'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  begin perform public.clase_cerrar(cod); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_found%', sqlerrm; end;
  perform set_config('request.jwt.claim.sub', u::text, false);
  perform public.clase_cerrar(cod);
  assert public.clases_autor(p) = '[]'::jsonb;
  raise notice 'MODO CLASE OK';
end $$;
select 'MODO CLASE OK';

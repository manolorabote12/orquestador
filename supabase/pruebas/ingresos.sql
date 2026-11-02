\set ON_ERROR_STOP 1
do $$
declare
  a uuid; b uuid; p uuid; j uuid; r jsonb; d jsonb;
begin
  insert into auth.users (email, email_confirmed_at) values ('ing-a@x.com', now()) returning id into a;
  insert into auth.users (email, email_confirmed_at) values ('ing-b@x.com', now()) returning id into b;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Ingresos', '{"titulo":"Ingresos","genero":"plataformas","niveles":["uno"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  -- 3 jugadores empezaron hace 10 dias; 2 volvieron al dia siguiente, 1 a los 7 dias. Uno nuevo hoy.
  insert into public.partidas (juego, version, sesion, nivel, resultado, segundos, muertes, created_at) values
    (j, 1, 's1', 0, 'gana', 10, 0, now() - interval '10 days'),
    (j, 1, 's2', 0, 'gana', 10, 0, now() - interval '10 days'),
    (j, 1, 's3', 0, 'muere', 10, 1, now() - interval '10 days'),
    (j, 1, 's1', 1, 'gana', 10, 0, now() - interval '9 days'),
    (j, 1, 's2', 1, 'gana', 10, 0, now() - interval '9 days'),
    (j, 1, 's1', 2, 'gana', 10, 0, now() - interval '3 days'),
    (j, 1, 's4', 0, 'gana', 10, 0, now());
  insert into public.juego_compras (juego, producto, token, sesion, created_at) values
    (j, 'monedas_500', 't-ing-1', 'aaaaaaaaaaaaaaa1', now()),
    (j, 'monedas_500', 't-ing-2', 'aaaaaaaaaaaaaaa1', now() - interval '2 days'),
    (j, 'sin_anuncios', 't-ing-3', 'aaaaaaaaaaaaaaa2', now() - interval '1 days');
  perform set_config('request.jwt.claim.sub', b::text, false);
  begin perform public.juego_ingresos(p); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  perform set_config('request.jwt.claim.sub', a::text, false);
  r := public.juego_ingresos(p, 30);
  assert jsonb_array_length(r -> 'dias') = 30, (r -> 'dias')::text;
  d := r -> 'dias' -> 29;
  assert (d ->> 'jugadores')::int = 1 and (d ->> 'nuevos')::int = 1 and (d ->> 'compras')::int = 1 and (d ->> 'euros')::numeric = 0.99, d::text;
  d := r -> 'dias' -> 19;
  assert (d ->> 'jugadores')::int = 3 and (d ->> 'nuevos')::int = 3 and (d ->> 'partidas')::int = 3, d::text;
  assert (r ->> 'total_euros')::numeric = 4.97, r::text;
  assert (r ->> 'neto_euros')::numeric = 4.22, r::text;
  assert (r ->> 'd1')::int = 67, r::text;  -- 2 de 3 (el de hoy aun no cuenta)
  assert (r ->> 'd7')::int = 33, r::text;  -- 1 de 3
  assert (r -> 'productos' -> 0 ->> 'producto') = 'sin_anuncios', r::text;
  assert (r ->> 'jugadores_total')::int = 4, r::text;
  delete from public.partidas where juego = j;
  delete from public.projects where id = p;
  raise notice 'INGRESOS OK';
end;
$$;

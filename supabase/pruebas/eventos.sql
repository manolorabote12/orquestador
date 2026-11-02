\set ON_ERROR_STOP 1
do $$
declare
  a uuid; b uuid; p uuid; j uuid; e1 bigint; e2 bigint; r jsonb; n int;
  s1 text := 'aaaaaaaaaaaaaaa1'; s2 text := 'bbbbbbbbbbbbbbb2';
begin
  insert into auth.users (email, email_confirmed_at) values ('ev-a@x.com', now()) returning id into a;
  insert into auth.users (email, email_confirmed_at) values ('ev-b@x.com', now()) returning id into b;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Eventos', '{"titulo":"Eventos","genero":"plataformas","niveles":["uno"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  assert public.evento_actual(j, s1) is null;
  -- Solo el autor
  perform set_config('request.jwt.claim.sub', b::text, false);
  begin perform public.evento_crear(p, 'regalo', 'Fiesta', now(), now() + interval '1 day', 100); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  perform set_config('request.jwt.claim.sub', a::text, false);
  begin perform public.evento_crear(p, 'regalo', 'Fiesta p.u.t.a', now(), now() + interval '1 day', 100); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_title%', sqlerrm; end;
  begin perform public.evento_crear(p, 'regalo', 'Fiesta', now(), now() + interval '20 days', 100); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_dates%', sqlerrm; end;
  begin perform public.evento_crear(p, 'regalo', 'Fiesta', now(), now() + interval '1 day', 9000); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_gift%', sqlerrm; end;
  begin perform public.evento_crear(p, 'gratis', 'Fiesta', now(), now() + interval '1 day', 1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_type%', sqlerrm; end;
  assert public._evento_titulo_ok('Fin de semana extraordinariamente dorado');
  e1 := public.evento_crear(p, 'regalo', '¡Regalo de otoño!', now() - interval '1 minute', now() + interval '2 days', 120);
  begin perform public.evento_crear(p, 'monedas_x2', 'Doble', now() + interval '1 day', now() + interval '3 days'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%overlap%', sqlerrm; end;
  e2 := public.evento_crear(p, 'monedas_x2', 'Monedas dobles', now() + interval '3 days', now() + interval '5 days');
  select count(*) into n from public.eventos_autor(p);
  assert n = 2;
  -- Jugadores
  r := public.evento_actual(j, s1);
  assert (r ->> 'id')::bigint = e1 and r ->> 'tipo' = 'regalo' and (r ->> 'regalo')::int = 120 and not (r ->> 'cobrado')::boolean, r::text;
  assert public.evento_regalo_cobrar(j, s1) = 120;
  assert public.evento_regalo_cobrar(j, s1) = 0;
  assert (public.evento_actual(j, s1) ->> 'cobrado')::boolean;
  assert public.evento_regalo_cobrar(j, s2) = 120;
  assert (select cobros from public.eventos_autor(p) where id = e1) = 2;
  -- Monedas x2 en marcha: no hay regalo que cobrar
  update public.juego_eventos set inicio = now() - interval '4 days', fin = now() - interval '3 days' where id = e1;
  update public.juego_eventos set inicio = now() - interval '1 hour' where id = e2;
  assert public.evento_actual(j, s1) ->> 'tipo' = 'monedas_x2';
  assert public.evento_regalo_cobrar(j, s2) = 0;
  begin perform public.evento_actual(j, 'mal'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_session%', sqlerrm; end;
  -- Borrar: solo el autor
  perform set_config('request.jwt.claim.sub', b::text, false);
  begin perform public.evento_borrar(e2); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_found%', sqlerrm; end;
  perform set_config('request.jwt.claim.sub', a::text, false);
  perform public.evento_borrar(e2);
  assert public.evento_actual(j, s1) is null;
  delete from public.projects where id = p;
  assert not exists (select 1 from public.juego_eventos where juego = j);
  raise notice 'EVENTOS OK';
end;
$$;

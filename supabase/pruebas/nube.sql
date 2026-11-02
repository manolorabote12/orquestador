\set ON_ERROR_STOP 1
do $$
declare
  a uuid; p uuid; j uuid; r jsonb; r2 jsonb; cod text; i int;
  s1 text := 'aaaaaaaaaaaaaaa1';
begin
  insert into auth.users (email, email_confirmed_at) values ('nube-a@x.com', now()) returning id into a;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Nube', '{"titulo":"Nube","genero":"plataformas","niveles":["uno"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  r := public.nube_guardar(j, s1, '{"meta": {"wallet": 500}}'::jsonb);
  cod := r ->> 'codigo';
  assert cod ~ '^[A-Z2-9]{8}$' and (r ->> 'pin') ~ '^[0-9]{6}$', r::text;
  assert (public.nube_restaurar(j, lower(cod), r ->> 'pin') -> 'meta' ->> 'wallet')::int = 500;
  -- Guardar otra vez: mismo codigo, PIN nuevo (el viejo deja de valer salvo que coincida).
  r2 := public.nube_guardar(j, s1, '{"meta": {"wallet": 900}}'::jsonb);
  assert r2 ->> 'codigo' = cod;
  assert (public.nube_restaurar(j, cod, r2 ->> 'pin') -> 'meta' ->> 'wallet')::int = 900;
  -- Otro juego no lo ve
  assert public.nube_restaurar(gen_random_uuid(), cod, r2 ->> 'pin') is null;
  -- Datos malos
  begin perform public.nube_guardar(j, s1, '[1,2]'::jsonb); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_data%', sqlerrm; end;
  begin perform public.nube_guardar(j, s1, jsonb_build_object('x', repeat('a', 300000))); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_data%', sqlerrm; end;
  begin perform public.nube_guardar(j, 'nope', '{}'::jsonb); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_session%', sqlerrm; end;
  -- PIN equivocado (el de otro juego ya conto uno): a los 5 fallos se bloquea aunque luego aciertes
  for i in 1..3 loop assert public.nube_restaurar(j, cod, '000000x') is null; end loop;
  assert public.nube_restaurar(j, cod, r2 ->> 'pin') is not null;
  assert public.nube_restaurar(j, cod, 'mal') is null;
  begin perform public.nube_restaurar(j, cod, r2 ->> 'pin'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%rate_limited%', sqlerrm; end;
  delete from public.nube_fallos where codigo = cod;
  -- Limpieza de partidas viejas
  update public.nube_partidas set updated_at = now() - interval '200 days' where codigo = cod;
  assert public.nube_limpiar() >= 1;
  assert public.nube_restaurar(j, cod, r2 ->> 'pin') is null;
  delete from public.nube_fallos where codigo = cod;
  delete from public.projects where id = p;
  raise notice 'NUBE OK';
end;
$$;

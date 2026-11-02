\set ON_ERROR_STOP 1
do $$
declare
  a uuid; b uuid; p uuid; j uuid; r jsonb; n int; c0 int;
  s1 text := 'aaaaaaaaaaaaaaa1'; s2 text := 'bbbbbbbbbbbbbbb2';
begin
  insert into auth.users (email, email_confirmed_at) values ('cha-a@x.com', now()) returning id into a;
  insert into auth.users (email, email_confirmed_at) values ('cha-b@x.com', now()) returning id into b;
  update public.profiles set credits = 200 where id = a;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Bigotes', '{"titulo":"Bigotes","heroe":{"nombre":"Bigotes","descripcion":"a cat"},"niveles":["uno"]}'::jsonb, '{}'::jsonb)
    returning id, telemetria_id into p, j;
  assert not public.charla_activa(j);
  -- Sin cupo: el servidor no llama a la IA.
  begin perform public.charla_reservar(j, s1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%no_quota%', sqlerrm; end;
  -- Solo el autor activa (y paga con tuercas).
  perform set_config('request.jwt.claim.sub', b::text, false);
  begin perform public.charla_activar(p); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  perform set_config('request.jwt.claim.sub', a::text, false);
  select credits into c0 from public.profiles where id = a;
  r := public.charla_activar(p);
  assert (r ->> 'mensajes')::int = 500, r::text;
  assert public.charla_activa(j);
  assert (select credits from public.profiles where id = a) = c0 - 40;
  assert exists (select 1 from public.credit_ledger where user_id = a and reason = 'charla_pack' and amount = -40);
  -- Reservar: valida sesion y juego, descuenta y devuelve el diseno (los personajes salen de ahi).
  begin perform public.charla_reservar(j, 'corta'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_session%', sqlerrm; end;
  begin perform public.charla_reservar(gen_random_uuid(), s1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%unknown_game%', sqlerrm; end;
  r := public.charla_reservar(j, s1);
  assert r -> 'spec' -> 'heroe' ->> 'nombre' = 'Bigotes', r::text;
  assert (select mensajes from public.charla_cupos where project_id = p) = 499;
  -- Si la IA falla, el mensaje vuelve al cupo
  perform public.charla_coste((r ->> 'envio')::bigint, 0.0004, false);
  assert (select mensajes from public.charla_cupos where project_id = p) = 500;
  -- Limite por dispositivo
  update public.settings set value = 3 where key = 'charla_por_sesion_dia';
  perform public.charla_reservar(j, s2);
  perform public.charla_reservar(j, s2);
  perform public.charla_reservar(j, s2);
  begin perform public.charla_reservar(j, s2); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%rate_limited%', sqlerrm; end;
  update public.settings set value = 30 where key = 'charla_por_sesion_dia';
  -- Estado y pausa (solo el autor)
  r := public.charla_estado(p);
  assert (r ->> 'activa')::boolean and (r ->> 'hoy')::int = 4 and (r ->> 'precio')::int = 40, r::text;
  perform public.charla_pausar(p, false);
  begin perform public.charla_reservar(j, s1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%no_quota%', sqlerrm; end;
  perform set_config('request.jwt.claim.sub', b::text, false);
  begin perform public.charla_pausar(p, true); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  -- El juego (anon) no puede reservar ni ver las tablas
  assert not has_function_privilege('anon', 'public.charla_reservar(uuid, text)', 'execute');
  assert not has_function_privilege('authenticated', 'public.charla_reservar(uuid, text)', 'execute');
  assert not has_function_privilege('anon', 'public.charla_activar(uuid)', 'execute');
  -- Borrar el juego borra su cupo
  delete from public.projects where id = p;
  assert not exists (select 1 from public.charla_cupos where project_id = p);
  raise notice 'CHARLA OK';
end;
$$;

\set ON_ERROR_STOP 1
do $$
declare
  a uuid; b uuid; p uuid; r jsonb; i integer;
begin
  insert into auth.users (email, email_confirmed_at) values ('res-a@x.com', now()) returning id into a;
  insert into auth.users (email, email_confirmed_at) values ('res-b@x.com', now()) returning id into b;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Gatos', '{"titulo":"Gatos Veloces","genero":"plataformas","niveles":["uno"]}'::jsonb, '{}'::jsonb) returning id into p;
  r := public.resena_borrador_reservar(a, p);
  assert r ->> 'titulo' = 'Gatos Veloces', r::text;
  perform public.resena_borrador_coste((r ->> 'id')::bigint, 0.0004);
  assert (select coste_usd from public.resenas_borradores where id = (r ->> 'id')::bigint) = 0.0004;
  -- Otro usuario no puede usar el juego de A.
  begin perform public.resena_borrador_reservar(b, p); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  -- Cupo diario.
  update public.settings set value = 3 where key = 'resenas_borradores_dia';
  perform public.resena_borrador_reservar(a, p);
  perform public.resena_borrador_reservar(a, p);
  begin perform public.resena_borrador_reservar(a, p); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%rate_limited%', sqlerrm; end;
  update public.settings set value = 60 where key = 'resenas_borradores_dia';
  -- Respuestas enviadas.
  perform public.resena_anotar(a, p, 'gp:AOqp', '¡Gracias por jugar!');
  begin perform public.resena_anotar(b, p, 'gp:AOqp', 'hola'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  begin perform public.resena_anotar(a, p, 'gp:AOqp', repeat('x', 351)); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%check%' or sqlerrm like '%violates%', sqlerrm; end;
  select count(*) into i from public.resenas_respuestas where project_id = p;
  assert i = 1, i::text;
  -- La app no puede llamarlas.
  assert not has_function_privilege('authenticated', 'public.resena_borrador_reservar(uuid, uuid)', 'execute');
  assert not has_function_privilege('anon', 'public.resena_anotar(uuid, uuid, text, text)', 'execute');
  delete from public.projects where id = p;
  assert (select count(*) from public.resenas_borradores where project_id = p) = 0;
  raise notice 'RESENAS OK';
end;
$$;

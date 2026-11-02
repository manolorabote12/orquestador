\set ON_ERROR_STOP 1
do $$
declare
  a uuid; b uuid; p uuid; e text;
begin
  insert into auth.users (email, email_confirmed_at) values ('ref-a@x.com', now()) returning id into a;
  insert into auth.users (email, email_confirmed_at) values ('ref-b@x.com', now()) returning id into b;
  insert into public.projects (user_id, title, spec, files) values (a, 'Dibujo', '{}'::jsonb, '{}'::jsonb) returning id into p;
  begin perform public.referencia_reservar(b, p); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  perform public.referencia_reservar(a, p);
  assert (select estado from public.referencias where project_id = p) = 'pendiente';
  perform public.referencia_resultado(p, true, 'a round orange cat drawn with crayons', '', 0.002);
  select estado into e from public.referencias where project_id = p;
  assert e = 'aprobada';
  perform public.referencia_reservar(a, p);
  assert (select estado from public.referencias where project_id = p) = 'pendiente', 'una nueva subida anula la aprobacion';
  perform public.referencia_resultado(p, false, '', 'Es una foto de una persona', 0.002);
  assert (select estado || motivo from public.referencias where project_id = p) = 'rechazadaEs una foto de una persona';
  update public.settings set value = 2 where key = 'referencias_dia';
  begin perform public.referencia_reservar(a, p); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%rate_limited%', sqlerrm; end;
  update public.settings set value = 10 where key = 'referencias_dia';
  assert not has_function_privilege('authenticated', 'public.referencia_resultado(uuid, boolean, text, text, numeric)', 'execute');
  assert exists (select 1 from storage.buckets where id = 'referencias' and not public);
  delete from public.projects where id = p;
  raise notice 'REFERENCIAS OK';
end;
$$;

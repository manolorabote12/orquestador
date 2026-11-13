\set ON_ERROR_STOP 1
-- Portal web: lista del escaparate con el enlace de Google Play solo si esta en produccion.
do $$
declare
  u uuid; p uuid; q uuid;
begin
  insert into auth.users (email, email_confirmed_at) values ('portal@x.com', now()) returning id into u;
  insert into public.projects (user_id, title, spec, files, version, play)
    values (u, 'En Play', '{"titulo":"En Play","genero":"golf"}'::jsonb, '{"web":"a/1/web/index.pck"}'::jsonb, 1,
      '{"paquete":"com.orq.enplay","estado":"subido","pista":"production"}'::jsonb) returning id into p;
  insert into public.projects (user_id, title, spec, files, version, play)
    values (u, 'En prueba', '{"titulo":"En prueba","genero":"golf"}'::jsonb, '{"web":"a/2/web/index.pck"}'::jsonb, 1,
      '{"paquete":"com.orq.prueba","estado":"subido","pista":"alpha"}'::jsonb) returning id into q;
  perform public.escaparate_publicar(u, p, 'Ana');
  perform public.escaparate_publicar(u, q, 'Ana');
  assert public.portal_play(p) = 'com.orq.enplay', 'produccion: con enlace';
  assert public.portal_play(q) is null, 'prueba cerrada: sin enlace';
  assert (select play from public.portal_lista('nuevos') where project_id = p) = 'com.orq.enplay';
  assert (select count(*) from public.portal_lista('nuevos') where project_id in (p, q)) = 2;
  update public.escaparate set oculto = true where project_id = p;
  assert public.portal_play(p) is null, 'oculto: nada';
  assert has_function_privilege('anon', 'public.portal_lista(text, text)', 'execute');
  delete from public.projects where user_id = u;
  raise notice 'portal OK';
end;
$$;

\set ON_ERROR_STOP 1
do $$
declare
  a uuid; b uuid; c uuid; viejo uuid; r jsonb; cod text; ca int; cb int; p uuid; q uuid; x record;
begin
  insert into auth.users (email, email_confirmed_at) values ('inv-a@x.com', now()) returning id into a;
  insert into auth.users (email, email_confirmed_at) values ('inv-b@x.com', now()) returning id into b;
  insert into auth.users (email, email_confirmed_at) values ('inv-c@x.com', now()) returning id into c;
  insert into auth.users (email, email_confirmed_at) values ('inv-v@x.com', now()) returning id into viejo;
  update public.profiles set created_at = now() - interval '30 days' where id = viejo;
  perform set_config('request.jwt.claim.sub', a::text, false);
  r := public.mi_invitacion();
  cod := r ->> 'codigo';
  assert length(cod) = 7 and (public.mi_invitacion() ->> 'codigo') = cod, r::text;
  begin perform public.usar_invitacion(cod); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%own_code%', sqlerrm; end;
  perform set_config('request.jwt.claim.sub', viejo::text, false);
  begin perform public.usar_invitacion(cod); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%too_late%', sqlerrm; end;
  perform set_config('request.jwt.claim.sub', b::text, false);
  begin perform public.usar_invitacion('NOEXIST'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_code%', sqlerrm; end;
  assert public.usar_invitacion(lower(cod)) = 'ok';
  begin perform public.usar_invitacion(cod); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%already_invited%', sqlerrm; end;
  -- B no puede invitar a A de vuelta (A ya tiene cuenta con proyectos? no: circulo).
  perform set_config('request.jwt.claim.sub', a::text, false);
  begin perform public.usar_invitacion(public.mi_invitacion() ->> 'codigo'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%own_code%', sqlerrm; end;
  select credits into ca from public.profiles where id = a;
  select credits into cb from public.profiles where id = b;
  -- Un juego (el de bienvenida) ya no paga: crear cuentas en cadena no sale gratis.
  insert into public.projects (user_id, title, spec, files) values (b, 'Uno', '{}'::jsonb, '{"web":"b/u/v1/web/index.pck"}'::jsonb) returning id into p;
  assert (select credits from public.profiles where id = a) = ca and (select credits from public.profiles where id = b) = cb;
  -- La primera compra de B: los dos cobran 30. La segunda no paga otra vez.
  perform public.grant_purchase(b, 'tuercas_300', 'tok-inv-1', 'GPA.inv-1');
  assert (select credits from public.profiles where id = a) = ca + 30 and (select credits from public.profiles where id = b) = cb + 180 + 30;
  perform public.grant_purchase(b, 'tuercas_300', 'tok-inv-2', 'GPA.inv-2');
  assert (select credits from public.profiles where id = a) = ca + 30;
  perform set_config('request.jwt.claim.sub', a::text, false);
  r := public.mi_invitacion();
  assert (r ->> 'invitados')::int = 1 and (r ->> 'pagados')::int = 1 and (r ->> 'ganadas')::int = 30, r::text;
  -- Tope mensual: con el tope alcanzado ya no paga a nadie.
  update public.settings set value = 1 where key = 'invitaciones_mes';
  perform set_config('request.jwt.claim.sub', c::text, false);
  perform public.usar_invitacion(cod);
  select credits into cb from public.profiles where id = c;
  perform public.grant_purchase(c, 'tuercas_300', 'tok-inv-3', 'GPA.inv-3');
  assert (select credits from public.profiles where id = c) = cb + 180 and (select credits from public.profiles where id = a) = ca + 30;
  update public.settings set value = 20 where key = 'invitaciones_mes';
  assert not has_function_privilege('anon', 'public.usar_invitacion(text)', 'execute');
  -- Ranking semanal: solo lo que se ha movido esta semana; los me gusta pesan mas.
  insert into public.projects (user_id, title, spec, files, version)
    values (a, 'Rank', '{"titulo":"Rank","genero":"golf"}'::jsonb, '{"web":"a/r/v1/web/index.pck"}'::jsonb, 1) returning id into q;
  perform public.escaparate_publicar(a, q, 'A');
  perform public.escaparate_publicar(b, p, 'B');
  for i in 1..3 loop perform public.escaparate_jugada(p); end loop;
  perform set_config('request.jwt.claim.sub', c::text, false);
  perform public.escaparate_megusta(q);
  select * into x from public.escaparate_lista('semana') limit 1;
  assert x.project_id = q, x::text;
  assert (select count(*) from public.escaparate_lista('semana')) = 2;
  perform public.escaparate_megusta(q);
  assert (select megusta from public.escaparate_dia where project_id = q) = 0;
  delete from public.projects where user_id in (a, b, c);
  raise notice 'INVITACIONES OK';
end;
$$;

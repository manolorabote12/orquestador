\set ON_ERROR_STOP 1
-- Galeria tipo Poki: anuncios por juego, reparto del mes y ganancias del creador (tuercas o dinero).
do $$
declare
  autor uuid; otro uuid; jugador uuid; p1 uuid; p2 uuid; r jsonb; n integer;
begin
  insert into auth.users (email, email_confirmed_at) values ('creador.gal@example.com', now()) returning id into autor;
  insert into auth.users (email, email_confirmed_at) values ('creador2.gal@example.com', now()) returning id into otro;
  insert into auth.users (email, email_confirmed_at) values ('jugador.gal@example.com', now()) returning id into jugador;
  insert into public.projects (user_id, title, spec) values (autor, 'Juego A', '{}'::jsonb) returning id into p1;
  insert into public.projects (user_id, title, spec) values (otro, 'Juego B', '{}'::jsonb) returning id into p2;
  insert into public.escaparate (project_id, user_id, titulo, genero, autor, version) values (p1, autor, 'Juego A', 'plataformas', 'Ana', 1);
  insert into public.escaparate (project_id, user_id, titulo, genero, autor, version) values (p2, otro, 'Juego B', 'puzle', 'Bea', 1);
  -- 1 - El autor jugando a su juego no cuenta; otro jugador si, con tope por juego y dia.
  perform set_config('request.jwt.claim.sub', autor::text, true);
  assert not public.galeria_anuncio(p1), 'el autor no cuenta';
  perform set_config('request.jwt.claim.sub', jugador::text, true);
  for n in 1..12 loop perform public.galeria_anuncio(p1); end loop;
  assert (select count(*) from public.galeria_anuncios where project_id = p1 and valido) = 10, 'tope por juego y dia';
  for n in 1..5 loop perform public.galeria_anuncio(p2, 'premio'); end loop;
  -- 2 - Reparto del mes: 50 % de 9,00 EUR = 450 centimos entre 10 y 5 anuncios.
  r := public.galeria_reparto(current_date, 900);
  assert (r ->> 'anuncios')::int = 15 and (r ->> 'repartido_cent')::int = 450, r::text;
  assert (select saldo_cent from public.creador_saldo where user_id = autor) = 300, 'Ana: 10/15 de 450';
  assert (select saldo_cent from public.creador_saldo where user_id = otro) = 150, 'Bea: 5/15 de 450';
  begin
    perform public.galeria_reparto(current_date, 900);
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%already_done%', sqlerrm; end;
  -- 3 - Ana ve sus ganancias y pasa 1 EUR a tuercas (150).
  perform set_config('request.jwt.claim.sub', autor::text, true);
  r := public.mis_ganancias();
  assert (r ->> 'saldo_cent')::int = 300 and not (r ->> 'cobro_activo')::boolean, r::text;
  update public.profiles set credits = 0 where id = autor;
  r := public.ganancias_a_tuercas(100);
  assert (r ->> 'tuercas')::int = 150 and (select credits from public.profiles where id = autor) = 150, r::text;
  begin
    perform public.ganancias_a_tuercas(1000);
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%insufficient%', sqlerrm; end;
  -- 4 - Cobro en dinero: apagado al principio; luego, desde el minimo y solo mayores.
  begin
    perform public.pedir_cobro('ana@example.com', 'Ana Perez', true);
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%cobros_off%', sqlerrm; end;
  update public.settings set value = 1 where key = 'cobro_dinero_activo';
  begin
    perform public.pedir_cobro('ana@example.com', 'Ana Perez', true);
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%below_minimum%', sqlerrm; end;
  update public.creador_saldo set saldo_cent = 2500 where user_id = autor;
  begin
    perform public.pedir_cobro('ana@example.com', 'Ana Perez', false);
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%adults_only%', sqlerrm; end;
  r := public.pedir_cobro('ana@example.com', 'Ana Perez', true);
  assert (r ->> 'cent')::int = 2500 and (select saldo_cent from public.creador_saldo where user_id = autor) = 0, r::text;
  -- 5 - Rechazado: el dinero vuelve. Pagado: queda cerrado.
  perform public.cobro_cerrar((select id from public.creador_cobros where user_id = autor), 'rechazado', 'PayPal no existe');
  assert (select saldo_cent from public.creador_saldo where user_id = autor) = 2500, 'devuelto';
  perform public.pedir_cobro('ana2@example.com', 'Ana Perez', true);
  assert public.cobro_cerrar((select max(id) from public.creador_cobros where user_id = autor), 'pagado') = 'pagado';
  update public.settings set value = 0 where key = 'cobro_dinero_activo';
  -- 6 - Seguridad.
  assert not has_function_privilege('authenticated', 'public.galeria_reparto(date, integer)', 'execute');
  assert not has_function_privilege('authenticated', 'public.cobro_cerrar(bigint, text, text)', 'execute');
  assert not has_function_privilege('anon', 'public.galeria_anuncio(uuid, text)', 'execute');
  perform set_config('request.jwt.claim.sub', '', true);
  raise notice 'galeria_ganancias OK';
end;
$$;

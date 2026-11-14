\set ON_ERROR_STOP 1
do $$
declare
  a uuid; p uuid; j uuid;
  s1 text := 'aaaaaaaaaaaaaaa1';
begin
  insert into auth.users (email, email_confirmed_at) values ('iap-a@x.com', now()) returning id into a;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Tienda', '{"titulo":"Tienda","genero":"plataformas","niveles":["uno"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  assert public.juego_compra_anotar(j, s1, 'monedas_500', 'tok-0000000001', 'GPA.1');
  assert not public.juego_compra_anotar(j, s1, 'monedas_500', 'tok-0000000001', 'GPA.1');
  assert public.juego_compra_anotar(j, s1, 'sin_anuncios', 'tok-0000000002', 'GPA.2');
  begin perform public.juego_compra_anotar(j, s1, 'gemas', 'tok-0000000003', null); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%unknown_product%', sqlerrm; end;
  assert public.iap_precio('monedas_3000') = 4.99;
  assert (select count(*) from public.juego_compras where juego = j) = 2;
  -- Compras a medida: el creador define su tienda (validada) y sus productos se anotan con su precio.
  perform set_config('request.jwt.claim.sub', a::text, true);
  begin perform public.set_project_tienda(p, '{"moneda":{"nombre":"Perlas"},"productos":[{"id":"X mal","tipo":"monedas","precio_cent":99,"cantidad":5}]}');
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_id%', sqlerrm; end;
  begin perform public.set_project_tienda(p, '{"moneda":{"nombre":"Perlas"},"productos":[{"id":"caro","tipo":"sin_anuncios","precio_cent":50000}]}');
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_price%', sqlerrm; end;
  perform public.set_project_tienda(p, '{"moneda":{"nombre":"Perlas","icono":"gem"},"productos":[
    {"id":"perlas_100","tipo":"monedas","cantidad":100,"precio_cent":99},
    {"id":"vip_mes","tipo":"vip","precio_cent":499,"periodo":"mes","extra_pct":50,"diario":30}]}');
  assert (select tienda #>> '{moneda,nombre}' from public.projects where id = p) = 'Perlas';
  assert public.juego_compra_anotar(j, s1, 'vip_mes', 'tok-0000000009', 'GPA.9');
  assert (select precio_eur from public.juego_compras where token = 'tok-0000000009') = 4.99;
  assert (public.juego_ingresos(p) ->> 'total_euros')::numeric = 0.99 + 2.99 + 4.99, public.juego_ingresos(p)::text;
  -- Galeria web: intentos de compra (uno por jugador y producto al dia) y la cuenta del mes.
  assert public.tienda_intento(j, s1, 'perlas_100');
  assert not public.tienda_intento(j, s1, 'perlas_100');
  assert public.tienda_intento(j, 'bbbbbbbbbbbbbbb2', 'vip_mes');
  assert not public.tienda_intento(j, s1, 'no_existe');
  assert (public.tienda_intentos_mes(current_date) ->> 'euros')::numeric >= 5.98;
  assert (public.tienda_intentos_mes(current_date) ->> 'comision_pct')::int = 10;
  assert has_function_privilege('anon', 'public.tienda_intento(uuid, text, text, text)', 'execute');
  assert not has_function_privilege('authenticated', 'public.tienda_intentos_mes(date)', 'execute');
  perform public.set_project_tienda(p, null);
  assert (select tienda from public.projects where id = p) is null;
  perform set_config('request.jwt.claim.sub', '', true);
  delete from public.projects where id = p;
  assert not exists (select 1 from public.juego_compras where juego = j);
  raise notice 'JUEGO COMPRAS OK';
end;
$$;

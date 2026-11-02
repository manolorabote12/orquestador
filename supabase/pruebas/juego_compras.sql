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
  delete from public.projects where id = p;
  assert not exists (select 1 from public.juego_compras where juego = j);
  raise notice 'JUEGO COMPRAS OK';
end;
$$;

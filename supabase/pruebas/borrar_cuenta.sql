\set ON_ERROR_STOP 1
do $$
declare
  u uuid; p uuid; r record; res jsonb; tele uuid; n int;
begin
  insert into auth.users (email, email_confirmed_at) values ('borrar@x.com', now()) returning id into u;
  update public.profiles set credits = 500 where id = u;
  select * into r from public.queue_game(u, 'un gato ninja que salta por tejados de noche');
  -- Con un trabajo en marcha no se puede borrar
  begin perform public.preparar_borrado(u); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%job_running%', sqlerrm; end;
  select * into r from public.claim_game_job('w1');
  p := public.complete_game_job(r.job_id, 0.1, 10, 'Bigotes', '{"titulo":"Bigotes"}'::jsonb, '{"proyecto":"x.zip"}'::jsonb);
  select telemetria_id into tele from public.projects where id = p;
  insert into public.partidas (juego, version, sesion, nivel, resultado, segundos, muertes) values (tele, 1, 's1', 1, 'gana', 30, 0);
  perform public.grant_purchase(u, 'tuercas_300', 'tok-borrar-1', 'GPA.1234-5678', null);
  perform public.grant_purchase(u, 'premium_mensual', 'tok-borrar-2', 'GPA.9999-0000', now() + interval '20 days');
  res := public.preparar_borrado(u);
  res := public.preparar_borrado(u); -- reintento tras un fallo: no duplica
  assert res -> 'juegos' ? p::text, res::text;
  assert (res ->> 'premium_activo')::boolean, 'avisa de la suscripcion activa';
  assert not exists (select 1 from public.partidas where juego = tele), 'borra las partidas de sus juegos';
  select count(*) into n from public.borrados b where b.pedidos @> '[{"pedido":"GPA.1234-5678"}]'::jsonb
    and b.huella <> u::text and b.pedidos::text not like '%' || u::text || '%';
  assert n = 1, 'guarda los pedidos sin el usuario';
  -- El borrado del usuario arrastra todo lo suyo
  delete from auth.users where id = u;
  assert not exists (select 1 from public.projects where user_id = u), 'proyectos';
  assert not exists (select 1 from public.jobs where user_id = u), 'trabajos';
  assert not exists (select 1 from public.purchases where user_id = u), 'compras';
  assert not exists (select 1 from public.credit_ledger where user_id = u), 'movimientos';
  raise notice 'BORRAR CUENTA OK';
end $$;
select 'BORRAR CUENTA OK';

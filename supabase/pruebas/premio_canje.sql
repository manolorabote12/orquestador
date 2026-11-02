\set ON_ERROR_STOP 1
do $$
declare
  u uuid; otro uuid; p uuid; j uuid; cod text; r jsonb;
begin
  insert into auth.users (email, email_confirmed_at) values ('canje-a@x.com', now()) returning id into u;
  insert into auth.users (email, email_confirmed_at) values ('canje-b@x.com', now()) returning id into otro;
  insert into public.projects (user_id, title, spec, files) values (u, 'Pan', '{}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  perform set_config('request.jwt.claim.sub', u::text, false);
  perform public.premio_guardar(p, 'Cafe gratis', 'CAFE', 2);
  cod := public.premio_ganado(j, 'abcdefabcdef0001', 2) ->> 'codigo';
  begin perform public.premio_canjear(p, 'hola'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_code%', sqlerrm; end;
  assert public.premio_canjear(p, 'CAFE-0000') ->> 'estado' = 'no_existe';
  r := public.premio_canjear(p, ' ' || lower(cod) || ' ');
  assert r ->> 'estado' = 'ok', r::text;
  r := public.premio_canjear(p, cod);
  assert r ->> 'estado' = 'ya_usado' and r ? 'canjeado_en', r::text;
  assert (public.premio_autor(p) ->> 'canjeados')::int = 1 and (public.premio_autor(p) ->> 'ganados')::int = 1;
  perform set_config('request.jwt.claim.sub', otro::text, false);
  begin perform public.premio_canjear(p, cod); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  raise notice 'PREMIO CANJE OK';
end $$;
select 'PREMIO CANJE OK';

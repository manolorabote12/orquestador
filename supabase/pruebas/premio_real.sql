\set ON_ERROR_STOP 1
do $$
declare
  u uuid; otro uuid; p uuid; j uuid; r jsonb; s1 text := 'abcdefabcdef0001'; s2 text := 'abcdefabcdef0002';
begin
  insert into auth.users (email, email_confirmed_at) values ('premio-a@x.com', now()) returning id into u;
  insert into auth.users (email, email_confirmed_at) values ('premio-b@x.com', now()) returning id into otro;
  insert into public.projects (user_id, title, spec, files) values (u, 'Panaderia', '{"titulo":"Pan"}'::jsonb, '{}'::jsonb)
    returning id, telemetria_id into p, j;
  perform set_config('request.jwt.claim.sub', u::text, false);
  assert public.premio_actual(j, s1) is null, 'sin premio';
  begin perform public.premio_guardar(p, '10 % en tu proxima compra', 'pan 10!', 3); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_code%', sqlerrm; end;
  begin perform public.premio_guardar(p, '<b>gratis</b>', 'PAN10', 3); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_text%', sqlerrm; end;
  begin perform public.premio_guardar(p, '10 % en tu proxima compra', 'PAN10', 3, '', 'http://inseguro.com'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_web%', sqlerrm; end;
  r := public.premio_guardar(p, '10 % en tu proxima compra', 'pan10', 3, 'Panaderia Luna, calle Mayor 3', 'https://panluna.es', current_date + 30);
  assert r ->> 'codigo' = 'PAN10' and (r ->> 'ganados')::int = 0, r::text;
  r := public.premio_actual(j, s1);
  assert r ->> 'texto' = '10 % en tu proxima compra' and (r ->> 'tras_nivel')::int = 3 and not (r ->> 'ganado')::boolean and not (r ? 'codigo'), r::text;
  begin perform public.premio_ganado(j, s1, 2); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_yet%', sqlerrm; end;
  r := public.premio_ganado(j, s1, 3);
  assert r ->> 'codigo' like 'PAN10-____' and r ->> 'codigo' = public.premio_ganado(j, s1, 4) ->> 'codigo', r::text;
  assert (public.premio_ganado(j, s2, 3) ->> 'codigo') <> (r ->> 'codigo'), 'cada jugador su codigo';
  assert (public.premio_actual(j, s1) ->> 'ganado')::boolean;
  assert (public.premio_autor(p) ->> 'ganados')::int = 2, 'el autor ve cuantos lo han ganado';
  perform set_config('request.jwt.claim.sub', otro::text, false);
  begin perform public.premio_guardar(p, 'Gratis todo', 'GRATIS', 1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  perform set_config('request.jwt.claim.sub', u::text, false);
  perform public.premio_guardar(p, '', '', 1);
  assert public.premio_actual(j, s1) is null, 'quitar el premio';
  raise notice 'PREMIO REAL OK';
end $$;
select 'PREMIO REAL OK';

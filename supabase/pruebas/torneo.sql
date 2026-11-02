\set ON_ERROR_STOP 1
do $$
declare
  a uuid; p uuid; j uuid; r jsonb; n int; rec record; v_pasada text;
  s1 text := 'aaaaaaaaaaaaaaa1'; s2 text := 'bbbbbbbbbbbbbbb2'; s3 text := 'ccccccccccccccc3';
begin
  insert into auth.users (email, email_confirmed_at) values ('tor-a@x.com', now()) returning id into a;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Bigotes', '{"titulo":"Bigotes","niveles":["uno","dos","tres","cuatro"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  -- Info: nivel de la semana dentro del juego y el mismo para todos
  r := public.torneo_info(j, s1);
  assert (r ->> 'nivel')::int between 0 and 3 and (r ->> 'segundos')::int between 1 and 604800, r::text;
  assert (public.torneo_info(j, s2) ->> 'nivel') = (r ->> 'nivel');
  assert public.torneo_semana() ~ '^\d{4}-S\d{2}$';
  begin perform public.torneo_info(gen_random_uuid(), s1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%unknown_game%', sqlerrm; end;
  -- Enviar: valida y guarda la mejor
  begin perform public.torneo_enviar(j, s1, 'p0lla', 100); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_alias%', sqlerrm; end;
  r := public.torneo_enviar(j, s1, 'Dani', 500);
  assert (r ->> 'posicion')::int = 1;
  r := public.torneo_enviar(j, s1, 'Dani', 200);
  assert (r ->> 'mejor')::int = 500, r::text;
  perform public.torneo_enviar(j, s2, 'Lucia', 900);
  perform public.torneo_enviar(j, s3, 'Pepe', 50);
  select * into rec from public.torneo_top(j, s3, 2) where tuyo;
  assert rec.posicion = 3 and rec.alias = 'Pepe', rec::text;
  select count(*) into n from public.torneo_top(j, null, 2);
  assert n = 2;
  assert (public.torneo_info(j, s1) ->> 'mejor')::int = 500;
  -- Premio: la semana pasada (se simula moviendo las marcas)
  v_pasada := public.torneo_semana(now() - interval '7 days');
  update public.torneo_marcas set semana = v_pasada where juego = j;
  r := public.torneo_info(j, s2);
  assert (r ->> 'premio')::int = 300 and (r ->> 'puesto_pasado')::int = 1, r::text;
  assert (public.torneo_info(j, s1) ->> 'premio')::int = 200;
  assert public.torneo_reclamar(j, s2) = 300;
  assert public.torneo_reclamar(j, s2) = 0;
  assert (public.torneo_info(j, s2) ->> 'premio')::int = 0;
  -- La semana nueva empieza vacia
  select count(*) into n from public.torneo_top(j, null, 10);
  assert n = 0;
  -- Limite por dispositivo
  update public.settings set value = 3 where key = 'torneo_envios_hora';
  begin
    for n in 1..5 loop perform public.torneo_enviar(j, s3, 'Pepe', 10 + n); end loop;
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%rate_limited%', sqlerrm; end;
  update public.settings set value = 40 where key = 'torneo_envios_hora';
  assert not has_function_privilege('anon', 'public._torneo_nivel(uuid, text)', 'execute');
  delete from public.projects where id = p;
  assert not exists (select 1 from public.torneo_marcas where juego = j);
  raise notice 'TORNEO OK';
end;
$$;

\set ON_ERROR_STOP 1
do $$
declare
  dueno uuid; p uuid; r record; c uuid; t uuid[] := '{}'; u uuid; i int; d int; j jsonb; otro uuid; c2 uuid;
begin
  -- Reservas: la migracion 39 deja 12 + 6. Esta prueba se escribio con 12 + 4 (16 probadores).
  assert public.setting('lz_margen')::int = 6, 'reservas: 12 + 6';
  update public.settings set value = 4 where key = 'lz_margen';
  insert into auth.users (email, email_confirmed_at) values ('dueno@x.com', now()) returning id into dueno;
  update public.profiles set credits = 500 where id = dueno;
  select * into r from public.queue_game(dueno, 'un gato ninja que salta por tejados de noche');
  select * into r from public.claim_game_job('w1');
  p := public.complete_game_job(r.job_id, 0.1, 10, 'Bigotes Veloces', '{"titulo":"Bigotes"}'::jsonb, '{}'::jsonb);
  for i in 1..16 loop
    insert into auth.users (email, email_confirmed_at) values ('t' || i || '@x.com', now()) returning id into u;
    t := t || u;
  end loop;
  perform set_config('orq.hoy', '2026-11-01', false);

  -- 1 - Abrir: solo juegos propios que ya estan en Google Play y con un grupo de Google valido.
  perform set_config('request.jwt.claim.sub', dueno::text, false);
  begin perform public.lz_abrir(p, 'https://groups.google.com/g/bigotes-testers'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_on_play%', sqlerrm; end;
  update public.projects set play = '{"paquete": "com.danielstudio.bigotesveloces"}' where id = p;
  begin perform public.lz_abrir(p, 'https://evil.com/g/x'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_group_link%', sqlerrm; end;
  c := public.lz_abrir(p, 'https://groups.google.com/g/bigotes-testers', 'Plataformas con un gato ninja');
  begin perform public.lz_abrir(p, 'https://groups.google.com/g/bigotes-testers'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%campaign_exists%', sqlerrm; end;
  assert (select enlace_prueba from public.lz_campanas where id = c) = 'https://play.google.com/apps/testing/com.danielstudio.bigotesveloces';
  perform set_config('request.jwt.claim.sub', t[1]::text, false);
  begin perform public.lz_abrir(p, 'https://groups.google.com/g/bigotes-testers'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;

  -- 2 - Reciprocidad: no se ve hasta que el autor pruebe 3 juegos de otros.
  assert not exists (select 1 from public.lz_lista() where campana = c), 'oculta: el autor no prueba nada';
  for i in 1..3 loop
    perform set_config('request.jwt.claim.sub', t[i]::text, false);
    insert into public.projects (user_id, title, spec, files, play)
      values (t[i], 'Juego ' || i, '{}'::jsonb, '{}'::jsonb, jsonb_build_object('paquete', 'com.t' || i || '.juego')) returning id into otro;
    c2 := public.lz_abrir(otro, 'https://groups.google.com/g/juego' || i);
    perform set_config('request.jwt.claim.sub', dueno::text, false);
    perform public.lz_unirme(c2);
  end loop;
  perform set_config('request.jwt.claim.sub', t[5]::text, false);
  assert exists (select 1 from public.lz_lista() where campana = c), 'visible: el autor prueba 3';

  -- 3 - Unirse: no la propia, no dos veces; maximo 12 + 4.
  perform set_config('request.jwt.claim.sub', dueno::text, false);
  begin perform public.lz_unirme(c); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%own_campaign%', sqlerrm; end;
  for i in 1..16 loop
    perform set_config('request.jwt.claim.sub', t[i]::text, false);
    perform public.lz_unirme(c);
  end loop;
  perform set_config('request.jwt.claim.sub', t[1]::text, false);
  begin perform public.lz_unirme(c); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%already_joined%' or sqlerrm like '%campaign_full%', sqlerrm; end;
  insert into auth.users (email, email_confirmed_at) values ('tarde@x.com', now()) returning id into u;
  perform set_config('request.jwt.claim.sub', u::text, false);
  assert not exists (select 1 from public.lz_lista() where campana = c), 'llena: ya no sale';
  begin perform public.lz_unirme(c); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%campaign_full%', sqlerrm; end;

  -- 4 - 14 dias: los 12 primeros juegan cada dia; 13 y 14 dejan de jugar el dia 3; 15 y 16 solo un dia.
  for d in 0..13 loop
    perform set_config('orq.hoy', ('2026-11-01'::date + d)::text, false);
    for i in 1..16 loop
      continue when i in (13, 14) and d >= 2;
      continue when i in (15, 16) and d >= 1;
      perform set_config('request.jwt.claim.sub', t[i]::text, false);
      select * into r from public.lz_checkin(c, d + 1, case when d = 3 and i = 1 then 'El nivel 4 es muy dificil' else '' end);
    end loop;
    if d = 0 then
      perform set_config('request.jwt.claim.sub', t[1]::text, false);
      begin perform public.lz_checkin(c, 1, ''); raise exception 'debia fallar';
      exception when others then assert sqlerrm like '%already_today%', sqlerrm; end;
    end if;
    -- el autor tambien juega cada dia a los 3 juegos que prueba
    perform set_config('request.jwt.claim.sub', dueno::text, false);
    for c2 in select campana from public.lz_probadores where tester = dueno loop
      perform public.lz_checkin(c2, 1, '');
    end loop;
    perform set_config('request.jwt.claim.sub', '', false);
    j := public.lz_revisar();
  end loop;
  assert r.dias = 14 and r.completado, 'probador 12 completa: ' || r::text;

  -- 5 - Puntos: 14 dias + 5 por completar; quien abandona pierde 5.
  assert public.lz_saldo(t[2]) = 19, 'saldo t2 ' || public.lz_saldo(t[2]);
  assert (select estado from public.lz_probadores where campana = c and tester = t[13]) = 'abandonado';
  assert public.lz_saldo(t[15]) = 1 - 5, 'saldo t15 ' || public.lz_saldo(t[15]);
  perform set_config('request.jwt.claim.sub', t[13]::text, false);
  begin perform public.lz_checkin(c, 5, ''); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%abandoned%', sqlerrm; end;

  -- 6 - El autor: campana lista para pedir produccion, opiniones privadas sin identidad.
  assert (select estado from public.lz_campanas where id = c) = 'lista', 'campana lista';
  perform set_config('request.jwt.claim.sub', dueno::text, false);
  j := public.lz_mis_campanas();
  assert (j -> 'campanas' -> 0 ->> 'completados')::int = 12, j::text;
  assert (j -> 'campanas' -> 0 ->> 'abandonos')::int = 4, j::text;
  assert j -> 'campanas' -> 0 -> 'opiniones' -> 0 ->> 'opinion' = 'El nivel 4 es muy dificil', j::text;
  assert (j -> 'campanas' -> 0 -> 'opiniones' -> 0) ? 'probador' and not ((j -> 'campanas' -> 0 -> 'opiniones' -> 0) ? 'tester');
  assert position(t[1]::text in j::text) = 0, 'no expone ids de probadores';
  assert (j ->> 'visible_si_pruebas')::boolean, 'el autor prueba 3';
  -- Datos para responder a Google al pedir produccion (migracion 39).
  assert (j -> 'campanas' -> 0 ->> 'checkins')::int >= 12 * 14, j::text;
  assert (j -> 'campanas' -> 0 ->> 'nivel_medio') is not null and (j -> 'campanas' -> 0 ->> 'nivel_max')::int >= 1, j::text;
  assert (j -> 'campanas' -> 0 ->> 'creada') is not null, j::text;

  -- 7 - Premium: visible sin probar a nadie.
  perform set_config('request.jwt.claim.sub', t[16]::text, false);
  insert into public.projects (user_id, title, spec, files, play) values (t[16], 'Premium', '{}', '{}', '{"paquete":"com.p.premium"}') returning id into otro;
  c2 := public.lz_abrir(otro, 'https://groups.google.com/g/premium');
  perform set_config('request.jwt.claim.sub', u::text, false);
  assert not exists (select 1 from public.lz_lista() where campana = c2), 'sin premium y abandonando: oculta';
  update public.profiles set premium_hasta = now() + interval '30 days' where id = t[16];
  assert (select premium from public.lz_lista() limit 1), 'premium primero';

  -- 8 - Nadie toca las tablas a mano.
  assert not has_table_privilege('authenticated', 'public.lz_puntos', 'INSERT') or
    not exists (select 1 from pg_policies where tablename = 'lz_puntos'), 'sin politicas de escritura';
  update public.settings set value = 6 where key = 'lz_margen';
  raise notice 'LANZADERA OK';
end $$;
select 'LANZADERA OK';

\set ON_ERROR_STOP 1
do $$
declare
  a uuid; b uuid; p uuid; j uuid; r jsonb; n int; rec record; atq bigint; t0 int;
  s1 text := 'aaaaaaaaaaaaaaa1'; s2 text := 'bbbbbbbbbbbbbbb2'; s3 text := 'ccccccccccccccc3';
  m text[];
begin
  insert into auth.users (email, email_confirmed_at) values ('liga-a@x.com', now()) returning id into a;
  insert into auth.users (email, email_confirmed_at) values ('liga-b@x.com', now()) returning id into b;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Clanes', '{"titulo":"Clanes","genero":"aldea","niveles":["uno"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  m := array_fill('..............'::text, array[14]);
  m[7] := '......H.......';
  -- Mapas
  assert public.liga_mapa_valido(m);
  assert not public.liga_mapa_valido(array_fill('..............'::text, array[14]));
  assert not public.liga_mapa_valido(array_fill('.....'::text, array[14]));
  assert not public.liga_mapa_valido(m || array['......H.......']);
  -- Publicar: valida todo
  begin perform public.liga_publicar(j, s1, 'Dani', array['x'], 1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_map%', sqlerrm; end;
  begin perform public.liga_publicar(j, s1, 'mierdas', m, 1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_alias%', sqlerrm; end;
  begin perform public.liga_publicar(gen_random_uuid(), s1, 'Dani', m, 1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%unknown_game%', sqlerrm; end;
  r := public.liga_publicar(j, s1, 'Dani', m, 2);
  assert (r ->> 'trofeos')::int = 0, r::text;
  -- Sin rivales todavia
  begin perform public.liga_rival(j, s1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%no_rivals%', sqlerrm; end;
  begin perform public.liga_rival(j, s2); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_published%', sqlerrm; end;
  perform public.liga_publicar(j, s2, 'Lucia', m, 1);
  -- Asalto: rival, resultado una sola vez y trofeos
  r := public.liga_rival(j, s1);
  assert r ->> 'alias' = 'Lucia' and jsonb_array_length(r -> 'mapa') = 14, r::text;
  atq := (r ->> 'ataque')::bigint;
  begin perform public.liga_resultado(j, s1, atq, 3, 80); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_result%', sqlerrm; end;
  begin perform public.liga_resultado(j, s2, atq, 1, 60); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%unknown_attack%', sqlerrm; end;
  r := public.liga_resultado(j, s1, atq, 2, 70);
  assert (r ->> 'trofeos')::int = 22, r::text;
  begin perform public.liga_resultado(j, s1, atq, 3, 100); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%already_closed%', sqlerrm; end;
  assert (select trofeos from public.liga_aldeas where sesion = s2) = 0;
  -- Perder quita trofeos al atacante y da al defensor
  r := public.liga_rival(j, s2);
  r := public.liga_resultado(j, s2, (r ->> 'ataque')::bigint, 0, 20);
  assert (r ->> 'trofeos')::int = 0 and (select trofeos from public.liga_aldeas where sesion = s1) = 26;
  -- Defensas y ranking
  select count(*) into n from public.liga_defensas(j, s2);
  assert n = 1;
  select * into rec from public.liga_defensas(j, s2);
  assert rec.alias = 'Dani' and rec.estrellas = 2 and rec.trofeos = -8, rec::text;
  select * into rec from public.liga_top(j, s2, 1) where tuyo;
  assert rec.alias = 'Lucia' and rec.posicion = 2, rec::text;
  -- Caducado
  r := public.liga_rival(j, s1);
  update public.liga_ataques set created_at = now() - interval '20 minutes' where id = (r ->> 'ataque')::bigint;
  begin perform public.liga_resultado(j, s1, (r ->> 'ataque')::bigint, 1, 60); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%expired%', sqlerrm; end;
  -- Limite de asaltos por hora
  update public.settings set value = 3 where key = 'liga_ataques_hora';
  begin
    for n in 1..5 loop perform public.liga_rival(j, s1); end loop;
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%rate_limited%', sqlerrm; end;
  update public.settings set value = 30 where key = 'liga_ataques_hora';
  -- Autor: ve y oculta; nadie mas
  perform set_config('request.jwt.claim.sub', b::text, false);
  begin perform * from public.liga_autor(p); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  perform set_config('request.jwt.claim.sub', a::text, false);
  select count(*) into n from public.liga_autor(p);
  assert n = 2;
  perform public.liga_ocultar((select id from public.liga_aldeas where sesion = s2), true);
  begin perform public.liga_rival(j, s1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%no_rivals%', sqlerrm; end;
  -- Solo juegos de aldea
  insert into public.projects (user_id, title, spec, files) values (a, 'Otro', '{"genero":"plataformas"}'::jsonb, '{}'::jsonb) returning telemetria_id into j;
  begin perform public.liga_publicar(j, s3, 'Pepe', m, 1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%unknown_game%', sqlerrm; end;
  assert not has_table_privilege('anon', 'public.liga_aldeas', 'select') or not exists (select 1 from pg_policies where tablename = 'liga_aldeas');
  -- Borrar el juego borra su liga
  delete from public.projects where id = p;
  assert not exists (select 1 from public.liga_aldeas where alias = 'Dani');
  raise notice 'LIGA OK';
end;
$$;

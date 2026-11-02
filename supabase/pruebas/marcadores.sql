\set ON_ERROR_STOP 1
do $$
declare
  a uuid; b uuid; p uuid; j uuid; r jsonb; n int; rec record; oid bigint;
  s1 text := 'aaaaaaaaaaaaaaa1'; s2 text := 'bbbbbbbbbbbbbbb2'; s3 text := 'ccccccccccccccc3';
begin
  insert into auth.users (email, email_confirmed_at) values ('mar-a@x.com', now()) returning id into a;
  insert into auth.users (email, email_confirmed_at) values ('mar-b@x.com', now()) returning id into b;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Bigotes', '{"titulo":"Bigotes","niveles":["uno","dos","tres"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  -- Apodos
  assert public.alias_valido('Dani_99') and public.alias_valido('Zorro Rojo') and public.alias_valido('Peña');
  assert not public.alias_valido('ab') and not public.alias_valido('quinceletrasmass') and not public.alias_valido('p0ll4z')
    and not public.alias_valido('hola<script>') and not public.alias_valido('Admin');
  -- Enviar: valida todo
  begin perform public.marcador_enviar(j, 0, 'corta', 'Dani', 100); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_session%', sqlerrm; end;
  begin perform public.marcador_enviar(j, 0, s1, 'mierdas', 100); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_alias%', sqlerrm; end;
  begin perform public.marcador_enviar(j, 0, s1, 'Dani', 0); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_score%', sqlerrm; end;
  begin perform public.marcador_enviar(j, 3, s1, 'Dani', 10); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_level%', sqlerrm; end;
  begin perform public.marcador_enviar(gen_random_uuid(), 0, s1, 'Dani', 10); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%unknown_game%', sqlerrm; end;
  r := public.marcador_enviar(j, 0, s1, 'Dani', 300);
  assert (r ->> 'posicion')::int = 1 and (r ->> 'mejor')::int = 300, r::text;
  r := public.marcador_enviar(j, 0, s2, 'Lucia', 500);
  assert (r ->> 'posicion')::int = 1, r::text;
  -- Una peor no baja tu marca; una mejor la sube
  r := public.marcador_enviar(j, 0, s1, 'Dani', 100);
  assert (r ->> 'mejor')::int = 300 and (r ->> 'posicion')::int = 2, r::text;
  r := public.marcador_enviar(j, 0, s1, 'Dani', 800);
  assert (r ->> 'mejor')::int = 800 and (r ->> 'posicion')::int = 1, r::text;
  r := public.marcador_enviar(j, 0, s3, 'Pepe', 50);
  -- Top: limite y tu fila aunque no entres
  select count(*) into n from public.marcador_top(j, 0, null, 2);
  assert n = 2, n::text;
  select count(*) into n from public.marcador_top(j, 0, s3, 2);
  assert n = 3, n::text;
  select * into rec from public.marcador_top(j, 0, s3, 2) where tuyo;
  assert rec.alias = 'Pepe' and rec.posicion = 3, rec::text;
  select * into rec from public.marcador_top(j, 0, null, 1);
  assert rec.alias = 'Dani' and rec.puntos = 800;
  -- Autor: ve y oculta; nadie mas puede
  perform set_config('request.jwt.claim.sub', b::text, false);
  begin perform * from public.marcador_autor(p, 0); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  select id into oid from public.marcadores where juego = j and alias = 'Dani';
  begin perform public.marcador_ocultar(oid, true); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_found%', sqlerrm; end;
  perform set_config('request.jwt.claim.sub', a::text, false);
  select count(*) into n from public.marcador_autor(p, 0);
  assert n = 3;
  perform public.marcador_ocultar(oid, true);
  select * into rec from public.marcador_top(j, 0, null, 1);
  assert rec.alias = 'Lucia' and rec.posicion = 1, rec::text;
  -- Limite por dispositivo
  update public.settings set value = 8 where key = 'marcadores_por_sesion_hora';
  begin
    for n in 1..10 loop perform public.marcador_enviar(j, 1, s3, 'Pepe', 10 + n); end loop;
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%rate_limited%', sqlerrm; end;
  update public.settings set value = 60 where key = 'marcadores_por_sesion_hora';
  -- Nadie lee la tabla a mano
  assert not has_table_privilege('anon', 'public.marcadores', 'select') or
    not exists (select 1 from pg_policies where tablename = 'marcadores');
  -- Borrar el juego borra su clasificacion
  delete from public.projects where id = p;
  assert not exists (select 1 from public.marcadores where juego = j);
  raise notice 'MARCADORES OK';
end;
$$;

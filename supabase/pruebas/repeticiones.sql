\set ON_ERROR_STOP 1
do $$
declare
  a uuid; p uuid; j uuid; m text[]; t bigint; r jsonb; rec record;
  s1 text := 'aaaaaaaaaaaaaaa1'; s2 text := 'bbbbbbbbbbbbbbb2'; s3 text := 'ccccccccccccccc3';
  v1 bigint; v2 bigint;
begin
  insert into auth.users (email, email_confirmed_at) values ('rep-a@x.com', now()) returning id into a;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Rep', '{"titulo":"Rep","genero":"aldea","niveles":["uno"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  m := array_fill('..............'::text, array[14]);
  m[7] := '......H.......';
  perform public.liga_publicar(j, s1, 'Dani', m, 1);
  perform public.liga_publicar(j, s2, 'Lucia', m, 1);
  perform public.liga_publicar(j, s3, 'Pepe', m, 1);
  select id into v1 from public.liga_aldeas where juego = j and sesion = s1;
  select id into v2 from public.liga_aldeas where juego = j and sesion = s2;
  insert into public.liga_ataques (juego, atacante, defensor) values (j, v1, v2) returning id into t;
  -- Sin cerrar no se sube
  assert not public.liga_repeticion_subir(j, s1, t, '{"eventos": []}'::jsonb);
  perform public.liga_resultado(j, s1, t, 2, 70);
  begin perform public.liga_repeticion_subir(j, s1, t, '{"eventos": 3}'::jsonb); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_data%', sqlerrm; end;
  -- Solo el atacante, y una vez
  assert not public.liga_repeticion_subir(j, s2, t, '{"eventos": [[1,"guerrero",0,0,0,0]]}'::jsonb);
  assert public.liga_repeticion_subir(j, s1, t, '{"eventos": [[1,"guerrero",0,0,0,0]], "mapa": ["x"]}'::jsonb);
  assert not public.liga_repeticion_subir(j, s1, t, '{"eventos": []}'::jsonb);
  select * into rec from public.liga_defensas(j, s2) limit 1;
  assert rec.ataque = t and rec.repeticion and rec.alias = 'Dani', rec::text;
  r := public.liga_repeticion(j, s2, t);
  assert jsonb_array_length(r -> 'eventos') = 1 and r ->> 'alias' = 'Dani' and (r ->> 'estrellas')::int = 2, r::text;
  assert public.liga_repeticion(j, s1, t) is not null;
  assert public.liga_repeticion(j, s3, t) is null;
  delete from public.projects where id = p;
  raise notice 'REPETICIONES OK';
end;
$$;

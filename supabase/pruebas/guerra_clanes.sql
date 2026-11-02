\set ON_ERROR_STOP 1
do $$
declare
  a uuid; p uuid; j uuid; r jsonb; m text[]; c1 bigint; c2 bigint; t bigint;
  s1 text := 'aaaaaaaaaaaaaaa1'; s2 text := 'bbbbbbbbbbbbbbb2'; s3 text := 'ccccccccccccccc3'; s4 text := 'ddddddddddddddd4';
  v1 bigint; v2 bigint; v3 bigint; v4 bigint;
begin
  insert into auth.users (email, email_confirmed_at) values ('guerra-a@x.com', now()) returning id into a;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Guerra', '{"titulo":"Guerra","genero":"aldea","niveles":["uno"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  m := array_fill('..............'::text, array[14]);
  m[7] := '......H.......';
  perform public.liga_publicar(j, s1, 'Dani', m, 1);
  perform public.liga_publicar(j, s2, 'Lucia', m, 1);
  perform public.liga_publicar(j, s3, 'Pepe', m, 1);
  perform public.liga_publicar(j, s4, 'Ana', m, 1);
  select id into v1 from public.liga_aldeas where juego = j and sesion = s1;
  select id into v2 from public.liga_aldeas where juego = j and sesion = s2;
  select id into v3 from public.liga_aldeas where juego = j and sesion = s3;
  select id into v4 from public.liga_aldeas where juego = j and sesion = s4;
  perform public.clan_crear(j, s1, 'Lobos');
  perform public.clan_unir(j, s2, (select codigo from public.liga_clanes where juego = j and nombre = 'Lobos'));
  perform public.clan_crear(j, s3, 'Osos');
  select id into c1 from public.liga_clanes where juego = j and nombre = 'Lobos';
  select id into c2 from public.liga_clanes where juego = j and nombre = 'Osos';

  -- Esta semana: Dani 3 + Lucia 2 (Lobos 5), Pepe 1 (Osos 1), Ana sin clan 3 (no cuenta).
  insert into public.liga_ataques (juego, atacante, defensor) values (j, v1, v3) returning id into t;
  perform public.liga_resultado(j, s1, t, 3, 100);
  insert into public.liga_ataques (juego, atacante, defensor) values (j, v2, v3) returning id into t;
  perform public.liga_resultado(j, s2, t, 2, 70);
  insert into public.liga_ataques (juego, atacante, defensor) values (j, v3, v1) returning id into t;
  perform public.liga_resultado(j, s3, t, 1, 40);
  insert into public.liga_ataques (juego, atacante, defensor) values (j, v4, v1) returning id into t;
  perform public.liga_resultado(j, s4, t, 3, 100);
  assert (select clan from public.liga_ataques where id = t) is null;

  r := public.clan_guerra(j, s2);
  assert jsonb_array_length(r -> 'top') = 2, r::text;
  assert (r -> 'top' -> 0 ->> 'nombre') = 'Lobos' and (r -> 'top' -> 0 ->> 'estrellas')::int = 5 and (r -> 'top' -> 0 ->> 'tuyo')::boolean, r::text;
  assert (r -> 'clan' ->> 'puesto')::int = 1 and (r -> 'clan' ->> 'tus_estrellas')::int = 2, r::text;
  assert (r ->> 'segundos')::int > 0 and (r ->> 'premio')::int = 0;
  r := public.clan_guerra(j, s4);
  assert r -> 'clan' = 'null'::jsonb or r -> 'clan' is null, r::text;

  -- Cambiarse de clan no se lleva las estrellas ya ganadas.
  perform public.clan_unir(j, s2, (select codigo from public.liga_clanes where id = c2));
  r := public.clan_guerra(j, s2);
  assert (r -> 'clan' ->> 'nombre') = 'Osos' and (r -> 'clan' ->> 'tus_estrellas')::int = 0, r::text;
  assert (r -> 'top' -> 0 ->> 'estrellas')::int = 5, r::text;

  -- Semana pasada: se mueven los asaltos 7 dias atras. Premio a quien aporto: Dani y Lucia 250 (Lobos 1.o), Pepe 150.
  update public.liga_ataques set cerrado_at = cerrado_at - interval '7 days', created_at = created_at - interval '7 days' where juego = j;
  r := public.clan_guerra(j, s1);
  assert (r ->> 'premio')::int = 250 and (r ->> 'puesto_pasado')::int = 1, r::text;
  assert jsonb_array_length(r -> 'top') = 0, r::text;
  assert public.clan_guerra_cobrar(j, s1) = 250;
  assert public.clan_guerra_cobrar(j, s1) = 0;
  assert public.clan_guerra_cobrar(j, s2) = 250;
  assert public.clan_guerra_cobrar(j, s3) = 150;
  assert public.clan_guerra_cobrar(j, s4) = 0;
  begin perform public.clan_guerra(j, 'x'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_session%', sqlerrm; end;

  delete from public.projects where id = p;
  assert not exists (select 1 from public.guerra_cobros where juego = j);
  raise notice 'GUERRA OK';
end;
$$;

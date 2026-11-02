\set ON_ERROR_STOP 1
do $$
declare
  a uuid; p uuid; j uuid; r jsonb; n int; rec record; cod text; m text[];
  s1 text := 'aaaaaaaaaaaaaaa1'; s2 text := 'bbbbbbbbbbbbbbb2'; s3 text := 'ccccccccccccccc3';
begin
  insert into auth.users (email, email_confirmed_at) values ('clan-a@x.com', now()) returning id into a;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Clanes', '{"titulo":"Clanes","genero":"aldea","niveles":["uno"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  m := array_fill('..............'::text, array[14]);
  m[7] := '......H.......';
  begin perform public.clan_crear(j, s1, 'Lobos'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_published%', sqlerrm; end;
  perform public.liga_publicar(j, s1, 'Dani', m, 1);
  perform public.liga_publicar(j, s2, 'Lucia', m, 1);
  perform public.liga_publicar(j, s3, 'Pepe', m, 1);
  update public.liga_aldeas set trofeos = 100 where sesion = s1;
  update public.liga_aldeas set trofeos = 50 where sesion = s2;
  update public.liga_aldeas set trofeos = 300 where sesion = s3;
  begin perform public.clan_crear(j, s1, 'p0llas'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_name%', sqlerrm; end;
  r := public.clan_crear(j, s1, 'Lobos');
  cod := r ->> 'codigo';
  assert char_length(cod) = 6 and cod ~ '^[A-Z2-9]{6}$', cod;
  begin perform public.clan_crear(j, s1, 'Otros'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%already_in_clan%', sqlerrm; end;
  begin perform public.clan_crear(j, s3, 'lobos'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%name_taken%', sqlerrm; end;
  r := public.clan_unir(j, s2, lower(cod));
  assert r ->> 'nombre' = 'Lobos';
  r := public.clan_info(j, s2);
  assert (r ->> 'trofeos')::int = 150 and jsonb_array_length(r -> 'miembros') = 2 and (r ->> 'puesto')::int = 1, r::text;
  assert public.clan_info(j, s3) is null;
  perform public.clan_crear(j, s3, 'Osos');
  select * into rec from public.clan_top(j, 10) limit 1;
  assert rec.nombre = 'Osos' and rec.trofeos = 300, rec::text;
  begin perform public.clan_unir(j, s2, 'ZZZZZZ'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%unknown_clan%', sqlerrm; end;
  -- Lleno
  update public.settings set value = 2 where key = 'clan_max_miembros';
  begin perform public.clan_unir(j, s3, cod); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%clan_full%', sqlerrm; end;
  update public.settings set value = 20 where key = 'clan_max_miembros';
  -- Cambiar de clan deja vacio el anterior: desaparece
  perform public.clan_unir(j, s3, cod);
  assert not exists (select 1 from public.liga_clanes where nombre = 'Osos');
  perform public.clan_salir(j, s1);
  perform public.clan_salir(j, s2);
  perform public.clan_salir(j, s3);
  assert not exists (select 1 from public.liga_clanes where juego = j);
  delete from public.projects where id = p;
  raise notice 'CLANES OK';
end;
$$;

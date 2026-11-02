\set ON_ERROR_STOP 1
do $$
declare
  u uuid; otro uuid; p uuid; j uuid; r jsonb;
begin
  insert into auth.users (email, email_confirmed_at) values ('regalo-a@x.com', now()) returning id into u;
  insert into auth.users (email, email_confirmed_at) values ('regalo-b@x.com', now()) returning id into otro;
  insert into public.projects (user_id, title, spec, files, version) values (u, 'Para Lucia', '{"titulo":"Para Lucia"}'::jsonb, '{}'::jsonb, 3)
    returning id, telemetria_id into p, j;
  perform set_config('request.jwt.claim.sub', u::text, false);
  assert public.regalo_ficha(p) is null and public.regalo_juego(j) is null, 'sin regalo';
  begin perform public.regalo_guardar(p, 'Lucia', '', 'Feliz cumple'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_name%', sqlerrm; end;
  begin perform public.regalo_guardar(p, 'Lucia', 'Dani', '<script>'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_message%', sqlerrm; end;
  r := public.regalo_guardar(p, ' Lucia ', 'Dani', 'Feliz cumple, hermana. Te quiero mucho', 0);
  assert r ->> 'para' = 'Lucia' and r ->> 'abierto_en' is null, r::text;
  r := public.regalo_ficha(p);
  assert r ->> 'titulo' = 'Para Lucia' and r ->> 'de' = 'Dani' and not (r ? 'mensaje') and (r ->> 'version')::int = 3, r::text;
  r := public.regalo_juego(j);
  assert r ->> 'mensaje' like 'Feliz cumple%' and (r ->> 'tras_nivel')::int = 0, r::text;
  perform public.regalo_abierto(p);
  assert (public.regalo_autor(p) ->> 'abierto_en') is not null and (public.regalo_autor(p) ->> 'leido_en') is null;
  perform public.regalo_leido(j);
  assert (public.regalo_autor(p) ->> 'leido_en') is not null, 'el autor sabe que lo ha leido';
  perform set_config('request.jwt.claim.sub', otro::text, false);
  begin perform public.regalo_guardar(p, 'X', 'Y', 'Z'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  assert public.regalo_autor(p) is null, 'otro no lo ve';
  perform set_config('request.jwt.claim.sub', u::text, false);
  perform public.regalo_guardar(p, '', '', '');
  assert public.regalo_ficha(p) is null, 'quitar el regalo';
  raise notice 'JUEGO REGALO OK';
end $$;
select 'JUEGO REGALO OK';

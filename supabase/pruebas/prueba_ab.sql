\set ON_ERROR_STOP 1
do $$
declare
  a uuid; b uuid; p uuid; j uuid; r jsonb; n integer;
begin
  insert into auth.users (email, email_confirmed_at) values ('ab-a@x.com', now()) returning id into a;
  insert into auth.users (email, email_confirmed_at) values ('ab-b@x.com', now()) returning id into b;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'AB', '{"titulo":"AB","genero":"plataformas","niveles":["uno","dos","tres"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  -- El juego manda el grupo solo en el nivel probado; un grupo raro se ignora.
  n := public.registrar_partida(j, 3, 'aaaaaaaa00000001', '[{"n":1,"r":"gana","s":20,"m":0,"e":3,"g":"b"},
    {"n":1,"r":"sale","s":20,"m":2,"g":"a"},{"n":0,"r":"gana","s":10,"m":0,"e":3},{"n":1,"r":"gana","s":9,"m":0,"g":"x"}]'::jsonb);
  assert n = 3, n::text;
  perform public.registrar_partida(j, 3, 'aaaaaaaa00000002', '[{"n":1,"r":"gana","s":20,"m":1,"g":"b"},{"n":1,"r":"muere","s":5,"m":1,"g":"a"},
    {"n":1,"r":"gana","s":25,"m":1,"g":"a"}]'::jsonb);
  perform public.registrar_partida(j, 2, 'aaaaaaaa00000003', '[{"n":1,"r":"gana","s":20,"m":0,"g":"b"}]'::jsonb);
  perform set_config('request.jwt.claim.sub', a::text, false);
  assert public.prueba_ab_informe(p) is null, 'sin prueba en marcha';
  update public.projects set spec = spec || '{"prueba_ab":{"nivel":1,"hacia":"mas_facil","id":"n1m3"}}'::jsonb where id = p;
  r := public.prueba_ab_informe(p);
  assert (r ->> 'nivel')::int = 1 and (r ->> 'version')::int = 3 and r ->> 'hacia' = 'mas_facil', r::text;
  assert (r -> 'grupos' -> 'b' ->> 'intentos')::int = 2 and (r -> 'grupos' -> 'b' ->> 'ganados')::int = 2 and (r -> 'grupos' -> 'b' ->> 'superan')::int = 2, r::text;
  assert (r -> 'grupos' -> 'a' ->> 'intentos')::int = 3 and (r -> 'grupos' -> 'a' ->> 'salidas')::int = 1 and (r -> 'grupos' -> 'a' ->> 'superan')::int = 1, r::text;
  assert (r -> 'grupos' -> 'a' ->> 'jugadores')::int = 2, r::text;
  perform set_config('request.jwt.claim.sub', b::text, false);
  begin perform public.prueba_ab_informe(p); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  delete from public.partidas where juego = j;
  delete from public.projects where id = p;
  raise notice 'PRUEBA AB OK';
end;
$$;

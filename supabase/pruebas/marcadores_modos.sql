\set ON_ERROR_STOP 1
do $$
declare
  a uuid; p uuid; j uuid; r jsonb; n int;
  s1 text := 'ddddddddddddddd1'; s2 text := 'eeeeeeeeeeeeeee2';
begin
  insert into auth.users (email, email_confirmed_at) values ('modos-a@x.com', now()) returning id into a;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Crono', '{"titulo":"Crono","niveles":["uno","dos","tres"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  -- Contrarreloj: 1000 + nivel, solo niveles que existen
  r := public.marcador_enviar(j, 1002, s1, 'Dani', 3600000 - 41300);
  assert (r ->> 'posicion')::int = 1, r::text;
  r := public.marcador_enviar(j, 1002, s2, 'Lucia', 3600000 - 39000);
  assert (r ->> 'posicion')::int = 1, r::text;
  select puntos into n from public.marcador_top(j, 1002, s1, 10) where tuyo;
  assert n = 3600000 - 41300, n::text;
  begin perform public.marcador_enviar(j, 1003, s1, 'Dani', 10); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_level%', sqlerrm; end;
  begin perform public.marcador_enviar(j, 500, s1, 'Dani', 10); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_level%', sqlerrm; end;
  -- Maraton: nivel 2000, como mucho tantos niveles como tiene el juego
  r := public.marcador_enviar(j, 2000, s1, 'Dani', 3);
  assert (r ->> 'mejor')::int = 3, r::text;
  begin perform public.marcador_enviar(j, 2000, s2, 'Lucia', 4); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_score%', sqlerrm; end;
  begin perform public.marcador_enviar(j, 2001, s1, 'Dani', 1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_level%', sqlerrm; end;
  -- Las clasificaciones no se mezclan
  assert (select count(*) from public.marcador_top(j, 2, null, 10)) = 0;
  assert (select count(*) from public.marcador_top(j, 2000, null, 10)) = 1;
  raise notice 'marcadores_modos OK';
end;
$$;

\set ON_ERROR_STOP 1
do $$
declare
  a uuid; p uuid; j uuid; r jsonb;
  s1 text := 'aaaaaaaaaaaaaaa1'; s2 text := 'bbbbbbbbbbbbbbb2'; s3 text := 'ccccccccccccccc3';
  g jsonb := '[[10,20],[15,20],[20,18]]'::jsonb;
begin
  insert into auth.users (email, email_confirmed_at) values ('fan-a@x.com', now()) returning id into a;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Bigotes', '{"titulo":"Bigotes","niveles":["uno","dos"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  perform public.marcador_enviar(j, 0, s1, 'Dani', 300);
  perform public.marcador_enviar(j, 0, s2, 'Lucia', 500);
  perform public.marcador_enviar(j, 0, s3, 'Pepe', 900);
  -- Solo se guarda con la marca que tienes de verdad
  assert not public.fantasma_subir(j, 0, s2, 450, g);
  assert public.fantasma_subir(j, 0, s2, 500, g);
  assert public.fantasma_subir(j, 0, s3, 900, '[[1,1],[2,2]]'::jsonb);
  begin perform public.fantasma_subir(j, 0, s1, 300, '[[1,"x"],[2,2]]'::jsonb); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_ghost%', sqlerrm; end;
  begin perform public.fantasma_subir(j, 0, s1, 300, '{"a":1}'::jsonb); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_ghost%', sqlerrm; end;
  -- Bajar: el que va justo por delante
  r := public.fantasma_bajar(j, 0, s1);
  assert r ->> 'alias' = 'Lucia' and jsonb_array_length(r -> 'datos') = 3, r::text;
  r := public.fantasma_bajar(j, 0, s2);
  assert r ->> 'alias' = 'Pepe', r::text;
  -- Si vas primero: el mejor de los demas
  r := public.fantasma_bajar(j, 0, s3);
  assert r ->> 'alias' = 'Lucia', r::text;
  assert public.fantasma_bajar(j, 1, s1) is null;
  delete from public.projects where id = p;
  raise notice 'FANTASMAS OK';
end;
$$;

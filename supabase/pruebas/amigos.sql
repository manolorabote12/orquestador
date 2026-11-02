\set ON_ERROR_STOP 1
do $$
declare
  a uuid; p uuid; j uuid; r jsonb; n int; rec record; c1 text; c2 text;
  s1 text := 'aaaaaaaaaaaaaaa1'; s2 text := 'bbbbbbbbbbbbbbb2'; s3 text := 'ccccccccccccccc3';
begin
  insert into auth.users (email, email_confirmed_at) values ('ami-a@x.com', now()) returning id into a;
  insert into public.projects (user_id, title, spec, files)
    values (a, 'Bigotes', '{"titulo":"Bigotes","niveles":["uno","dos"]}'::jsonb, '{}'::jsonb) returning id, telemetria_id into p, j;
  c1 := public.amigo_codigo(j, s1);
  assert char_length(c1) = 6 and public.amigo_codigo(j, s1) = c1, 'el codigo no cambia';
  c2 := public.amigo_codigo(j, s2);
  assert c1 <> c2;
  perform public.marcador_enviar(j, 0, s1, 'Dani', 300);
  perform public.marcador_enviar(j, 0, s2, 'Lucia', 500);
  perform public.marcador_enviar(j, 0, s3, 'Pepe', 900);
  begin perform public.amigo_anadir(j, s1, c1); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%own_code%', sqlerrm; end;
  begin perform public.amigo_anadir(j, s1, 'ZZZZZZ'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%unknown_code%', sqlerrm; end;
  r := public.amigo_anadir(j, s1, lower(c2));
  assert r ->> 'alias' = 'Lucia', r::text;
  select count(*) into n from public.amigos_top(j, s1, 0);
  assert n = 2, 'solo tu y tus amigos (Pepe no)';
  select * into rec from public.amigos_top(j, s1, 0) where tuyo;
  assert rec.posicion = 2 and rec.alias = 'Dani', rec::text;
  perform public.amigo_quitar(j, s1, c2);
  select count(*) into n from public.amigos_top(j, s1, 0);
  assert n = 1;
  delete from public.projects where id = p;
  assert not exists (select 1 from public.amigos_codigos where juego = j);
  raise notice 'AMIGOS OK';
end;
$$;

\set ON_ERROR_STOP 1
do $$
declare
  a uuid; b uuid; c uuid; d uuid; p uuid; sin_web uuid; n uuid; r record; m int;
begin
  insert into auth.users (email, email_confirmed_at) values ('esc-a@x.com', now()) returning id into a;
  insert into auth.users (email, email_confirmed_at) values ('esc-b@x.com', now()) returning id into b;
  insert into auth.users (email, email_confirmed_at) values ('esc-c@x.com', now()) returning id into c;
  insert into auth.users (email, email_confirmed_at) values ('esc-d@x.com', now()) returning id into d;
  insert into public.projects (user_id, title, spec, files, version)
    values (a, 'Bigotes', '{"titulo":"Bigotes","genero":"plataformas","resumen":"Un gato ninja"}'::jsonb,
      '{"web":"a/p/v2/web/index.pck","proyecto":"a/p/v2/x.zip"}'::jsonb, 2) returning id into p;
  insert into public.projects (user_id, title, spec, files) values (a, 'Sin web', '{}'::jsonb, '{}'::jsonb) returning id into sin_web;
  -- Publicar: solo lo propio y con version web
  begin perform public.escaparate_publicar(b, p, 'B'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%project_not_found%', sqlerrm; end;
  begin perform public.escaparate_publicar(a, sin_web, 'A'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%no_web_build%', sqlerrm; end;
  perform public.escaparate_publicar(a, p, 'Daniel Studio');
  select * into r from public.escaparate_lista('nuevos') where project_id = p;
  assert r.titulo = 'Bigotes' and r.genero = 'plataformas' and r.autor = 'Daniel Studio' and r.version = 2, r::text;
  perform public.escaparate_jugada(p);
  perform public.escaparate_jugada(p);
  -- Me gusta: uno por persona, y volver a pulsar lo quita
  perform set_config('request.jwt.claim.sub', b::text, false);
  m := public.escaparate_megusta(p);
  assert m = 1;
  m := public.escaparate_megusta(p);
  assert m = 0;
  m := public.escaparate_megusta(p);
  select * into r from public.escaparate_ficha(p);
  assert r.jugadas = 2 and r.megusta = 1, r::text;
  -- Remix: proyecto nuevo de B, el original lo cuenta; el propio no
  begin perform public.escaparate_remix(a, p, '{}'::jsonb); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%own_game%', sqlerrm; end;
  n := public.escaparate_remix(b, p, '{"web":"b/n/v1/web/index.pck"}'::jsonb);
  assert (select remix_de from public.projects where id = n) = p;
  assert (select user_id from public.projects where id = n) = b;
  assert (select prompt from public.project_versions where project_id = n and version = 2) like 'Remix de%';
  assert (select version from public.projects where id = n) = 2, 'misma version que el zip';
  assert (select remixes from public.escaparate_ficha(p)) = 1;
  -- Denuncias: 3 personas distintas lo ocultan
  for r in select x from unnest(array[b, c, d]) x loop
    perform set_config('request.jwt.claim.sub', r.x::text, false);
    perform public.denunciar(p, null, 'Contenido ofensivo');
    perform public.denunciar(p, null, 'otra vez');
  end loop;
  assert (select count(*) from public.content_reports where project_id = p and tipo = 'escaparate') = 3;
  assert not exists (select 1 from public.escaparate_lista('top') where project_id = p), 'oculto tras 3 denuncias';
  assert not exists (select 1 from public.escaparate_ficha(p));
  begin perform public.escaparate_remix(c, p, '{}'::jsonb); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_found%', sqlerrm; end;
  -- Retirar
  perform public.escaparate_retirar(a, p);
  assert not exists (select 1 from public.escaparate where project_id = p);
  raise notice 'ESCAPARATE OK';
end $$;
select 'ESCAPARATE OK';

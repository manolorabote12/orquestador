\set ON_ERROR_STOP 1
do $$
declare
  dueno uuid; p uuid; c uuid; t uuid[] := '{}'; u uuid; i int; ajeno uuid;
begin
  insert into auth.users (email, email_confirmed_at) values ('den-dueno@x.com', now()) returning id into dueno;
  update public.profiles set premium_hasta = now() + interval '10 days' where id = dueno;
  insert into public.projects (user_id, title, spec, files, play)
    values (dueno, 'Juego Feo', '{}'::jsonb, '{}'::jsonb, '{"paquete":"com.feo.juego"}'::jsonb) returning id into p;
  perform set_config('request.jwt.claim.sub', dueno::text, false);
  c := public.lz_abrir(p, 'https://groups.google.com/g/feo', 'nota ofensiva');
  for i in 1..4 loop
    insert into auth.users (email, email_confirmed_at) values ('den' || i || '@x.com', now()) returning id into u;
    t := t || u;
  end loop;
  perform set_config('request.jwt.claim.sub', t[1]::text, false);
  assert exists (select 1 from public.lz_lista() where campana = c), 'visible al principio';
  begin perform public.denunciar(null, c, 'x'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%bad_reason%', sqlerrm; end;
  perform public.denunciar(null, c, 'La nota insulta a la gente');
  perform public.denunciar(null, c, 'otra vez');  -- repetida: no cuenta dos veces
  assert (select count(*) from public.content_reports where campana = c) = 1;
  assert not exists (select 1 from public.lz_lista() where campana = c), 'quien denuncia deja de verla';
  perform set_config('request.jwt.claim.sub', t[4]::text, false);
  assert exists (select 1 from public.lz_lista() where campana = c), 'los demas aun la ven';
  for i in 2..3 loop
    perform set_config('request.jwt.claim.sub', t[i]::text, false);
    perform public.denunciar(null, c, 'Contenido ofensivo');
  end loop;
  assert (select oculta from public.lz_campanas where id = c), '3 denuncias: oculta';
  perform set_config('request.jwt.claim.sub', t[4]::text, false);
  assert not exists (select 1 from public.lz_lista() where campana = c), 'oculta para todos';
  -- Juego propio: lo que genero la IA. Un juego ajeno no se puede denunciar por id.
  perform set_config('request.jwt.claim.sub', dueno::text, false);
  perform public.denunciar(p, null, 'La IA dibujo algo inapropiado');
  assert exists (select 1 from public.content_reports where project_id = p and tipo = 'juego');
  perform set_config('request.jwt.claim.sub', t[4]::text, false);
  begin perform public.denunciar(p, null, 'no es mio'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%not_found%', sqlerrm; end;
  raise notice 'DENUNCIAS OK';
end $$;
select 'DENUNCIAS OK';

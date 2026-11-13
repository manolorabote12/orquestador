\set ON_ERROR_STOP 1
-- Economia v2: precios con margen, un regalo por correo real y progreso que avisa.
do $$
declare
  a uuid; b uuid; c uuid; d uuid; j uuid; sigue boolean;
begin
  -- Precios vigentes desde economia v3 (13 nov): juego 120, bienvenida 120, anuncio 2.
  assert (select credits from public.pricing where kind = 'game') = 120;
  assert public.setting('welcome_credits') = 120 and public.setting('reward_ad_credits') = 2;
  assert public.correo_normal('P.e.Pe+juegos@GMail.com') = 'pepe@gmail.com';
  assert public.correo_normal('pepe+x@outlook.com') = 'pepe@outlook.com';
  assert public.correo_normal('pe.pe@outlook.com') = 'pe.pe@outlook.com';
  insert into auth.users (email, email_confirmed_at) values ('ana.lopez@gmail.com', now()) returning id into a;
  insert into auth.users (email, email_confirmed_at) values ('analopez+2@gmail.com', now()) returning id into b;
  insert into auth.users (email, email_confirmed_at) values ('ana.lopez@googlemail.com', now()) returning id into c;
  insert into auth.users (email, email_confirmed_at) values ('otra.ana@gmail.com', now()) returning id into d;
  assert (select credits from public.profiles where id = a) = 120, 'la primera cuenta cobra';
  assert (select credits from public.profiles where id = b) = 0, 'el mismo gmail con +etiqueta no cobra';
  assert (select credits from public.profiles where id = c) = 0, 'googlemail con puntos tampoco';
  assert (select credits from public.profiles where id = d) = 120, 'otra persona si';
  assert not exists (select 1 from public.credit_ledger where user_id in (b, c) and reason = 'signup');
  -- Invitarse a uno mismo con otra cuenta del mismo correo no vale.
  perform set_config('request.jwt.claim.sub', a::text, false);
  perform set_config('request.jwt.claim.sub', b::text, false);
  begin
    perform public.usar_invitacion((select codigo_invitacion from public.profiles where id = a));
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%own_code%' or sqlerrm like '%bad_code%', sqlerrm; end;
  -- job_progress: true mientras corre; false si ya no.
  insert into public.jobs (user_id, kind, cost, status, started_at) values (d, 'game', 80, 'running', now()) returning id into j;
  sigue := public.job_progress(j, '{"paso":"arte"}'::jsonb);
  assert sigue, 'en marcha';
  update public.jobs set status = 'failed' where id = j;
  sigue := public.job_progress(j, '{"paso":"arte"}'::jsonb);
  assert not sigue, 'caducado';
  assert not has_function_privilege('anon', 'public.job_progress(uuid, jsonb)', 'execute');
  assert not has_function_privilege('authenticated', 'public.job_progress(uuid, jsonb)', 'execute');
  raise notice 'economia_v2 OK';
end;
$$;

\set ON_ERROR_STOP 1
-- Canario semanal: encarga sin cobrar, informa y limpia.
do $$
declare
  c uuid; j uuid; e jsonb; rutas text[];
begin
  begin
    perform public.canario_encargar('un canario de prueba que salta por las nubes');
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%sin_canario%', sqlerrm; end;
  insert into auth.users (email, email_confirmed_at) values ('canario@orquestador.invalid', now()) returning id into c;
  j := public.canario_encargar('un canario de prueba que salta por las nubes');
  assert (select cost from public.jobs where id = j) = 0 and (select status from public.jobs where id = j) = 'queued';
  assert (select (detail ->> 'canario')::boolean from public.jobs where id = j);
  update public.jobs set status = 'done', started_at = now() - interval '20 minutes', finished_at = now(), provider_cost_usd = 0.11,
    progress = '[{"paso":"arte","estado":"ok","mensaje":"Arte listo"},{"paso":"niveles","estado":"ok","mensaje":"x"}]'::jsonb where id = j;
  e := public.canario_estado();
  assert e ->> 'status' = 'done' and (e ->> 'segundos')::int >= 1190 and jsonb_array_length(e -> 'pasos') = 1, e::text;
  insert into public.projects (user_id, title, spec) values (c, 'Canario', '{}'::jsonb);
  insert into storage.objects (bucket_id, name) values ('juegos', c::text || '/x/v1/juego.apk'), ('juegos', 'otro/y.apk');
  rutas := public.canario_limpiar();
  assert rutas = array[c::text || '/x/v1/juego.apk'], rutas::text;
  assert not exists (select 1 from public.projects where user_id = c);
  -- Con la fabrica parada, ni el canario.
  perform public.pausar_fabrica(true, 'prueba');
  begin
    perform public.canario_encargar('otro canario con la fabrica parada');
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%budget_exceeded%', sqlerrm; end;
  perform public.pausar_fabrica(false);
  assert not has_function_privilege('authenticated', 'public.canario_encargar(text)', 'execute');
  raise notice 'canario OK';
end;
$$;
-- Regalar un juego completo a una cuenta.
do $$
declare
  u uuid; j uuid;
begin
  insert into auth.users (email, email_confirmed_at) values ('Dueno.Real@gmail.com', now()) returning id into u;
  j := public.regalar_juego('duenoreal@gmail.com', 'un duelo de cartas entre orcos y humanos con torres');
  assert (select user_id from public.jobs where id = j) = u and (select cost from public.jobs where id = j) = 0;
  assert (select status from public.jobs where id = j) = 'queued';
  delete from public.jobs where id = j;  -- que no lo coja la fabrica de otras pruebas
  begin
    perform public.regalar_juego('nadie@example.com', 'un duelo de cartas entre orcos y humanos con torres');
    raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%sin_cuenta%', sqlerrm; end;
  assert not has_function_privilege('authenticated', 'public.regalar_juego(text, text)', 'execute');
  raise notice 'regalar OK';
end;
$$;

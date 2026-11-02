\set ON_ERROR_STOP 1
do $$
declare
  a uuid; r jsonb; i int;
begin
  insert into auth.users (email, email_confirmed_at) values ('gir-a@x.com', now()) returning id into a;
  perform public.giro_anotar('golf', 'espejo', true);
  perform public.giro_anotar('golf', 'espejo', false, 'los bots no lo superan');
  perform public.giro_anotar('laberinto', 'cola', true);
  r := public.giros_estadisticas();
  assert jsonb_array_length(r -> 'stats') >= 2, r::text;
  assert exists (select 1 from jsonb_array_elements(r -> 'stats') e where e ->> 'genero' = 'golf' and e ->> 'giro' = 'espejo'
    and (e ->> 'usos')::int >= 2 and (e ->> 'ok')::int >= 1), r::text;
  assert (r -> 'lecciones' -> 0 ->> 'problema') = 'los bots no lo superan', r::text;
  update public.settings set value = 2 where key = 'ganchos_dia';
  perform public.gancho_reservar(a);
  perform public.gancho_coste(public.gancho_reservar(a), 0.003);
  begin perform public.gancho_reservar(a); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%rate_limited%', sqlerrm; end;
  update public.settings set value = 20 where key = 'ganchos_dia';
  assert not has_function_privilege('authenticated', 'public.giro_anotar(text, text, boolean, text)', 'execute');
  assert not has_function_privilege('anon', 'public.giros_estadisticas()', 'execute');
  delete from public.giros_uso where genero in ('golf', 'laberinto');
  raise notice 'GIROS OK';
end;
$$;

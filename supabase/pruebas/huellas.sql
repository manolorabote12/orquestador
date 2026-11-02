\set ON_ERROR_STOP 1
do $$
declare
  r jsonb;
begin
  perform public.huella_anotar('caida', '{"giros": [], "reglas": [], "palabras": ["neon", "bloques"], "familia": "cartoon"}'::jsonb);
  perform public.huella_anotar('caida', '"no es un objeto"'::jsonb);
  r := public.huellas_recientes();
  assert jsonb_array_length(r) = 1, r::text;
  assert r -> 0 ->> 'genero' = 'caida' and r -> 0 -> 'palabras' ? 'neon', r::text;
  begin perform public.huella_anotar('caida', jsonb_build_object('palabras', repeat('x', 5000))); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%check%' or sqlerrm like '%huellas_firma%', sqlerrm; end;
  assert not has_function_privilege('authenticated', 'public.huella_anotar(text, jsonb)', 'execute');
  assert not has_function_privilege('anon', 'public.huellas_recientes()', 'execute');
  delete from public.huellas;
  raise notice 'HUELLAS OK';
end;
$$;

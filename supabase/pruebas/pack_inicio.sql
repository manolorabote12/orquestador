\set ON_ERROR_STOP 1
do $$
begin
  assert public.iap_precio('pack_inicio') = 3.99;
  assert public.iap_precio('sin_anuncios') = 2.99;
  raise notice 'pack_inicio OK';
end;
$$;

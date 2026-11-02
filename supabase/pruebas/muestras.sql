\set ON_ERROR_STOP 1
do $$
declare
  b record;
begin
  select * into b from storage.buckets where id = 'motor';
  assert b.public, 'el bucket motor debe ser publico';
  assert 'application/json' = any(b.allowed_mime_types), 'el indice de muestras es JSON';
  assert 'application/octet-stream' = any(b.allowed_mime_types), 'los .pck de muestra';
  assert 'application/wasm' = any(b.allowed_mime_types), 'el motor sigue';
  raise notice 'MUESTRAS OK';
end;
$$;

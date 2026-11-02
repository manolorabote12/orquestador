-- Motor web de Godot para jugar dentro de la app sin instalar nada.
-- El motor (index.js + index.wasm, ~38 MB) es igual para todos los juegos: se sube una vez
-- por version de Godot con fabrica/subir_motor.py y se sirve publico (y cacheable).
-- Cada version de cada juego solo guarda su paquete (files->>'web' = .../web/index.pck, ~1 MB)
-- en el bucket privado 'juegos'; la app lo abre con una URL firmada.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('motor', 'motor', true, 62914560,
  array['application/wasm', 'text/javascript', 'application/javascript', 'application/octet-stream'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Lectura publica; escribir solo con la clave de servicio (que salta RLS). Sin politicas de escritura.
drop policy if exists "motor publico" on storage.objects;
create policy "motor publico" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'motor');

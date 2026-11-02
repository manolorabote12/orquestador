-- Partidas de muestra («Probar» en el catálogo del taller): un index.pck por género en
-- motor/muestras/<genero>.pck y su índice motor/muestras/indice.json (fabrica/muestras.py).
-- El bucket público 'motor' ya existe (20261008000005_motor_web.sql); solo hace falta que admita
-- el índice en JSON. Lectura pública y escritura solo con la clave de servicio, como el motor.
update storage.buckets
set allowed_mime_types = array['application/wasm', 'text/javascript', 'application/javascript', 'application/octet-stream', 'application/json']
where id = 'motor';

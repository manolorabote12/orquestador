-- Escaparate: paquetes de hasta 50 MB (antes 20). Los juegos con arte y musica de verdad pasan de 20 MB y no
-- se podian compartir (413 Payload too large). 50 MB es el tope por archivo del plan gratis de Supabase.
update storage.buckets set file_size_limit = 52428800 where id = 'escaparate';

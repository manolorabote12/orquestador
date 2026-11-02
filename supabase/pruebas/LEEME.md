# Pruebas de la base de datos sin Supabase

Aplica todas las migraciones en un PostgreSQL 16 local (con `stubs.sql` imitando `auth` y
`storage`) y recorre los flujos de dinero y de trabajos: juego, vídeos para redes y publicación.

```bash
initdb -D /tmp/orqdb -U postgres && pg_ctl -D /tmp/orqdb -o "-p 54329" start
psql -p 54329 -U postgres -c "create database orq"
psql -p 54329 -U postgres -d orq -v ON_ERROR_STOP=1 -f stubs.sql
for f in ../migrations/*.sql; do psql -p 54329 -U postgres -d orq -v ON_ERROR_STOP=1 -f $f; done
psql -p 54329 -U postgres -d orq -f flujo.sql      # termina con: FLUJO OK
```

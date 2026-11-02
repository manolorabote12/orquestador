#!/bin/bash
set -e
D=/var/tmp/orqpg/data
S=/var/tmp/orqpg
B=/usr/lib/postgresql/16/bin
if [ ! -d $D ]; then su postgres -c "$B/initdb -D $D -U postgres" >/dev/null; fi
su postgres -c "$B/pg_ctl -D $D -o '-p 54329 -k $S' -l $S/log status" >/dev/null 2>&1 || su postgres -c "$B/pg_ctl -D $D -o '-p 54329 -k $S' -l $S/log start" >/dev/null
sleep 1
P="psql -h $S -p 54329 -U postgres -q"
$P -c "drop database if exists orq" -c "create database orq"
$P -d orq -v ON_ERROR_STOP=1 -f /home/claude/supabase/pruebas/stubs.sql 2>&1 | grep -v WARNING | grep -v HINT || true
for f in /home/claude/supabase/migrations/*.sql; do
  $P -d orq -v ON_ERROR_STOP=1 -f $f 2>&1 | grep -iE "error" || true
done
for f in /home/claude/supabase/pruebas/*.sql; do
  case $f in *stubs.sql) continue;; esac
  echo "== $(basename $f): $($P -d orq -f $f 2>&1 | grep -E 'OK$|ERROR|error' | tail -1)"
done
# Verificacion de compras (TypeScript del servidor) con Node.
E=/home/claude/app/node_modules/.bin/esbuild
$E /home/claude/supabase/functions/_shared/google.ts --format=esm --outfile=/home/claude/supabase/pruebas/.google.mjs --log-level=error
$E /home/claude/supabase/functions/_shared/compras.ts --format=esm --outfile=/home/claude/supabase/pruebas/.compras.mjs --log-level=error
echo "== compras.mjs: $(node /home/claude/supabase/pruebas/compras.mjs | tail -1)"
$E /home/claude/supabase/functions/_shared/youtube.ts --format=esm --outfile=/home/claude/supabase/pruebas/.youtube.mjs --log-level=error
echo "== youtube.mjs: $(node /home/claude/supabase/pruebas/youtube.mjs | tail -1)"
$E /home/claude/supabase/functions/_shared/escaparate.ts --format=esm --outfile=/home/claude/supabase/pruebas/.escaparate.mjs --log-level=error
$E /home/claude/supabase/functions/_shared/itch.ts --format=esm --outfile=/home/claude/supabase/pruebas/.itch.mjs --log-level=error
echo "== itch.mjs: $(node /home/claude/supabase/pruebas/itch.mjs | tail -1)"
echo "== escaparate.mjs: $(node /home/claude/supabase/pruebas/escaparate.mjs | tail -1)"
$E /home/claude/supabase/functions/_shared/plan-logica.ts --bundle --format=esm --outfile=/home/claude/supabase/pruebas/.plan.mjs --log-level=error
echo "== plan.mjs: $(node /home/claude/supabase/pruebas/plan.mjs | tail -1)"
$E /home/claude/supabase/functions/_shared/charla.ts --format=esm --outfile=/home/claude/supabase/pruebas/.charla.mjs --log-level=error
echo "== charla.mjs: $(node /home/claude/supabase/pruebas/charla.mjs | tail -1)"
$E /home/claude/supabase/functions/_shared/resenas.ts --format=esm --outfile=/home/claude/supabase/pruebas/.resenas.mjs --log-level=error
echo "== resenas.mjs: $(node /home/claude/supabase/pruebas/resenas.mjs | tail -1)"
$E /home/claude/supabase/functions/_shared/referencias.ts --format=esm --outfile=/home/claude/supabase/pruebas/.referencias.mjs --log-level=error
echo "== referencias.mjs: $(node /home/claude/supabase/pruebas/referencias.mjs | tail -1)"
$E /home/claude/supabase/functions/_shared/ganchos.ts --bundle --format=esm --outfile=/home/claude/supabase/pruebas/.ganchos.mjs --log-level=error
echo "== ganchos.mjs: $(node /home/claude/supabase/pruebas/ganchos.mjs | tail -1)"

-- Blindaje: las funciones de los disparadores (triggers) no se pueden llamar a mano desde la API,
-- pero tampoco tienen por que poder ejecutarlas anonimos ni usuarios. Se les quita el permiso a
-- todas (las de ahora y, al repetir la migracion, las nuevas). Los disparadores siguen funcionando:
-- los lanza la base de datos, no el usuario.
do $$
declare
  r record;
begin
  for r in select p.oid::regprocedure as f from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prorettype = 'trigger'::regtype loop
    execute format('revoke all on function %s from public, anon, authenticated', r.f);
  end loop;
end $$;

\set ON_ERROR_STOP 1
-- Red de seguridad: ninguna funcion que actua "en nombre de" un usuario (parametro p_user) ni
-- ninguna que concede saldo puede llamarse con la clave publica o con una sesion normal.
do $$
declare
  r record;
  malas text := '';
begin
  for r in
    select p.oid, p.proname, pg_get_function_identity_arguments(p.oid) as args
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prosecdef
       and (coalesce(p.proargnames, '{}') && array['p_user']
            or p.proname in ('grant_purchase', 'revoke_purchase', 'grant_ad_reward', 'youtube_token', 'youtube_guardar',
                             'lz_revisar', 'complete_game_job', 'complete_publish_job', 'complete_marketing_job', 'fail_job'))
  loop
    if has_function_privilege('anon', r.oid, 'execute') or has_function_privilege('authenticated', r.oid, 'execute') then
      malas := malas || r.proname || '(' || r.args || ') ';
    end if;
  end loop;
  assert malas = '', 'funciones peligrosas abiertas: ' || malas;
  -- Tablas con datos privados: RLS activado.
  for r in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity loop
    malas := malas || r.relname || ' ';
  end loop;
  assert malas = '', 'tablas sin RLS: ' || malas;
  raise notice 'SEGURIDAD OK';
end $$;
select 'SEGURIDAD OK';

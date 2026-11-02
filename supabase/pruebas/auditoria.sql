\set ON_ERROR_STOP 1
-- Auditoria de seguridad de toda la base: cada tabla con RLS, cada funcion SECURITY DEFINER con su
-- search_path fijo y nada ejecutable por anonimos salvo lo que esta en la lista (lo publico a proposito).
do $$
declare
  r record;
  malos text := '';
begin
  -- Lo que juegan los juegos publicados sin cuenta (con su sesion anonima) y el escaparate publico.
  perform set_config('orq.publicas', 'marcador_top,marcador_enviar,arena_estado,arena_resultado,arena_top,arena_buscar,arena_empezar,' ||
    'arena_privada_unir,arena_privada_crear,escaparate_ficha,escaparate_jugada,escaparate_lista,registrar_partida,' ||
    'liga_repeticion,liga_defensas,liga_repeticion_subir,liga_top,liga_rival,liga_publicar,liga_resultado,clan_top,clan_crear,' ||
    'clan_unir,clan_salir,clan_info,clan_guerra,clan_guerra_cobrar,amigo_codigo,amigo_anadir,amigo_quitar,amigos_top,' ||
    'charla_activa,torneo_info,torneo_enviar,torneo_top,torneo_reclamar,evento_actual,premio_actual,premio_ganado,regalo_ficha,regalo_abierto,regalo_juego,regalo_leido,opinion_enviar,clase_unirse,clase_progreso,evento_regalo_cobrar,fantasma_subir,' ||
    'fantasma_bajar,nube_guardar,nube_restaurar,reto_actual,reto_ranking', false);
  -- 1 - Todas las tablas de public con seguridad por filas.
  for r in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity loop
    malos := malos || ' tabla sin RLS: ' || r.relname || ';';
  end loop;
  -- 2 - SECURITY DEFINER siempre con search_path (si no, se puede secuestrar con otro esquema).
  for r in select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prosecdef
              and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) x where x like 'search_path=%') loop
    malos := malos || ' definer sin search_path: ' || r.proname || ';';
  end loop;
  -- 3 - Funciones SECURITY DEFINER que un anonimo puede ejecutar: solo las publicas a proposito.
  for r in select p.proname, pg_get_function_identity_arguments(p.oid) as args from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prosecdef and has_function_privilege('anon', p.oid, 'execute')
              and p.proname not in (select unnest(string_to_array(current_setting('orq.publicas', true), ','))) loop
    malos := malos || ' anon puede ejecutar: ' || r.proname || '(' || r.args || ');';
  end loop;
  if malos <> '' then raise exception 'AUDITORIA:%', malos; end if;
  -- 4 - Ninguna funcion de disparador ejecutable por usuarios (migracion 40).
  for r in select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prorettype = 'trigger'::regtype
              and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute')) loop
    malos := malos || ' disparador ejecutable: ' || r.proname || ';';
  end loop;
  if malos <> '' then raise exception 'AUDITORIA:%', malos; end if;
  raise notice 'AUDITORIA OK';
end $$;

-- Reloj dentro de Supabase (12 de noviembre de 2026).
--
-- El Reloj de GitHub Actions corria cada 15 minutos y se comio los 2.000 minutos gratis del mes:
-- GitHub bloqueo todos los workflows (ni despliegues ni avisos). Lo que es de la base de datos o de
-- la nube pasa aqui, con pg_cron (gratis):
--   - cada 15 min, dentro de la base: Lanzadera, premio del reto semanal y trabajos colgados;
--   - cada 15 min, por HTTP (pg_net) a la funcion "reloj": despertar la fabrica si hay cola;
--   - cada 6 horas, por HTTP: reembolsos de Google Play y que la fabrica aprenda de las partidas.
-- En GitHub queda solo un reloj lento (vigilante del gasto con correo, juegos de muestra, web).
--
-- La funcion "reloj" no la puede llamar cualquiera: lleva una clave aleatoria que solo conoce la
-- base (tabla privada, sin acceso para la app). La direccion del proyecto la apunta el despliegue
-- (reloj_configurar) porque una migracion no la sabe.

create table if not exists public.reloj_privado (
  id boolean primary key default true check (id),
  url text,
  clave text not null default replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),
  actualizado timestamptz not null default now()
);
alter table public.reloj_privado enable row level security;
revoke all on public.reloj_privado from public, anon, authenticated;
insert into public.reloj_privado (id) values (true) on conflict (id) do nothing;

-- La llama el despliegue con la clave de servicio: guarda la direccion del proyecto.
create or replace function public.reloj_configurar(p_url text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_url is null or p_url !~ '^https://' then return false; end if;
  update public.reloj_privado set url = rtrim(p_url, '/'), actualizado = now() where id;
  return true;
end;
$$;
revoke all on function public.reloj_configurar(text) from public, anon, authenticated;
grant execute on function public.reloj_configurar(text) to service_role;

-- Lo que el Reloj de GitHub hacia con curl contra la base: cada tarea por separado (si una falla,
-- las demas corren igual).
create or replace function public.reloj_bd()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v jsonb := '{}'::jsonb;
begin
  begin perform public.lz_revisar(); v := v || '{"lanzadera": true}';
  exception when others then v := v || jsonb_build_object('lanzadera', sqlerrm); end;
  begin perform public.reto_premiar_anterior(); v := v || '{"reto": true}';
  exception when others then v := v || jsonb_build_object('reto', sqlerrm); end;
  begin perform public.expire_stuck_jobs(); v := v || '{"colgados": true}';
  exception when others then v := v || jsonb_build_object('colgados', sqlerrm); end;
  return v;
end;
$$;
revoke all on function public.reloj_bd() from public, anon, authenticated;
grant execute on function public.reloj_bd() to service_role;

-- Llama a la funcion "reloj" (despertar la fabrica; con p_seis_horas tambien reembolsos y aprender).
-- Solo si hay algo que hacer: sin cola y fuera de las 6 horas no gasta ni una llamada.
create or replace function public.reloj_llamar(p_seis_horas boolean)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.reloj_privado;
begin
  select * into r from public.reloj_privado where id;
  if r.url is null then return false; end if;
  if not p_seis_horas and not exists (select 1 from public.jobs where status = 'queued') then return false; end if;
  perform net.http_post(
    url := r.url || '/functions/v1/reloj',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-reloj', r.clave),
    body := jsonb_build_object('seis_horas', p_seis_horas),
    timeout_milliseconds := 20000);
  return true;
end;
$$;
revoke all on function public.reloj_llamar(boolean) from public, anon, authenticated;
grant execute on function public.reloj_llamar(boolean) to service_role;

-- Programacion (en las pruebas locales no hay pg_cron ni pg_net: solo se avisa).
do $$
begin
  create extension if not exists pg_cron;
  create extension if not exists pg_net;
  perform cron.unschedule(jobid) from cron.job where jobname in ('orq-reloj-bd', 'orq-reloj-fabrica', 'orq-reloj-6h');
  perform cron.schedule('orq-reloj-bd', '*/15 * * * *', 'select public.reloj_bd()');
  perform cron.schedule('orq-reloj-fabrica', '*/15 * * * *', 'select public.reloj_llamar(false)');
  perform cron.schedule('orq-reloj-6h', '41 */6 * * *', 'select public.reloj_llamar(true)');
exception when others then
  raise notice 'sin pg_cron o pg_net: el reloj solo corre a mano (%).', sqlerrm;
end;
$$;

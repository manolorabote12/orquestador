-- Guardian dentro de la base de datos (10 de noviembre de 2026).
--
-- El Reloj de GitHub esta programado cada 15 minutos, pero GitHub lo retrasa: en la practica corre
-- cada 1-6 horas. Para que la parada automatica no dependa de el, la propia base de datos mira cada
-- 5 minutos (pg_cron) y PARA la fabrica si la ultima hora costo mas que 'alarma_hora_usd'.
-- El aviso por correo sigue llegando con el siguiente Reloj (ve la fabrica parada y lo dice).

insert into public.settings (key, value, note) values
  ('alarma_hora_usd', 3, 'Si la ultima hora cuesta mas que esto (USD), la fabrica se para sola')
on conflict (key) do nothing;

create or replace function public.guardian()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hora numeric;
begin
  if public.fabrica_pausada() then return false; end if;
  select coalesce(sum(coalesce(provider_cost_usd, est_cost_usd, 0)), 0) into v_hora from public.jobs
   where created_at > now() - interval '1 hour' or finished_at > now() - interval '1 hour';
  if v_hora > public.setting('alarma_hora_usd') then
    perform public.pausar_fabrica(true, 'guardian: la ultima hora costo ' || round(v_hora, 2) || ' $');
    return true;
  end if;
  return false;
end;
$$;

revoke all on function public.guardian() from public, anon, authenticated;
grant execute on function public.guardian() to service_role;

-- Cada 5 minutos, si la base de datos tiene pg_cron (Supabase lo trae; en las pruebas locales no).
do $$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule(jobid) from cron.job where jobname = 'orq-guardian';
  perform cron.schedule('orq-guardian', '*/5 * * * *', 'select public.guardian()');
exception when others then
  raise notice 'sin pg_cron: el guardian solo corre a mano (%).', sqlerrm;
end;
$$;

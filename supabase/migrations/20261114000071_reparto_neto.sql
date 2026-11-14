-- Reparto de la galeria sobre lo que queda despues de pagar lo que cuesta servir los juegos
-- (descargas del motor y de los paquetes): asi el 80/20 nunca hace perder dinero (14 nov 2026).
update public.settings
   set note = 'Parte (%) de lo que pagan los anuncios de la galeria, despues de los costes de servirlos, que va a los creadores'
 where key = 'galeria_reparto_pct';

alter table public.galeria_repartos add column if not exists costes_cent integer not null default 0;

drop function if exists public.galeria_reparto(date, integer);

create or replace function public.galeria_reparto(p_mes date, p_ingresos_cent integer, p_costes_cent integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ini timestamptz := date_trunc('month', p_mes::timestamptz);
  v_fin timestamptz := date_trunc('month', p_mes::timestamptz) + interval '1 month';
  v_total integer;
  v_bolsa integer;
  v_repartido integer := 0;
  v_creadores integer := 0;
  r record;
  v_parte integer;
begin
  if p_ingresos_cent is null or p_ingresos_cent < 0 or coalesce(p_costes_cent, 0) < 0 then raise exception 'bad_amount'; end if;
  if exists (select 1 from public.galeria_repartos where mes = date_trunc('month', p_mes)::date) then
    raise exception 'already_done';
  end if;
  select count(*) into v_total from public.galeria_anuncios where valido and created_at >= v_ini and created_at < v_fin;
  -- Se reparte lo que queda despues de pagar lo que cuesta servir los juegos (nunca negativo).
  v_bolsa := (greatest(p_ingresos_cent - coalesce(p_costes_cent, 0), 0) * public.setting('galeria_reparto_pct') / 100)::integer;
  if v_total > 0 and v_bolsa > 0 then
    for r in select autor, count(*) as n from public.galeria_anuncios
              where valido and created_at >= v_ini and created_at < v_fin group by autor loop
      -- Redondeo hacia abajo: la suma nunca pasa de la bolsa.
      v_parte := (v_bolsa::bigint * r.n / v_total)::integer;
      if v_parte > 0 then
        insert into public.creador_saldo (user_id, saldo_cent, ganado_cent) values (r.autor, v_parte, v_parte)
        on conflict (user_id) do update set saldo_cent = creador_saldo.saldo_cent + v_parte,
          ganado_cent = creador_saldo.ganado_cent + v_parte, updated_at = now();
        insert into public.creador_movimientos (user_id, tipo, cent, nota)
        values (r.autor, 'reparto', v_parte, 'Anuncios de ' || to_char(v_ini, 'MM/YYYY') || ': ' || r.n);
        v_repartido := v_repartido + v_parte;
        v_creadores := v_creadores + 1;
      end if;
    end loop;
  end if;
  insert into public.galeria_repartos (mes, ingresos_cent, reparto_cent, anuncios, creadores, costes_cent)
  values (date_trunc('month', p_mes)::date, p_ingresos_cent, v_repartido, v_total, v_creadores, coalesce(p_costes_cent, 0));
  return jsonb_build_object('mes', to_char(v_ini, 'YYYY-MM'), 'anuncios', v_total, 'ingresos_cent', p_ingresos_cent,
    'repartido_cent', v_repartido, 'creadores', v_creadores, 'costes_cent', coalesce(p_costes_cent, 0));
end;
$$;

revoke all on function public.galeria_reparto(date, integer, integer) from public, anon, authenticated;
grant execute on function public.galeria_reparto(date, integer, integer) to service_role;

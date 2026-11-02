-- Panel de ingresos y jugadores del autor (app -> Jugadores -> Ingresos y jugadores).
--   juego_ingresos(p_project, p_dias): por dia (UTC) jugadores, nuevos, partidas, compras y euros;
--   ventas por producto; total bruto y lo que le queda al autor (85 %: Google se queda el 15 %);
--   retencion D1 y D7 (de los que empezaron, cuantos volvieron al dia siguiente / a los 7 dias).
-- Los jugadores salen de los datos anonimos de partida (solo si el jugador no los ha apagado).
-- Los anuncios no estan aqui: AdMob los paga y los cuenta en su propia consola.

create index if not exists partidas_dia_idx on public.partidas (juego, created_at);

create or replace function public.juego_ingresos(p_project uuid, p_dias integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_juego uuid;
  v_dias integer := least(greatest(coalesce(p_dias, 30), 7), 90);
  v_desde date;
  v_out jsonb;
begin
  select pr.telemetria_id into v_juego from public.projects pr where pr.id = p_project and pr.user_id = auth.uid();
  if not found then raise exception 'project_not_found'; end if;
  v_desde := (now() at time zone 'UTC')::date - (v_dias - 1);
  with dias as (
    select generate_series(v_desde, (now() at time zone 'UTC')::date, interval '1 day')::date as dia
  ), act as (
    select (created_at at time zone 'UTC')::date as dia, sesion, count(*) as n
      from public.partidas where juego = v_juego and created_at >= v_desde - interval '8 days'
     group by 1, 2
  ), primero as (
    select sesion, min(dia) as dia from act group by sesion
  ), compras as (
    select (created_at at time zone 'UTC')::date as dia, producto, public.iap_precio(producto) as eur
      from public.juego_compras where juego = v_juego and created_at >= v_desde
  ), por_dia as (
    select d.dia,
      (select count(distinct a.sesion) from act a where a.dia = d.dia)::integer as jugadores,
      (select count(*) from primero f where f.dia = d.dia)::integer as nuevos,
      (select coalesce(sum(a.n), 0) from act a where a.dia = d.dia)::integer as partidas,
      (select count(*) from compras c where c.dia = d.dia)::integer as compras,
      (select coalesce(sum(c.eur), 0) from compras c where c.dia = d.dia)::numeric as euros
    from dias d
  ), coh as (
    select f.sesion, f.dia,
      exists (select 1 from act a where a.sesion = f.sesion and a.dia = f.dia + 1) as d1,
      exists (select 1 from act a where a.sesion = f.sesion and a.dia = f.dia + 7) as d7
    from primero f where f.dia >= v_desde
  )
  select jsonb_build_object(
    'dias', (select coalesce(jsonb_agg(jsonb_build_object('dia', dia, 'jugadores', jugadores, 'nuevos', nuevos,
               'partidas', partidas, 'compras', compras, 'euros', euros) order by dia), '[]'::jsonb) from por_dia),
    'productos', (select coalesce(jsonb_agg(jsonb_build_object('producto', producto, 'ventas', n, 'euros', eur) order by eur desc), '[]'::jsonb)
                    from (select producto, count(*)::integer as n, sum(eur) as eur from compras group by producto) x),
    'total_euros', (select coalesce(sum(eur), 0) from compras),
    'neto_euros', round((select coalesce(sum(eur), 0) from compras) * 0.85, 2),
    -- Solo cuentan los que empezaron hace al menos 1 (o 7) dias completos.
    'd1', (select round(100.0 * count(*) filter (where d1) / nullif(count(*), 0)) from coh
            where dia <= (now() at time zone 'UTC')::date - 1),
    'd7', (select round(100.0 * count(*) filter (where d7) / nullif(count(*), 0)) from coh
            where dia <= (now() at time zone 'UTC')::date - 7),
    'jugadores_total', (select count(distinct sesion) from act where dia >= v_desde)
  ) into v_out;
  return v_out;
end;
$$;

revoke all on function public.juego_ingresos(uuid, integer) from public, anon;
grant execute on function public.juego_ingresos(uuid, integer) to authenticated;

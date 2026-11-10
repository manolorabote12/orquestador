-- Embudo de jugadores y vigilancia del correo (10 de noviembre de 2026).
--
-- 1 - embudo(dias): de cada 100 que se registran, cuantos verifican, hacen un juego, lo terminan y compran.
--     El estudio de precios supone que compran unos 6 de cada 100: con esto se ve si es verdad.
-- 2 - vigilancia() cuenta tambien los correos de acceso de las ultimas 24 h: Gmail deja unos 500 al dia
--     y si se pasa nadie recibe el codigo para entrar. El vigilante avisa al llegar a 400.

create or replace function public.vigilancia(p_caro_usd numeric default 0.8, p_minutos integer default 20)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'pausada', public.fabrica_pausada(),
    'nota_pausa', (select note from public.settings where key = 'fabrica_pausada'),
    'hora_usd', (select round(coalesce(sum(coalesce(provider_cost_usd, est_cost_usd, 0)), 0), 3) from public.jobs
                  where created_at > now() - interval '1 hour' or (finished_at > now() - interval '1 hour')),
    'dia_usd', (select round(coalesce(sum(coalesce(provider_cost_usd, est_cost_usd, 0)), 0), 3) from public.jobs
                 where created_at >= date_trunc('day', now())),
    'presupuesto_dia_usd', public.setting('daily_budget_usd'),
    'en_marcha', (select count(*) from public.jobs where status = 'running'),
    -- Correos de acceso enviados en 24 h (aprox.: altas, codigos y cambios de correo). Gmail corta en ~500.
    'correos_24h', (select count(*) from auth.users u, lateral (select to_jsonb(u) j) x
                     where greatest(nullif(j ->> 'confirmation_sent_at', '')::timestamptz, nullif(j ->> 'recovery_sent_at', '')::timestamptz,
                                    nullif(j ->> 'email_change_sent_at', '')::timestamptz, nullif(j ->> 'last_sign_in_at', '')::timestamptz,
                                    u.created_at) > now() - interval '24 hours'),
    'en_cola', (select count(*) from public.jobs where status = 'queued'),
    'juegos_dia', (select count(*) from public.jobs where kind like 'game%' and created_at >= date_trunc('day', now())),
    'fallidos_dia', (select count(*) from public.jobs where kind like 'game%' and status = 'failed' and created_at >= date_trunc('day', now())),
    'caros', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'kind', kind, 'usd', provider_cost_usd, 'status', status)), '[]'::jsonb)
                from public.jobs
               where provider_cost_usd >= p_caro_usd and finished_at > now() - make_interval(mins => p_minutos)),
    'fallos_recientes', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'kind', kind, 'error', left(error, 160), 'usd', provider_cost_usd)), '[]'::jsonb)
                from public.jobs
               where status = 'failed' and kind like 'game%' and finished_at > now() - make_interval(mins => p_minutos))
  )
$$;

revoke all on function public.vigilancia(numeric, integer) from public, anon, authenticated;
grant execute on function public.vigilancia(numeric, integer) to service_role;

create or replace function public.embudo(p_dias integer default 30)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with nuevos as (
    select u.id, u.email_confirmed_at is not null as verificado from auth.users u
     where u.created_at > now() - make_interval(days => p_dias)
  ), juegos as (
    select j.user_id, bool_or(j.status = 'done') as terminado from public.jobs j
     where j.kind = 'game' and j.user_id in (select id from nuevos) group by j.user_id
  ), compras as (
    select l.user_id, sum(l.amount) as tuercas from public.credit_ledger l
     where l.reason = 'purchase' and l.user_id in (select id from nuevos) group by l.user_id
  )
  select jsonb_build_object(
    'dias', p_dias,
    'registros', (select count(*) from nuevos),
    'verificados', (select count(*) from nuevos where verificado),
    'con_juego', (select count(*) from juegos),
    'juego_terminado', (select count(*) from juegos where terminado),
    'compradores', (select count(*) from compras),
    'tuercas_compradas', (select coalesce(sum(tuercas), 0) from compras),
    'pct_compran', (select case when count(*) = 0 then 0 else round(100.0 * (select count(*) from compras) / count(*), 1) end from nuevos where verificado),
    'compradores_total', (select count(distinct user_id) from public.credit_ledger where reason = 'purchase'),
    'anuncios_30d', (select count(*) from public.credit_ledger where reason = 'reward_ad' and created_at > now() - interval '30 days')
  )
$$;

revoke all on function public.embudo(integer) from public, anon, authenticated;
grant execute on function public.embudo(integer) to service_role;

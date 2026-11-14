-- Compras a medida (14 nov 2026): cada creador decide que vende en su juego (moneda propia, packs
-- con su precio, sin anuncios, pase y VIP de suscripcion). Va en projects.tienda (lo valida
-- set_project_tienda, igual que fabrica/play/tienda.py) y viaja con la publicacion a Google Play.
-- 1 - juego_compra_anotar acepta los productos del creador y guarda su precio (precio_eur).
-- 2 - Galeria web: aun no se cobra; tienda_intento apunta quien quiso comprar y por cuanto, y
--     tienda_intentos_mes da la cuenta de lo que se habria vendido y la comision de Orquestador
--     (setting web_compras_comision_pct) para decidir si merece la pena abrir las compras web.
-- 3 - web_compras_activas: interruptor (apagado hasta que el dueno tenga alta y pasarela de pago).

alter table public.projects add column if not exists tienda jsonb;
alter table public.juego_compras add column if not exists precio_eur numeric;

insert into public.settings (key, value, note)
values ('web_compras_activas', 0, 'Compras con dinero en los juegos de la web (0 = solo se apuntan los intentos)')
on conflict (key) do nothing;

-- ============ 1 - Validar y guardar la tienda del creador
create or replace function public.tienda_validar(t jsonb)
returns text
language plpgsql
immutable
as $$
declare
  p jsonb; v_ids text[] := '{}'; v_vip integer := 0; v_pase integer := 0; v_id text; v_tipo text; v_cent integer;
begin
  if jsonb_typeof(t) <> 'object' then return 'bad_store'; end if;
  if length(trim(coalesce(t #>> '{moneda,nombre}', ''))) not between 1 and 20 then return 'bad_currency'; end if;
  if coalesce(t #>> '{moneda,icono}', 'coin') not in ('coin', 'gem', 'star', 'heart', 'trophy', 'cube') then return 'bad_icon'; end if;
  if jsonb_typeof(t -> 'productos') <> 'array' or jsonb_array_length(t -> 'productos') not between 1 and 12 then return 'bad_products'; end if;
  for p in select * from jsonb_array_elements(t -> 'productos') loop
    v_id := coalesce(p ->> 'id', ''); v_tipo := coalesce(p ->> 'tipo', '');
    if v_id !~ '^[a-z][a-z0-9_]{2,39}$' or v_id = any(v_ids) then return 'bad_id'; end if;
    v_ids := v_ids || v_id;
    if v_tipo not in ('monedas', 'sin_anuncios', 'pack', 'pase', 'vip') then return 'bad_kind'; end if;
    if jsonb_typeof(p -> 'precio_cent') <> 'number' then return 'bad_price'; end if;
    v_cent := (p ->> 'precio_cent')::numeric;
    if v_cent::numeric <> (p ->> 'precio_cent')::numeric or v_cent not between 10 and 9999 then return 'bad_price'; end if;
    if v_tipo in ('monedas', 'pack') and (jsonb_typeof(p -> 'cantidad') <> 'number' or (p ->> 'cantidad')::numeric not between 1 and 1000000) then
      return 'bad_amount';
    end if;
    if length(coalesce(p ->> 'nombre', '')) > 40 then return 'bad_name'; end if;
    if v_tipo = 'vip' then
      v_vip := v_vip + 1;
      if coalesce(p ->> 'periodo', 'mes') not in ('semana', 'mes', 'anio') then return 'bad_period'; end if;
      if coalesce((p ->> 'extra_pct')::numeric, 0) not between 0 and 300 or coalesce((p ->> 'diario')::numeric, 0) not between 0 and 100000 then
        return 'bad_vip';
      end if;
    end if;
    if v_tipo = 'pase' then v_pase := v_pase + 1; end if;
  end loop;
  if v_vip > 2 then return 'too_many_vip'; end if;
  if v_pase > 1 then return 'too_many_pass'; end if;
  return null;
end;
$$;

create or replace function public.set_project_tienda(p_project uuid, p_tienda jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_err text;
begin
  if auth.uid() is null then raise exception 'unknown_user'; end if;
  if not exists (select 1 from public.projects where id = p_project and user_id = auth.uid()) then
    raise exception 'project_not_found';
  end if;
  if p_tienda is null or p_tienda = '{}'::jsonb then
    update public.projects set tienda = null where id = p_project;
    return null;
  end if;
  v_err := public.tienda_validar(p_tienda);
  if v_err is not null then raise exception '%', v_err; end if;
  update public.projects set tienda = p_tienda where id = p_project;
  return p_tienda;
end;
$$;
revoke all on function public.set_project_tienda(uuid, jsonb) from public, anon;
grant execute on function public.set_project_tienda(uuid, jsonb) to authenticated;

-- Precio (euros) de un producto en un juego: el del creador o el del kit.
create or replace function public.iap_precio_juego(p_juego uuid, p_producto text)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select (e ->> 'precio_cent')::numeric / 100 from public.projects pr,
      jsonb_array_elements(coalesce(pr.tienda -> 'productos', '[]'::jsonb)) e
    where pr.telemetria_id = p_juego and e ->> 'id' = p_producto limit 1), public.iap_precio(p_producto));
$$;
revoke all on function public.iap_precio_juego(uuid, text) from public, anon, authenticated;

-- ============ La publicacion lleva tambien la tienda del creador.
create or replace function public.queue_publish(p_user uuid, p_project uuid, p_modo text, p_pista text)
returns table (job_id uuid, credits_left integer, cost integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_cuenta public.play_cuentas%rowtype;
  v_play jsonb;
  v_admob jsonb;
  v_tienda jsonb;
begin
  if p_modo not in ('primer_aab', 'subir') then raise exception 'bad_mode'; end if;
  if p_pista not in ('internal', 'alpha', 'beta', 'production') then raise exception 'bad_track'; end if;
  select * into v_cuenta from public.play_cuentas where user_id = p_user;
  if not found then raise exception 'play_setup_missing'; end if;
  select play, admob, tienda into v_play, v_admob, v_tienda from public.projects where id = p_project and user_id = p_user;
  if not found then raise exception 'project_not_found'; end if;
  if p_modo = 'subir' and coalesce(v_play ->> 'paquete', '') = '' then raise exception 'first_aab_missing'; end if;
  if exists (select 1 from public.jobs where project_id = p_project and status in ('queued', 'running')) then
    raise exception 'project_busy';
  end if;
  select * into r from public.reserve_job(p_user, 'game_publish', jsonb_build_object(
    'modo', p_modo, 'pista', p_pista, 'estudio', v_cuenta.estudio, 'correo', v_cuenta.correo,
    'paquete', v_play ->> 'paquete', 'version_code', coalesce((v_play ->> 'version_code')::int, 0),
    'admob', v_admob, 'tienda', v_tienda));
  update public.jobs set status = 'queued', project_id = p_project where id = r.job_id;
  return query select r.job_id, r.credits_left, r.cost;
end;
$$;

-- ============ Anotar compras: tambien las del creador, con su precio.
create or replace function public.juego_compra_anotar(p_juego uuid, p_sesion text, p_producto text, p_token text, p_orden text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_eur numeric;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  v_eur := public.iap_precio_juego(p_juego, p_producto);
  if v_eur = 0 then raise exception 'unknown_product'; end if;
  insert into public.juego_compras (juego, producto, token, orden, sesion, precio_eur)
  values (p_juego, p_producto, p_token, p_orden, p_sesion, v_eur) on conflict (token) do nothing;
  return found;
end;
$$;
revoke all on function public.juego_compra_anotar(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.juego_compra_anotar(uuid, text, text, text, text) to service_role;

-- ============ 2 - Galeria web: intentos de compra (sin cobrar)
create table if not exists public.tienda_intentos (
  id         bigserial primary key,
  juego      uuid not null,
  producto   text not null,
  sesion     text not null,
  precio_eur numeric not null,
  created_at timestamptz not null default now()
);
create index if not exists tienda_intentos_idx on public.tienda_intentos (created_at, juego);
alter table public.tienda_intentos enable row level security;

-- La llama el juego en la web (clave anon). Uno por jugador, juego y producto al dia (no se infla).
create or replace function public.tienda_intento(p_juego uuid, p_sesion text, p_producto text, p_precio text default '')
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_eur numeric;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then return false; end if;
  if not exists (select 1 from public.projects where telemetria_id = p_juego) then return false; end if;
  v_eur := public.iap_precio_juego(p_juego, p_producto);
  if v_eur = 0 then return false; end if;
  if exists (select 1 from public.tienda_intentos where juego = p_juego and sesion = p_sesion and producto = p_producto
               and created_at > now() - interval '1 day') then
    return false;
  end if;
  insert into public.tienda_intentos (juego, producto, sesion, precio_eur) values (p_juego, p_producto, p_sesion, v_eur);
  return true;
end;
$$;
revoke all on function public.tienda_intento(uuid, text, text, text) from public;
grant execute on function public.tienda_intento(uuid, text, text, text) to anon, authenticated;

-- Para el dueno (service_role): lo que se habria vendido en la web un mes y lo que ganaria.
-- Cuenta la pasarela (1,5 % + 0,25 EUR por cobro) y la paga la parte del creador.
create or replace function public.tienda_intentos_mes(p_mes date)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with x as (
    select * from public.tienda_intentos
     where created_at >= date_trunc('month', p_mes) and created_at < date_trunc('month', p_mes) + interval '1 month'
  )
  select jsonb_build_object(
    'mes', to_char(date_trunc('month', p_mes), 'YYYY-MM'),
    'intentos', (select count(*) from x),
    'jugadores', (select count(distinct sesion) from x),
    'juegos', (select count(distinct juego) from x),
    'euros', (select coalesce(sum(precio_eur), 0) from x),
    'comision_pct', public.setting('web_compras_comision_pct'),
    'comision_euros', round((select coalesce(sum(precio_eur), 0) from x) * public.setting('web_compras_comision_pct') / 100.0, 2),
    'pasarela_euros', round((select coalesce(sum(precio_eur * 0.015 + 0.25), 0) from x), 2),
    'productos', (select coalesce(jsonb_agg(jsonb_build_object('producto', producto, 'intentos', n, 'euros', e) order by e desc), '[]'::jsonb)
                    from (select producto, count(*) as n, sum(precio_eur) as e from x group by producto) y));
$$;
revoke all on function public.tienda_intentos_mes(date) from public, anon, authenticated;
grant execute on function public.tienda_intentos_mes(date) to service_role;

-- ============ Ingresos del juego: con el precio de cada venta (las del creador tienen el suyo).
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
    select (created_at at time zone 'UTC')::date as dia, producto, coalesce(precio_eur, public.iap_precio(producto)) as eur
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

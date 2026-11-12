-- Galeria tipo Poki: los juegos del Escaparate se juegan dentro de la app con anuncios de AdMob
-- (de Orquestador) y sus creadores ganan una parte.
--
-- 1 - Cada anuncio que se ve jugando a un juego de la galeria se apunta (galeria_anuncio). No cuenta
--     si lo ve su propio autor y hay topes por jugador y dia: nadie gana jugando a su juego en bucle.
-- 2 - Cada mes, el dueno mete lo que Google pago de verdad por esos anuncios (workflow «Galeria:
--     reparto del mes»). galeria_reparto reparte el 50 % entre los creadores segun sus anuncios
--     validos. Nunca se reparte mas de lo que entra. Una sola vez por mes.
-- 3 - El creador elige: pasar su saldo a tuercas (1 EUR = 150, mejor que comprarlas) o cobrarlo en
--     dinero por PayPal desde 20 EUR, cuando el dueno active los cobros (cobro_dinero_activo = 1).
--     Los cobros los paga el dueno a mano (workflow) y quedan apuntados.

insert into public.settings (key, value, note) values
  ('galeria_reparto_pct', 50, 'Parte (%) de lo que pagan los anuncios de la galeria que va a los creadores'),
  ('ganancias_tuercas_por_euro', 150, 'Tuercas por cada euro de ganancias que el creador pasa a tuercas'),
  ('cobro_minimo_cent', 2000, 'Minimo (centimos) para pedir un cobro en dinero'),
  ('cobro_dinero_activo', 0, '1 = los creadores pueden pedir cobros en dinero (PayPal). Activar cuando el dueno pueda pagar'),
  ('galeria_anuncios_jugador_dia', 30, 'Anuncios por jugador y dia que cuentan para el reparto'),
  ('galeria_anuncios_juego_dia', 10, 'Anuncios por jugador, juego y dia que cuentan para el reparto')
on conflict (key) do nothing;

create table if not exists public.galeria_anuncios (
  id bigserial primary key,
  project_id uuid not null,
  autor uuid not null,
  jugador uuid not null,
  tipo text not null check (tipo in ('intersticial', 'premio')),
  valido boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists galeria_anuncios_mes on public.galeria_anuncios (created_at, valido);
create index if not exists galeria_anuncios_jugador on public.galeria_anuncios (jugador, created_at);
alter table public.galeria_anuncios enable row level security;

create table if not exists public.galeria_repartos (
  mes date primary key,
  ingresos_cent integer not null check (ingresos_cent >= 0),
  reparto_cent integer not null,
  anuncios integer not null,
  creadores integer not null,
  created_at timestamptz not null default now()
);
alter table public.galeria_repartos enable row level security;

create table if not exists public.creador_saldo (
  user_id uuid primary key references auth.users (id) on delete cascade,
  saldo_cent integer not null default 0 check (saldo_cent >= 0),
  ganado_cent integer not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.creador_saldo enable row level security;

create table if not exists public.creador_movimientos (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  tipo text not null check (tipo in ('reparto', 'a_tuercas', 'cobro', 'cobro_devuelto')),
  cent integer not null,
  tuercas integer not null default 0,
  nota text,
  created_at timestamptz not null default now()
);
create index if not exists creador_movimientos_user on public.creador_movimientos (user_id, created_at desc);
alter table public.creador_movimientos enable row level security;

create table if not exists public.creador_cobros (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  cent integer not null check (cent > 0),
  paypal text not null,
  nombre text not null,
  estado text not null default 'pendiente' check (estado in ('pendiente', 'pagado', 'rechazado')),
  nota text,
  created_at timestamptz not null default now(),
  cerrado_at timestamptz
);
alter table public.creador_cobros enable row level security;

-- 1 - Apuntar un anuncio visto en un juego de la galeria (lo llama la app tras mostrarlo).
create or replace function public.galeria_anuncio(p_project uuid, p_tipo text default 'intersticial')
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_yo uuid := auth.uid();
  v_autor uuid;
  v_hoy integer;
  v_juego integer;
  v_valido boolean;
begin
  if v_yo is null then raise exception 'not_authenticated'; end if;
  select user_id into v_autor from public.escaparate where project_id = p_project and not oculto;
  if v_autor is null then return false; end if;
  select count(*) filter (where valido), count(*) filter (where valido and project_id = p_project)
    into v_hoy, v_juego
    from public.galeria_anuncios where jugador = v_yo and created_at > now() - interval '1 day';
  v_valido := v_autor <> v_yo
    and v_hoy < public.setting('galeria_anuncios_jugador_dia')
    and v_juego < public.setting('galeria_anuncios_juego_dia');
  insert into public.galeria_anuncios (project_id, autor, jugador, tipo, valido)
  values (p_project, v_autor, v_yo, case when p_tipo = 'premio' then 'premio' else 'intersticial' end, v_valido);
  return v_valido;
end;
$$;

-- 2 - Reparto del mes con lo que Google pago de verdad (centimos). Idempotente: una vez por mes.
create or replace function public.galeria_reparto(p_mes date, p_ingresos_cent integer)
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
  if p_ingresos_cent is null or p_ingresos_cent < 0 then raise exception 'bad_amount'; end if;
  if exists (select 1 from public.galeria_repartos where mes = date_trunc('month', p_mes)::date) then
    raise exception 'already_done';
  end if;
  select count(*) into v_total from public.galeria_anuncios where valido and created_at >= v_ini and created_at < v_fin;
  v_bolsa := (p_ingresos_cent * public.setting('galeria_reparto_pct') / 100)::integer;
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
  insert into public.galeria_repartos (mes, ingresos_cent, reparto_cent, anuncios, creadores)
  values (date_trunc('month', p_mes)::date, p_ingresos_cent, v_repartido, v_total, v_creadores);
  return jsonb_build_object('mes', to_char(v_ini, 'YYYY-MM'), 'anuncios', v_total, 'ingresos_cent', p_ingresos_cent,
    'repartido_cent', v_repartido, 'creadores', v_creadores);
end;
$$;

-- 3 - Lo que ve el creador.
create or replace function public.mis_ganancias()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'saldo_cent', coalesce((select saldo_cent from public.creador_saldo where user_id = auth.uid()), 0),
    'ganado_cent', coalesce((select ganado_cent from public.creador_saldo where user_id = auth.uid()), 0),
    'anuncios_mes', (select count(*) from public.galeria_anuncios where autor = auth.uid() and valido
                      and created_at >= date_trunc('month', now())),
    'por_juego', coalesce((select jsonb_agg(x order by x.anuncios desc) from (
        select e.titulo, count(a.id) as anuncios from public.escaparate e
          left join public.galeria_anuncios a on a.project_id = e.project_id and a.valido and a.created_at >= date_trunc('month', now())
         where e.user_id = auth.uid() group by e.titulo) x), '[]'::jsonb),
    'movimientos', coalesce((select jsonb_agg(m) from (
        select tipo, cent, tuercas, nota, created_at from public.creador_movimientos
         where user_id = auth.uid() order by created_at desc limit 20) m), '[]'::jsonb),
    'cobros', coalesce((select jsonb_agg(c) from (
        select cent, estado, created_at from public.creador_cobros where user_id = auth.uid() order by created_at desc limit 10) c), '[]'::jsonb),
    'tuercas_por_euro', public.setting('ganancias_tuercas_por_euro'),
    'cobro_minimo_cent', public.setting('cobro_minimo_cent'),
    'cobro_activo', public.setting('cobro_dinero_activo') = 1,
    'reparto_pct', public.setting('galeria_reparto_pct'))
$$;

-- 4 - Pasar saldo a tuercas (cualquier cantidad desde 10 centimos).
create or replace function public.ganancias_a_tuercas(p_cent integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_yo uuid := auth.uid();
  v_saldo integer;
  v_tuercas integer;
  v_credits integer;
begin
  if v_yo is null then raise exception 'not_authenticated'; end if;
  if p_cent is null or p_cent < 10 then raise exception 'bad_amount'; end if;
  select saldo_cent into v_saldo from public.creador_saldo where user_id = v_yo for update;
  if coalesce(v_saldo, 0) < p_cent then raise exception 'insufficient'; end if;
  v_tuercas := (p_cent::bigint * public.setting('ganancias_tuercas_por_euro') / 100)::integer;
  update public.creador_saldo set saldo_cent = saldo_cent - p_cent, updated_at = now() where user_id = v_yo;
  update public.profiles set credits = credits + v_tuercas where id = v_yo returning credits into v_credits;
  insert into public.credit_ledger (user_id, amount, reason, ref) values (v_yo, v_tuercas, 'ganancias', p_cent::text || ' cent');
  insert into public.creador_movimientos (user_id, tipo, cent, tuercas, nota) values (v_yo, 'a_tuercas', -p_cent, v_tuercas, null);
  return jsonb_build_object('tuercas', v_tuercas, 'credits', v_credits, 'saldo_cent', v_saldo - p_cent);
end;
$$;

-- 5 - Pedir un cobro en dinero (todo el saldo). Solo con los cobros activados y desde el minimo.
create or replace function public.pedir_cobro(p_paypal text, p_nombre text, p_mayor boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_yo uuid := auth.uid();
  v_saldo integer;
begin
  if v_yo is null then raise exception 'not_authenticated'; end if;
  if public.setting('cobro_dinero_activo') <> 1 then raise exception 'cobros_off'; end if;
  if not coalesce(p_mayor, false) then raise exception 'adults_only'; end if;
  if coalesce(p_paypal, '') !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'bad_paypal'; end if;
  if char_length(trim(coalesce(p_nombre, ''))) < 4 then raise exception 'bad_name'; end if;
  if exists (select 1 from public.creador_cobros where user_id = v_yo and estado = 'pendiente') then raise exception 'pending_exists'; end if;
  select saldo_cent into v_saldo from public.creador_saldo where user_id = v_yo for update;
  if coalesce(v_saldo, 0) < public.setting('cobro_minimo_cent') then raise exception 'below_minimum'; end if;
  update public.creador_saldo set saldo_cent = 0, updated_at = now() where user_id = v_yo;
  insert into public.creador_cobros (user_id, cent, paypal, nombre) values (v_yo, v_saldo, lower(trim(p_paypal)), left(trim(p_nombre), 120));
  insert into public.creador_movimientos (user_id, tipo, cent, nota) values (v_yo, 'cobro', -v_saldo, 'PayPal');
  return jsonb_build_object('cent', v_saldo);
end;
$$;

-- 6 - El dueno cierra un cobro: pagado, o rechazado (el dinero vuelve al saldo).
create or replace function public.cobro_cerrar(p_id bigint, p_estado text, p_nota text default null)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  c public.creador_cobros%rowtype;
begin
  if p_estado not in ('pagado', 'rechazado') then raise exception 'bad_state'; end if;
  select * into c from public.creador_cobros where id = p_id for update;
  if not found then return 'unknown'; end if;
  if c.estado <> 'pendiente' then return 'already'; end if;
  update public.creador_cobros set estado = p_estado, nota = p_nota, cerrado_at = now() where id = p_id;
  if p_estado = 'rechazado' then
    insert into public.creador_saldo (user_id, saldo_cent) values (c.user_id, c.cent)
    on conflict (user_id) do update set saldo_cent = creador_saldo.saldo_cent + c.cent, updated_at = now();
    insert into public.creador_movimientos (user_id, tipo, cent, nota) values (c.user_id, 'cobro_devuelto', c.cent, p_nota);
  end if;
  return p_estado;
end;
$$;

revoke all on function public.galeria_anuncio(uuid, text) from public, anon;
grant execute on function public.galeria_anuncio(uuid, text) to authenticated;
revoke all on function public.mis_ganancias() from public, anon;
grant execute on function public.mis_ganancias() to authenticated;
revoke all on function public.ganancias_a_tuercas(integer) from public, anon;
grant execute on function public.ganancias_a_tuercas(integer) to authenticated;
revoke all on function public.pedir_cobro(text, text, boolean) from public, anon;
grant execute on function public.pedir_cobro(text, text, boolean) to authenticated;
revoke all on function public.galeria_reparto(date, integer) from public, anon, authenticated;
grant execute on function public.galeria_reparto(date, integer) to service_role;
revoke all on function public.cobro_cerrar(bigint, text, text) from public, anon, authenticated;
grant execute on function public.cobro_cerrar(bigint, text, text) to service_role;

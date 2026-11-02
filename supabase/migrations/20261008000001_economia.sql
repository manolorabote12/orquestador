-- Orquestador: economía de créditos blindada
--
-- Objetivo: que ninguna acción (código, imágenes, música, voces, compilación) pueda
-- costar más de lo que cobra, ni por error ni por abuso.
--
--  * pricing   : precio en créditos, tope diario por usuario y coste estimado de cada acción.
--  * settings  : presupuesto diario global, créditos de bienvenida, tope de devoluciones...
--  * reserve_job / finish_job / fail_job : el ÚNICO camino para gastar créditos.
--  * Créditos de bienvenida solo con cuenta verificada (correo confirmado o Google).
--  * Créditos por anuncio solo con verificación firmada de Google (función admob-reward).
--  * v_margin_by_kind : coste real frente a lo cobrado, para ajustar precios con datos.

-- ============ Precios por acción ============

create table public.pricing (
  kind          text primary key,
  label         text not null,
  credits       integer not null check (credits >= 0),
  max_per_day   integer not null check (max_per_day >= 0),   -- por usuario
  est_cost_usd  numeric(10, 4) not null check (est_cost_usd >= 0),
  enabled       boolean not null default true
);

-- Valores iniciales PROVISIONALES. est_cost_usd es una estimación prudente (por encima
-- de lo esperado) que se usa para el presupuesto global hasta tener datos reales.
-- Con 1 crédito ≈ 0,7 céntimos netos, cada precio cubre de sobra su coste estimado.
insert into public.pricing (kind, label, credits, max_per_day, est_cost_usd, enabled) values
  ('design',      'Crear juego (diseño con IA)',          20, 15, 0.015, true),
  ('edit',        'Cambio por chat',                        5, 60, 0.012, true),
  ('art_set',     'Arte completo (icono, fondo, sprites)', 60,  5, 0.250, false),
  ('art_image',   'Regenerar una imagen',                  10, 30, 0.040, false),
  ('music_track', 'Música a medida',                       40,  5, 0.150, false),
  ('voice_line',  'Locución corta',                         5, 30, 0.010, false),
  ('build',       'Compilar .aab para Google Play',       100,  3, 0.100, false);
-- art_*, music_*, voice_* y build quedan desactivados hasta que exista su trabajador.

-- ============ Ajustes globales ============

create table public.settings (
  key    text primary key,
  value  numeric not null,
  note   text
);

insert into public.settings (key, value, note) values
  ('daily_budget_usd',      20,    'Gasto máximo en proveedores (IA, GPU, compilación) por día UTC, sumando todos los usuarios'),
  ('max_jobs_per_minute',    4,    'Trabajos por usuario y minuto, de cualquier tipo'),
  ('max_refunds_per_day',    3,    'Devoluciones automáticas por usuario y día; a partir de ahí el fallo no se devuelve'),
  ('welcome_credits',       40,    'Créditos al verificar la cuenta'),
  ('reward_ad_credits',      5,    'Créditos por anuncio bonificado verificado por Google'),
  ('reward_ads_per_day',     5,    'Anuncios bonificados con premio por usuario y día'),
  ('credit_value_eur',   0.007,    'Valor neto de 1 crédito (pack 2,99 € / 300 cr, sin IVA ni comisión de Google)');

create or replace function public.setting(p_key text)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select value from public.settings where key = p_key
$$;

-- ============ Trabajos: tipos, coste real y devoluciones ============

alter table public.jobs drop constraint if exists jobs_kind_check;
alter table public.jobs add constraint jobs_kind_fk foreign key (kind) references public.pricing (kind);

alter table public.jobs
  add column refunded           boolean not null default false,
  add column est_cost_usd       numeric(10, 4) not null default 0,
  add column provider_cost_usd  numeric(10, 5),
  add column tokens_in          integer,
  add column tokens_out         integer,
  add column units              numeric,          -- imágenes, segundos de audio, minutos de compilación...
  add column detail             jsonb;

create index jobs_day_idx on public.jobs (created_at);

-- ============ Perfiles: bienvenida solo una vez y con cuenta verificada ============

alter table public.profiles add column welcome_granted boolean not null default false;

create or replace function public.grant_welcome(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_amount integer := public.setting('welcome_credits')::integer;
begin
  update public.profiles
     set welcome_granted = true,
         credits = credits + v_amount
   where id = p_user and not welcome_granted;
  if found and v_amount > 0 then
    insert into public.credit_ledger (user_id, amount, reason) values (p_user, v_amount, 'signup');
  end if;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, credits) values (new.id, 0);
  if new.email_confirmed_at is not null then      -- Google y otros proveedores ya vienen verificados
    perform public.grant_welcome(new.id);
  end if;
  return new;
end;
$$;

create or replace function public.handle_user_confirmed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email_confirmed_at is not null and old.email_confirmed_at is null then
    perform public.grant_welcome(new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_confirmed on auth.users;
create trigger on_auth_user_confirmed
  after update of email_confirmed_at on auth.users
  for each row execute function public.handle_user_confirmed();

-- ============ Reservar un trabajo: comprueba todo y cobra, en una sola transacción ============
-- Errores (en el mensaje): unknown_kind, kind_disabled, rate_limited, daily_limit,
-- budget_exceeded, insufficient_credits.

create or replace function public.reserve_job(p_user uuid, p_kind text, p_detail jsonb default null)
returns table (job_id uuid, credits_left integer, cost integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_price      public.pricing%rowtype;
  v_credits    integer;
  v_today      timestamptz := date_trunc('day', now());
  v_count      integer;
  v_spent      numeric;
  v_job        uuid;
begin
  select * into v_price from public.pricing where kind = p_kind;
  if not found then raise exception 'unknown_kind'; end if;
  if not v_price.enabled then raise exception 'kind_disabled'; end if;

  -- Bloquea el perfil: dos peticiones simultáneas del mismo usuario se ponen en fila.
  select credits into v_credits from public.profiles where id = p_user for update;
  if not found then raise exception 'unknown_user'; end if;

  select count(*) into v_count from public.jobs
   where user_id = p_user and created_at > now() - interval '1 minute';
  if v_count >= public.setting('max_jobs_per_minute') then raise exception 'rate_limited'; end if;

  select count(*) into v_count from public.jobs
   where user_id = p_user and kind = p_kind and created_at >= v_today;
  if v_count >= v_price.max_per_day then raise exception 'daily_limit'; end if;

  -- Presupuesto global: coste real de lo terminado + estimado de lo que sigue en marcha.
  select coalesce(sum(coalesce(provider_cost_usd, est_cost_usd)), 0) into v_spent
    from public.jobs where created_at >= v_today;
  if v_spent + v_price.est_cost_usd > public.setting('daily_budget_usd') then
    raise exception 'budget_exceeded';
  end if;

  if v_credits < v_price.credits then raise exception 'insufficient_credits'; end if;

  insert into public.jobs (user_id, kind, cost, est_cost_usd, detail)
  values (p_user, p_kind, v_price.credits, v_price.est_cost_usd, p_detail)
  returning id into v_job;

  if v_price.credits > 0 then
    update public.profiles set credits = credits - v_price.credits where id = p_user
    returning credits into v_credits;
    insert into public.credit_ledger (user_id, amount, reason, ref)
    values (p_user, -v_price.credits, p_kind, v_job::text);
  end if;

  return query select v_job, v_credits, v_price.credits;
end;
$$;

-- ============ Cerrar un trabajo con éxito, guardando su coste real ============

create or replace function public.finish_job(
  p_job uuid, p_cost_usd numeric, p_tokens_in integer default null,
  p_tokens_out integer default null, p_units numeric default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.jobs
     set status = 'done', finished_at = now(), provider_cost_usd = p_cost_usd,
         tokens_in = p_tokens_in, tokens_out = p_tokens_out, units = p_units
   where id = p_job and status = 'running';
  if not found then raise exception 'job_not_running'; end if;
end;
$$;

-- ============ Cerrar un trabajo fallido ============
-- p_cost_usd: lo que costó igualmente (p. ej. tokens gastados antes de fallar).
-- p_refund:   true si el fallo es nuestro. Solo se devuelve hasta max_refunds_per_day.
-- Devuelve true si se devolvieron los créditos.

create or replace function public.fail_job(
  p_job uuid, p_error text, p_cost_usd numeric default null, p_refund boolean default true)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job      public.jobs%rowtype;
  v_refunds  integer;
  v_refund   boolean := false;
begin
  select * into v_job from public.jobs where id = p_job and status = 'running' for update;
  if not found then raise exception 'job_not_running'; end if;

  if p_refund and v_job.cost > 0 then
    select count(*) into v_refunds from public.jobs
     where user_id = v_job.user_id and refunded and created_at >= date_trunc('day', now());
    if v_refunds < public.setting('max_refunds_per_day') then
      update public.profiles set credits = credits + v_job.cost where id = v_job.user_id;
      insert into public.credit_ledger (user_id, amount, reason, ref)
      values (v_job.user_id, v_job.cost, 'refund', v_job.id::text);
      v_refund := true;
    end if;
  end if;

  update public.jobs
     set status = 'failed', finished_at = now(), error = left(p_error, 500),
         provider_cost_usd = coalesce(p_cost_usd, 0), refunded = v_refund
   where id = p_job;

  return v_refund;
end;
$$;

-- Los trabajos que se quedan colgados (la función murió a mitad) se cierran solos:
-- cuentan su coste estimado y se devuelven con la misma regla.
create or replace function public.expire_stuck_jobs()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  n integer := 0;
begin
  for r in select id, est_cost_usd from public.jobs
            where status = 'running' and created_at < now() - interval '10 minutes'
  loop
    perform public.fail_job(r.id, 'timeout', r.est_cost_usd, true);
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- ============ Anuncios bonificados (solo desde la función admob-reward) ============

create table public.ad_rewards (
  transaction_id  text primary key,              -- id único que manda Google: evita cobrar dos veces
  user_id         uuid not null references public.profiles (id) on delete cascade,
  credits         integer not null,
  ad_unit         text,
  created_at      timestamptz not null default now()
);

alter table public.ad_rewards enable row level security;
create policy "ver mis recompensas" on public.ad_rewards
  for select to authenticated using (user_id = auth.uid());

-- Devuelve: 'granted', 'duplicate', 'daily_limit' o 'unknown_user'.
create or replace function public.grant_ad_reward(p_user uuid, p_tx text, p_ad_unit text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_amount integer := public.setting('reward_ad_credits')::integer;
  v_count  integer;
begin
  perform 1 from public.profiles where id = p_user for update;
  if not found then return 'unknown_user'; end if;

  if exists (select 1 from public.ad_rewards where transaction_id = p_tx) then
    return 'duplicate';
  end if;

  select count(*) into v_count from public.ad_rewards
   where user_id = p_user and created_at >= date_trunc('day', now());
  if v_count >= public.setting('reward_ads_per_day') then return 'daily_limit'; end if;

  insert into public.ad_rewards (transaction_id, user_id, credits, ad_unit)
  values (p_tx, p_user, v_amount, p_ad_unit);
  update public.profiles set credits = credits + v_amount where id = p_user;
  insert into public.credit_ledger (user_id, amount, reason, ref)
  values (p_user, v_amount, 'reward_ad', p_tx);
  return 'granted';
end;
$$;

-- ============ Margen real por tipo de acción (para ti, en el panel de Supabase) ============

create view public.v_margin_by_kind
with (security_invoker = true)
as
select
  j.kind,
  count(*)                                                     as trabajos,
  count(*) filter (where j.status = 'failed')                  as fallidos,
  sum(case when j.refunded then 0 else j.cost end)             as creditos_cobrados,
  round(sum(case when j.refunded then 0 else j.cost end)
        * public.setting('credit_value_eur'), 2)               as ingreso_eur,
  round(sum(coalesce(j.provider_cost_usd, 0)), 4)              as coste_usd,
  round(avg(j.provider_cost_usd) filter (where j.status = 'done'), 5) as coste_medio_usd,
  p.est_cost_usd                                               as coste_estimado_usd
from public.jobs j
join public.pricing p on p.kind = j.kind
group by j.kind, p.est_cost_usd;

-- ============ Permisos ============

alter table public.pricing  enable row level security;
alter table public.settings enable row level security;

create policy "precios visibles" on public.pricing
  for select to anon, authenticated using (true);
-- settings: sin políticas = solo el servidor.

revoke all on public.v_margin_by_kind from public, anon, authenticated;

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.setting(text)',
    'public.grant_welcome(uuid)',
    'public.reserve_job(uuid, text, jsonb)',
    'public.finish_job(uuid, numeric, integer, integer, numeric)',
    'public.fail_job(uuid, text, numeric, boolean)',
    'public.expire_stuck_jobs()',
    'public.grant_ad_reward(uuid, text, text)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end;
$$;

-- Las funciones antiguas de la primera migración ya no se usan desde el servidor.
revoke all on function public.spend_credits(uuid, integer, text, text) from service_role;

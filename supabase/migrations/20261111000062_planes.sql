-- Planes mensuales (noviembre de 2026): tuercas cada mes por suscripcion de Google Play.
--
--   Taller      4,99 EUR/mes  o 49,99 EUR/ano  -> 250 tuercas al mes (3 juegos)
--   Taller Pro 12,99 EUR/mes  o 129,99 EUR/ano -> 800 tuercas al mes (10 juegos)
--
-- En Play Console: dos suscripciones, plan_taller y plan_pro, cada una con dos planes base,
-- "mensual" y "anual" (los precios se ponen alli). El servidor solo mira la suscripcion: las
-- tuercas van cada mes tambien en el plan anual.
--
-- Rentable siempre: un juego cuesta ~0,35 $ de verdad. Taller deja ~4,24 EUR (Google se queda un
-- 15 %) y gasta como mucho 1,05 $; Pro deja ~11 EUR y gasta como mucho 3,50 $. Las tuercas que no
-- se gastan se acumulan como mucho hasta 2 meses del plan (nadie guarda cientos sin usar).
--
-- Ventajas: los dos planes ponen tu juego primero en la Lanzadera (premium_hasta) y sus juegos
-- se fabrican antes que los de la cola gratis. Pro: +20 % de tuercas en cada pack que compres.

alter table public.store_products drop constraint if exists store_products_kind_check;
alter table public.store_products add constraint store_products_kind_check check (kind in ('tuercas', 'premium', 'plan'));
alter table public.store_products add column if not exists plan text;
alter table public.store_products add column if not exists tuercas_mes integer not null default 0;

insert into public.store_products (product_id, kind, credits, plan, tuercas_mes, note) values
  ('plan_taller', 'plan', 0, 'taller', 250, 'Suscripcion Taller: 250 tuercas al mes (4,99 EUR/mes o 49,99 EUR/ano)'),
  ('plan_pro', 'plan', 0, 'pro', 800, 'Suscripcion Taller Pro: 800 tuercas al mes y +20 % en packs (12,99 EUR/mes o 129,99 EUR/ano)')
on conflict (product_id) do update set kind = excluded.kind, plan = excluded.plan, tuercas_mes = excluded.tuercas_mes, note = excluded.note;
-- El premium antiguo (solo la Lanzadera) lo sustituyen los planes, que ya la incluyen.
update public.store_products set active = false where product_id = 'premium_mensual';

alter table public.profiles add column if not exists plan text check (plan in ('taller', 'pro'));
alter table public.profiles add column if not exists plan_hasta timestamptz;
alter table public.profiles add column if not exists plan_entrega timestamptz;

insert into public.settings (key, value, note) values
  ('plan_tope_meses', 2, 'Las tuercas del plan se acumulan como mucho hasta N meses del plan'),
  ('plan_pro_bonus_packs', 20, 'Taller Pro: % extra de tuercas en cada pack comprado')
on conflict (key) do nothing;

create or replace function public.plan_rango(p_plan text)
returns integer
language sql
immutable
as $$
  select case p_plan when 'pro' then 2 when 'taller' then 1 else 0 end
$$;

-- 1 - Entrega mensual. La llama pg_cron cada hora (y grant_purchase al contratar). Idempotente:
--     cada perfil cobra una vez por mes; si el reloj se paro varios meses, solo una.
create or replace function public.plan_entregar(p_user uuid default null)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_mes integer;
  v_dar integer;
  n integer := 0;
begin
  for r in select p.id, p.plan, p.credits, p.plan_entrega from public.profiles p
            where p.plan is not null and p.plan_hasta > now() and coalesce(p.plan_entrega, now()) <= now()
              and (p_user is null or p.id = p_user)
            for update skip locked
  loop
    select tuercas_mes into v_mes from public.store_products where kind = 'plan' and plan = r.plan order by tuercas_mes desc limit 1;
    v_dar := greatest(0, least(coalesce(v_mes, 0), coalesce(v_mes, 0) * public.setting('plan_tope_meses')::integer - r.credits));
    if v_dar > 0 then
      update public.profiles set credits = credits + v_dar where id = r.id;
      insert into public.credit_ledger (user_id, amount, reason, ref) values (r.id, v_dar, 'plan', r.plan);
    end if;
    update public.profiles
       set plan_entrega = greatest(coalesce(r.plan_entrega, now()) + interval '1 month', now() + interval '1 day')
     where id = r.id;
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- 2 - Conceder compras: igual que antes para tuercas (con el +20 % de Pro) y premium; nuevo: planes.
create or replace function public.grant_purchase(p_user uuid, p_product text, p_token text, p_order text, p_expires timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_p public.store_products%rowtype;
  v_ya public.purchases%rowtype;
  v_perfil public.profiles%rowtype;
  v_saldo integer;
  v_dar integer;
begin
  select * into v_p from public.store_products where product_id = p_product;
  if not found then raise exception 'unknown_product'; end if;
  select * into v_perfil from public.profiles where id = p_user for update;
  if not found then raise exception 'unknown_user'; end if;
  select * into v_ya from public.purchases where purchase_token = p_token for update;
  if found then
    if v_ya.user_id <> p_user then raise exception 'token_other_user'; end if;
    if v_ya.estado = 'reembolsada' then raise exception 'refunded'; end if;
    -- Renovacion de una suscripcion (mismo token, nueva fecha).
    if v_p.kind in ('premium', 'plan') and p_expires is not null and (v_ya.expires_at is null or p_expires > v_ya.expires_at) then
      update public.purchases set expires_at = p_expires, updated_at = now() where purchase_token = p_token;
      update public.profiles set premium_hasta = greatest(coalesce(premium_hasta, now()), p_expires) where id = p_user;
      if v_p.kind = 'plan' and v_perfil.plan = v_p.plan then
        update public.profiles set plan_hasta = greatest(coalesce(plan_hasta, now()), p_expires) where id = p_user;
        perform public.plan_entregar(p_user);
      end if;
      return jsonb_build_object('resultado', 'renovada', 'premium_hasta', p_expires);
    end if;
    select credits into v_saldo from public.profiles where id = p_user;
    return jsonb_build_object('resultado', 'ya_concedida', 'credits', v_saldo);
  end if;

  if v_p.kind = 'tuercas' then
    v_dar := v_p.credits;
    if v_perfil.plan = 'pro' and v_perfil.plan_hasta > now() then
      v_dar := v_dar + (v_p.credits * public.setting('plan_pro_bonus_packs') / 100)::integer;
    end if;
    insert into public.purchases (purchase_token, order_id, user_id, product_id, kind, credits, expires_at)
    values (p_token, p_order, p_user, p_product, v_p.kind, v_dar, p_expires);
    update public.profiles set credits = credits + v_dar where id = p_user returning credits into v_saldo;
    insert into public.credit_ledger (user_id, amount, reason, ref) values (p_user, v_dar, 'purchase', p_order);
    return jsonb_build_object('resultado', 'concedida', 'credits', v_saldo, 'sumadas', v_dar);
  end if;

  if p_expires is null or p_expires < now() then raise exception 'subscription_expired'; end if;
  insert into public.purchases (purchase_token, order_id, user_id, product_id, kind, credits, expires_at)
  values (p_token, p_order, p_user, p_product, v_p.kind, 0, p_expires);
  update public.profiles set premium_hasta = greatest(coalesce(premium_hasta, now()), p_expires) where id = p_user;
  if v_p.kind = 'plan' then
    -- Plan nuevo o mejor que el que tenia: entrega ya. Mismo plan o cambio a uno menor: sigue el
    -- calendario (Google prorratea el cambio; nadie cobra dos veces el mismo mes).
    if v_perfil.plan is null or coalesce(v_perfil.plan_hasta, now()) <= now() or public.plan_rango(v_p.plan) > public.plan_rango(v_perfil.plan) then
      update public.profiles set plan = v_p.plan, plan_hasta = p_expires, plan_entrega = now() where id = p_user;
      perform public.plan_entregar(p_user);
    else
      update public.profiles set plan = v_p.plan, plan_hasta = p_expires where id = p_user;
    end if;
    -- Cuenta como compra (sin tuercas: las da la entrega): paga la invitacion y sale en el embudo.
    insert into public.credit_ledger (user_id, amount, reason, ref) values (p_user, 0, 'purchase', p_order);
    select credits into v_saldo from public.profiles where id = p_user;
    return jsonb_build_object('resultado', 'concedida', 'plan', v_p.plan, 'plan_hasta', p_expires, 'credits', v_saldo);
  end if;
  return jsonb_build_object('resultado', 'concedida', 'premium_hasta', p_expires);
end;
$$;

-- 3 - Reembolso o anulacion: tambien quita el plan y la ultima entrega del mes.
create or replace function public.revoke_purchase(p_token text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.purchases%rowtype;
  v_mes integer;
begin
  select * into v from public.purchases where purchase_token = p_token for update;
  if not found then return 'unknown'; end if;
  if v.estado = 'reembolsada' then return 'already'; end if;
  update public.purchases set estado = 'reembolsada', updated_at = now() where purchase_token = p_token;
  if v.kind = 'tuercas' then
    update public.profiles set credits = greatest(credits - v.credits, 0) where id = v.user_id;
    insert into public.credit_ledger (user_id, amount, reason, ref) values (v.user_id, -v.credits, 'refund_purchase', v.order_id);
  elsif v.kind = 'plan' then
    select tuercas_mes into v_mes from public.store_products where product_id = v.product_id;
    update public.profiles set credits = greatest(credits - coalesce(v_mes, 0), 0), plan = null, plan_hasta = now(),
           premium_hasta = least(premium_hasta, now())
     where id = v.user_id;
    insert into public.credit_ledger (user_id, amount, reason, ref) values (v.user_id, -coalesce(v_mes, 0), 'refund_purchase', v.order_id);
  else
    update public.profiles set premium_hasta = now() where id = v.user_id and premium_hasta > now();
  end if;
  return 'revoked';
end;
$$;

-- 4 - Lo que ve la app.
create or replace function public.mi_tienda()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object('credits', p.credits, 'premium_hasta', p.premium_hasta,
    'premium', coalesce(p.premium_hasta > now(), false),
    'plan', case when p.plan_hasta > now() then p.plan end, 'plan_hasta', case when p.plan_hasta > now() then p.plan_hasta end,
    'plan_entrega', case when p.plan_hasta > now() then p.plan_entrega end,
    'tope_meses', public.setting('plan_tope_meses'), 'bonus_pro', public.setting('plan_pro_bonus_packs'))
    from public.profiles p where p.id = auth.uid()
$$;

-- 5 - La fabrica coge antes los juegos de quien tiene plan (despues de las vistas previas, que son cortas).
create or replace function public.claim_game_job(p_worker text)
returns table (job_id uuid, user_id uuid, kind text, project_id uuid, idea text, detail jsonb, project_files jsonb, project_version integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if public.fabrica_pausada() then return; end if;
  select j.id into v_id from public.jobs j
    left join public.profiles pr on pr.id = j.user_id
   where j.kind in ('game', 'game_change', 'game_restore', 'game_marketing', 'game_publish', 'game_mod', 'game_preview')
     and j.status = 'queued'
   order by (j.kind = 'game_preview') desc, coalesce(pr.plan_hasta > now(), false) desc, j.created_at
   for update of j skip locked
   limit 1;
  if v_id is null then return; end if;
  update public.jobs set status = 'running', started_at = now(), worker = left(p_worker, 80) where id = v_id;
  return query
    select j.id, j.user_id, j.kind, j.project_id, j.detail ->> 'idea', j.detail, p.files, p.version
      from public.jobs j left join public.projects p on p.id = j.project_id
     where j.id = v_id;
end;
$$;

revoke all on function public.plan_entregar(uuid) from public, anon, authenticated;
grant execute on function public.plan_entregar(uuid) to service_role;
revoke all on function public.grant_purchase(uuid, text, text, text, timestamptz) from public, anon, authenticated;
grant execute on function public.grant_purchase(uuid, text, text, text, timestamptz) to service_role;
revoke all on function public.revoke_purchase(text) from public, anon, authenticated;
grant execute on function public.revoke_purchase(text) to service_role;
revoke all on function public.mi_tienda() from public, anon;
grant execute on function public.mi_tienda() to authenticated;
revoke all on function public.claim_game_job(text) from public, anon, authenticated;
grant execute on function public.claim_game_job(text) to service_role;

-- Cada hora, si la base de datos tiene pg_cron (Supabase lo trae; en las pruebas locales no).
do $$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule(jobid) from cron.job where jobname = 'orq-planes';
  perform cron.schedule('orq-planes', '17 * * * *', 'select public.plan_entregar()');
exception when others then
  raise notice 'sin pg_cron: las entregas del plan solo corren a mano (%).', sqlerrm;
end;
$$;

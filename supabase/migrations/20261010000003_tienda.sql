-- Orquestador: compras dentro de la app (Google Play Billing).
--
--   app -> compra en Google Play (sin conceder nada) -> funcion play-purchase con el purchaseToken
--   play-purchase -> pregunta a la API de Google si la compra es real y esta pagada
--               -> grant_purchase (aqui): concede UNA sola vez por token, y despues la funcion
--                  consume (tuercas) o reconoce (suscripcion) la compra en Google.
--   reloj -> revisa reembolsos (voidedpurchases) y llama a revoke_purchase.
-- Los precios los pone Google Play (Play Console); aqui solo que da cada producto.

create table if not exists public.store_products (
  product_id text primary key,
  kind       text not null check (kind in ('tuercas', 'premium')),
  credits    integer not null default 0,
  active     boolean not null default true,
  note       text
);

insert into public.store_products (product_id, kind, credits, note) values
  ('tuercas_300', 'tuercas', 300, 'Pack pequeno (en Play Console: 2,99 EUR)'),
  ('tuercas_1100', 'tuercas', 1100, 'Pack mediano (9,99 EUR)'),
  ('tuercas_3600', 'tuercas', 3600, 'Pack grande (29,99 EUR)'),
  ('premium_mensual', 'premium', 0, 'Suscripcion: la Lanzadera te pone primero (4,99 EUR/mes)')
on conflict (product_id) do nothing;

alter table public.store_products enable row level security;
create policy "ver productos" on public.store_products for select to anon, authenticated using (active);

create table if not exists public.purchases (
  purchase_token text primary key,
  order_id       text,
  user_id        uuid not null references public.profiles (id) on delete cascade,
  product_id     text not null references public.store_products (product_id),
  kind           text not null,
  credits        integer not null default 0,
  expires_at     timestamptz,
  estado         text not null default 'concedida' check (estado in ('concedida', 'reembolsada')),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists purchases_user_idx on public.purchases (user_id, created_at desc);
create index if not exists purchases_order_idx on public.purchases (order_id);
alter table public.purchases enable row level security;
create policy "ver mis compras" on public.purchases for select to authenticated using (user_id = auth.uid());

-- Concede una compra ya verificada con Google. Idempotente: el mismo token nunca da dos veces.
-- Para suscripciones, cada renovacion actualiza la caducidad (mismo token, nueva fecha).
create or replace function public.grant_purchase(p_user uuid, p_product text, p_token text, p_order text, p_expires timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_p public.store_products%rowtype;
  v_ya public.purchases%rowtype;
  v_saldo integer;
begin
  select * into v_p from public.store_products where product_id = p_product;
  if not found then raise exception 'unknown_product'; end if;
  perform 1 from public.profiles where id = p_user for update;
  if not found then raise exception 'unknown_user'; end if;
  select * into v_ya from public.purchases where purchase_token = p_token for update;
  if found then
    if v_ya.user_id <> p_user then raise exception 'token_other_user'; end if;
    if v_ya.estado = 'reembolsada' then raise exception 'refunded'; end if;
    if v_p.kind = 'premium' and p_expires is not null and (v_ya.expires_at is null or p_expires > v_ya.expires_at) then
      update public.purchases set expires_at = p_expires, updated_at = now() where purchase_token = p_token;
      update public.profiles set premium_hasta = greatest(coalesce(premium_hasta, now()), p_expires) where id = p_user;
      return jsonb_build_object('resultado', 'renovada', 'premium_hasta', p_expires);
    end if;
    select credits into v_saldo from public.profiles where id = p_user;
    return jsonb_build_object('resultado', 'ya_concedida', 'credits', v_saldo);
  end if;
  insert into public.purchases (purchase_token, order_id, user_id, product_id, kind, credits, expires_at)
  values (p_token, p_order, p_user, p_product, v_p.kind, v_p.credits, p_expires);
  if v_p.kind = 'tuercas' then
    update public.profiles set credits = credits + v_p.credits where id = p_user returning credits into v_saldo;
    insert into public.credit_ledger (user_id, amount, reason, ref) values (p_user, v_p.credits, 'purchase', p_order);
    return jsonb_build_object('resultado', 'concedida', 'credits', v_saldo, 'sumadas', v_p.credits);
  end if;
  if p_expires is null or p_expires < now() then raise exception 'subscription_expired'; end if;
  update public.profiles set premium_hasta = greatest(coalesce(premium_hasta, now()), p_expires) where id = p_user;
  return jsonb_build_object('resultado', 'concedida', 'premium_hasta', p_expires);
end;
$$;

-- Reembolso o anulacion (Google voidedpurchases): se quita lo concedido (las tuercas, sin bajar de 0).
create or replace function public.revoke_purchase(p_token text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.purchases%rowtype;
begin
  select * into v from public.purchases where purchase_token = p_token for update;
  if not found then return 'unknown'; end if;
  if v.estado = 'reembolsada' then return 'already'; end if;
  update public.purchases set estado = 'reembolsada', updated_at = now() where purchase_token = p_token;
  if v.kind = 'tuercas' then
    update public.profiles set credits = greatest(credits - v.credits, 0) where id = v.user_id;
    insert into public.credit_ledger (user_id, amount, reason, ref) values (v.user_id, -v.credits, 'refund_purchase', v.order_id);
  else
    update public.profiles set premium_hasta = now() where id = v.user_id and premium_hasta > now();
  end if;
  return 'revoked';
end;
$$;

-- Lo que ve la app: mi saldo y si soy premium.
create or replace function public.mi_tienda()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object('credits', p.credits, 'premium_hasta', p.premium_hasta,
    'premium', coalesce(p.premium_hasta > now(), false))
    from public.profiles p where p.id = auth.uid()
$$;

revoke all on function public.grant_purchase(uuid, text, text, text, timestamptz) from public, anon, authenticated;
grant execute on function public.grant_purchase(uuid, text, text, text, timestamptz) to service_role;
revoke all on function public.revoke_purchase(text) from public, anon, authenticated;
grant execute on function public.revoke_purchase(text) to service_role;
revoke all on function public.mi_tienda() from public, anon;
grant execute on function public.mi_tienda() to authenticated;

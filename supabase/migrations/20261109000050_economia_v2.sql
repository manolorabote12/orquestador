-- Economia v2 (estudio de noviembre de 2026): que cada tuerca deje margen y que nada queme dinero.
--
-- 1 - Precios con margen (coste real medido: ~0,26 EUR por juego con fallos incluidos):
--     juego 80 tuercas (antes 60), videos 35 (antes 20), cambio programado 50 (antes 30),
--     volver a una version 3 (antes gratis: rehace bots, APK y capturas), plan del taller 25 al dia.
-- 2 - Regalos que se pagan solos: bienvenida 40 (medio juego), anuncio 3 tuercas (Google paga
--     ~0,009 EUR; 3 tuercas cuestan ~0,010 EUR), hasta 6 anuncios al dia.
-- 3 - La bienvenida solo una vez por correo de verdad: Gmail ignora los puntos y lo que va tras '+',
--     asi que pepe+1@gmail.com y p.e.p.e@gmail.com ya no son cuentas nuevas con regalo.
-- 4 - Invitaciones: se pagan cuando el invitado COMPRA algo (antes, con su primer juego, que podia
--     ser el de bienvenida: crear cuentas en cadena salia gratis y cada una costaba un juego).
-- 5 - job_progress dice si el trabajo sigue vivo: si el servidor lo dio por caducado, la fabrica
--     deja de pedir GPU. Y un juego tiene 45 minutos (antes 30) antes de darse por perdido.

-- ------------------------------------------------------------------ 1 y 2: precios y regalos

update public.pricing set credits = 80, est_cost_usd = 0.35 where kind = 'game';
update public.pricing set credits = 35, est_cost_usd = 0.15 where kind = 'game_marketing';
update public.pricing set credits = 50, est_cost_usd = 0.25 where kind = 'game_mod';
update public.pricing set credits = 3, est_cost_usd = 0.03 where kind = 'game_restore';
update public.pricing set max_per_day = 25 where kind = 'plan';
update public.pricing set est_cost_usd = 0.12 where kind = 'charla_pack';

update public.settings set value = 40, note = 'Tuercas al verificar la cuenta (medio juego: el resto con anuncios o el pack pequeno)'
 where key = 'welcome_credits';
update public.settings set value = 3, note = 'Tuercas por anuncio bonificado (Google paga ~0,009 EUR; 3 tuercas cuestan ~0,010 EUR)'
 where key = 'reward_ad_credits';
update public.settings set value = 6 where key = 'reward_ads_per_day';
update public.settings set value = 0.00585, note = 'Valor neto de 1 tuerca en el pack grande (29,99 EUR / 3600, sin IVA ni comision)'
 where key = 'credit_value_eur';
update public.settings set value = 45 where key = 'game_timeout_minutes';

-- ------------------------------------------------------------------ 3: un regalo por correo real

create or replace function public.correo_normal(p_correo text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when p_correo is null or position('@' in p_correo) = 0 then lower(trim(coalesce(p_correo, '')))
    else (
      with partes as (
        select split_part(lower(trim(p_correo)), '@', 1) as local, split_part(lower(trim(p_correo)), '@', 2) as dominio
      ), sin_etiqueta as (
        select split_part(local, '+', 1) as local, dominio from partes
      )
      select case when dominio in ('gmail.com', 'googlemail.com')
                  then replace(local, '.', '') || '@gmail.com'
                  else local || '@' || dominio end
        from sin_etiqueta
    )
  end
$$;

create or replace function public.grant_welcome(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_amount integer := public.setting('welcome_credits')::integer;
  v_norm   text;
begin
  select public.correo_normal(email) into v_norm from auth.users where id = p_user;
  -- Otra cuenta con el mismo correo de verdad ya cobro la bienvenida: esta no cobra.
  if v_norm is not null and v_norm <> '' and exists (
       select 1 from public.profiles p join auth.users u on u.id = p.id
        where p.id <> p_user and p.welcome_granted and public.correo_normal(u.email) = v_norm) then
    v_amount := 0;
  end if;
  update public.profiles
     set welcome_granted = true,
         credits = credits + v_amount
   where id = p_user and not welcome_granted;
  if found and v_amount > 0 then
    insert into public.credit_ledger (user_id, amount, reason) values (p_user, v_amount, 'signup');
  end if;
end;
$$;

revoke all on function public.grant_welcome(uuid) from public, anon, authenticated;
revoke all on function public.correo_normal(text) from public, anon;

-- ------------------------------------------------------------------ 4: invitaciones al comprar

drop trigger if exists pagar_invitacion on public.projects;

create or replace function public.pagar_invitacion_compra()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_de uuid;
  v_n integer := public.setting('invitacion_tuercas')::integer;
begin
  if new.reason <> 'purchase' then return new; end if;
  select invitado_por into v_de from public.profiles
   where id = new.user_id and not invitacion_pagada and invitado_por is not null for update;
  if v_de is null then return new; end if;
  update public.profiles set invitacion_pagada = true where id = new.user_id;
  if (select count(*) from public.credit_ledger where user_id = v_de and reason = 'invite' and created_at > now() - interval '30 days')
     >= public.setting('invitaciones_mes') then
    return new;
  end if;
  update public.profiles set credits = credits + v_n where id in (v_de, new.user_id);
  insert into public.credit_ledger (user_id, amount, reason, ref) values
    (v_de, v_n, 'invite', new.user_id::text), (new.user_id, v_n, 'invite', v_de::text);
  return new;
end;
$$;

drop trigger if exists pagar_invitacion_compra on public.credit_ledger;
create trigger pagar_invitacion_compra after insert on public.credit_ledger
  for each row when (new.reason = 'purchase')
  execute function public.pagar_invitacion_compra();

revoke all on function public.pagar_invitacion_compra() from public, anon, authenticated;

-- El invitado puede usar el codigo hasta su primera compra (antes: hasta su primer juego).
create or replace function public.usar_invitacion(p_codigo text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_de uuid;
  v_perfil record;
begin
  if v_user is null then raise exception 'unknown_user'; end if;
  select id into v_de from public.profiles where codigo_invitacion = upper(trim(coalesce(p_codigo, '')));
  if v_de is null then raise exception 'bad_code'; end if;
  if v_de = v_user then raise exception 'own_code'; end if;
  select invitado_por, created_at into v_perfil from public.profiles where id = v_user for update;
  if v_perfil.invitado_por is not null then raise exception 'already_invited'; end if;
  if v_perfil.created_at < now() - interval '7 days'
     or exists (select 1 from public.credit_ledger where user_id = v_user and reason = 'purchase') then
    raise exception 'too_late';
  end if;
  if exists (select 1 from public.profiles where id = v_de and invitado_por = v_user) then raise exception 'own_code'; end if;
  -- Nadie se invita a si mismo con otra cuenta del mismo correo.
  if exists (select 1 from auth.users a, auth.users b where a.id = v_user and b.id = v_de
              and public.correo_normal(a.email) = public.correo_normal(b.email)) then
    raise exception 'own_code';
  end if;
  update public.profiles set invitado_por = v_de where id = v_user;
  return 'ok';
end;
$$;

revoke all on function public.usar_invitacion(text) from public, anon;
grant execute on function public.usar_invitacion(text) to authenticated;

-- ------------------------------------------------------------------ 5: progreso que avisa

drop function if exists public.job_progress(uuid, jsonb);
create function public.job_progress(p_job uuid, p_event jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.jobs
     set progress = (
       select coalesce(jsonb_agg(e order by n), '[]'::jsonb)
         from (select e, n from jsonb_array_elements(progress || jsonb_build_array(p_event)) with ordinality as t(e, n)
               order by n desc limit 60) last
     )
   where id = p_job and status = 'running';
  -- false: el trabajo ya no esta en marcha (caducado o cerrado). La fabrica deja de gastar.
  return found;
end;
$$;

revoke all on function public.job_progress(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.job_progress(uuid, jsonb) to service_role;

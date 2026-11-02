\set ON_ERROR_STOP 1
do $$
declare
  u uuid; o uuid; j jsonb; c0 int; t text;
begin
  insert into auth.users (email, email_confirmed_at) values ('compra@x.com', now()) returning id into u;
  insert into auth.users (email, email_confirmed_at) values ('otra@x.com', now()) returning id into o;
  select credits into c0 from public.profiles where id = u;
  j := public.grant_purchase(u, 'tuercas_1100', 'tok-1', 'GPA.1');
  assert j ->> 'resultado' = 'concedida' and (j ->> 'credits')::int = c0 + 1100, j::text;
  j := public.grant_purchase(u, 'tuercas_1100', 'tok-1', 'GPA.1');
  assert j ->> 'resultado' = 'ya_concedida' and (j ->> 'credits')::int = c0 + 1100, 'el mismo token no da dos veces: ' || j::text;
  begin perform public.grant_purchase(o, 'tuercas_1100', 'tok-1', 'GPA.1'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%token_other_user%', sqlerrm; end;
  begin perform public.grant_purchase(u, 'no_existe', 'tok-2', 'GPA.2'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%unknown_product%', sqlerrm; end;
  assert (select count(*) from public.credit_ledger where user_id = u and reason = 'purchase') = 1;
  -- Suscripcion premium: concede, renueva con el mismo token y la Lanzadera la ve.
  j := public.grant_purchase(u, 'premium_mensual', 'sub-1', 'GPA.3', now() + interval '30 days');
  assert public.lz_premium(u), 'premium activo';
  j := public.grant_purchase(u, 'premium_mensual', 'sub-1', 'GPA.3..0', now() + interval '60 days');
  assert j ->> 'resultado' = 'renovada', j::text;
  assert (select premium_hasta from public.profiles where id = u) > now() + interval '59 days';
  begin perform public.grant_purchase(o, 'premium_mensual', 'sub-9', 'GPA.9', now() - interval '1 day'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%subscription_expired%', sqlerrm; end;
  -- Reembolso: se quitan las tuercas (sin bajar de 0) y el premium.
  update public.profiles set credits = 500 where id = u;
  t := public.revoke_purchase('tok-1');
  assert t = 'revoked' and (select credits from public.profiles where id = u) = 0, 'reembolso no deja saldo negativo';
  assert public.revoke_purchase('tok-1') = 'already';
  begin perform public.grant_purchase(u, 'tuercas_1100', 'tok-1', 'GPA.1'); raise exception 'debia fallar';
  exception when others then assert sqlerrm like '%refunded%', sqlerrm; end;
  perform public.revoke_purchase('sub-1');
  assert not public.lz_premium(u), 'reembolso del premium';
  perform set_config('request.jwt.claim.sub', u::text, false);
  j := public.mi_tienda();
  assert (j ->> 'premium')::boolean = false and (j ->> 'credits')::int = 0, j::text;
  raise notice 'TIENDA OK';
end $$;
select 'TIENDA OK';

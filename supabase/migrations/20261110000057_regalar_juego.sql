-- Juego regalado por el dueno (10 de noviembre de 2026): un juego completo para la cuenta de un correo,
-- sin cobrar tuercas. Lo lanza el workflow «Canario» (accion regalar). Sirve para probar un juego de
-- verdad con tu propia cuenta: sale en «Mis juegos» como cualquier otro.

create or replace function public.regalar_juego(p_correo text, p_idea text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_job uuid;
begin
  if char_length(coalesce(p_idea, '')) not between 15 and 700 then raise exception 'bad_idea'; end if;
  select id into v_user from auth.users
   where public.correo_normal(email) = public.correo_normal(p_correo)
   order by created_at limit 1;
  if v_user is null then raise exception 'sin_cuenta'; end if;
  insert into public.jobs (user_id, kind, cost, est_cost_usd, status, detail)
  values (v_user, 'game', 0, 0.35, 'queued', jsonb_build_object('idea', p_idea, 'regalo', true))
  returning id into v_job;
  return v_job;
end;
$$;

revoke all on function public.regalar_juego(text, text) from public, anon, authenticated;
grant execute on function public.regalar_juego(text, text) to service_role;

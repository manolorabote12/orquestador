-- Orquestador: borrar la cuenta (Google Play lo exige dentro de la app y desde la web).
--
--   app (su sesion) -> delete-account (funcion) -> preparar_borrado: comprueba, guarda lo que la
--   ley obliga a conservar SIN datos personales y devuelve que archivos borrar; la funcion borra
--   los archivos y despues el usuario (auth.admin.deleteUser) y todo cae en cascada.
--
-- Se conserva (anonimo, 6 anos, obligacion fiscal/fraude): pedidos de Google Play (id de pedido,
-- producto, fecha, estado) con una huella del usuario que no se puede revertir.
-- No se borra: lo publicado en la cuenta de Google Play / App Store del usuario (es suyo, no nuestro)
-- ni la suscripcion de Google Play (se cancela en Play: lo avisa la app antes de borrar).

create table if not exists public.borrados (
  id          bigserial primary key,
  huella      text not null unique,
  pedidos     jsonb not null default '[]'::jsonb,
  juegos      integer not null default 0,
  created_at  timestamptz not null default now()
);
alter table public.borrados enable row level security;
-- Sin politicas: solo el servidor.

create or replace function public.preparar_borrado(p_user uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_juegos   uuid[];
  v_tele     uuid[];
  v_pedidos  jsonb;
  v_premium  boolean;
begin
  if not exists (select 1 from public.profiles where id = p_user) then raise exception 'user_not_found'; end if;
  -- 1 - Nada a medias: un trabajo en marcha escribiria en una cuenta que ya no existe.
  if exists (select 1 from public.jobs where user_id = p_user and status in ('queued', 'running')) then
    raise exception 'job_running';
  end if;
  select coalesce(array_agg(id), '{}'), coalesce(array_agg(telemetria_id) filter (where telemetria_id is not null), '{}')
    into v_juegos, v_tele from public.projects where user_id = p_user;
  select coalesce(jsonb_agg(jsonb_build_object('pedido', order_id, 'producto', product_id, 'estado', estado,
    'fecha', created_at) order by created_at), '[]'::jsonb)
    into v_pedidos from public.purchases where user_id = p_user;
  v_premium := exists (select 1 from public.purchases where user_id = p_user and kind = 'premium'
    and estado = 'concedida' and expires_at > now());
  -- 2 - Lo que se guarda por ley, sin el usuario: huella irreversible.
  insert into public.borrados (huella, pedidos, juegos)
  values (encode(sha256(convert_to(p_user::text || 'orq-borrado', 'UTF8')), 'hex'), v_pedidos, coalesce(array_length(v_juegos, 1), 0))
  on conflict (huella) do update set pedidos = excluded.pedidos, juegos = excluded.juegos, created_at = now();
  -- 3 - Las partidas anonimas de sus juegos ya no sirven a nadie.
  delete from public.partidas where juego = any (v_tele);
  return jsonb_build_object('juegos', to_jsonb(v_juegos), 'premium_activo', v_premium);
end;
$$;
revoke all on function public.preparar_borrado(uuid) from public, anon, authenticated;
grant execute on function public.preparar_borrado(uuid) to service_role;

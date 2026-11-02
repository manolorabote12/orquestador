-- Compras dentro de los juegos (Google Play Billing). El juego compra en Google Play y manda el
-- token a la funcion juego-compra, que lo comprueba con Google (cuenta de servicio de Orquestador,
-- invitada a la consola del autor) y lo anota aqui UNA vez. Solo la funcion (service_role) escribe.
-- Productos fijos del kit, con su precio base en euros (Google lo convierte a cada pais):
--   monedas_500 (0,99), monedas_3000 (4,99), pase_temporada (3,99) -> se consumen
--   sin_anuncios (2,99) -> se compra una vez
-- El autor ve sus ventas en la app (juego_ingresos, en la migracion del panel de ingresos).

create table if not exists public.juego_compras (
  id         bigserial primary key,
  juego      uuid not null,
  producto   text not null,
  token      text not null unique,
  orden      text,
  sesion     text not null,
  created_at timestamptz not null default now()
);
create index if not exists juego_compras_idx on public.juego_compras (juego, created_at);
alter table public.juego_compras enable row level security;

create or replace function public.iap_precio(p_producto text)
returns numeric
language sql
immutable
as $$
  select case p_producto when 'monedas_500' then 0.99 when 'monedas_3000' then 4.99
    when 'pase_temporada' then 3.99 when 'sin_anuncios' then 2.99 else 0 end::numeric;
$$;

-- La llama la funcion juego-compra tras verificar con Google. Devuelve true si es nueva.
create or replace function public.juego_compra_anotar(p_juego uuid, p_sesion text, p_producto text, p_token text, p_orden text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  if public.iap_precio(p_producto) = 0 then raise exception 'unknown_product'; end if;
  insert into public.juego_compras (juego, producto, token, orden, sesion)
  values (p_juego, p_producto, p_token, p_orden, p_sesion) on conflict (token) do nothing;
  return found;
end;
$$;

create or replace function public._juego_compras_borrar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.juego_compras where juego = old.telemetria_id;
  return old;
end;
$$;
drop trigger if exists juego_compras_borrar on public.projects;
create trigger juego_compras_borrar after delete on public.projects for each row execute function public._juego_compras_borrar();

revoke all on function public.juego_compra_anotar(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.juego_compra_anotar(uuid, text, text, text, text) to service_role;
revoke all on function public._juego_compras_borrar() from public, anon, authenticated;

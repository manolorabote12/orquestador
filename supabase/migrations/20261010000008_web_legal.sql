-- Orquestador: la web publica (GitHub Pages, carpeta web/) pinta las politicas de privacidad de los
-- juegos desde un JSON del almacen 'legal'. Supabase Storage sirve los .html como texto plano (salvo
-- plan Pro con dominio propio), asi que la pagina buena es web/privacidad.html?j=<juego>.

update storage.buckets set allowed_mime_types = array['text/html', 'application/json'] where id = 'legal';

-- Cuenta de revision de Google Play / Apple: entra con un correo y un codigo fijos (secreto
-- ORQ_REVISOR = "correo:codigo" en las funciones). Freno: 20 fallos por hora y se bloquea.
create table if not exists public.revisor_intentos (
  id bigserial primary key,
  created_at timestamptz not null default now()
);
alter table public.revisor_intentos enable row level security;

create or replace function public.revisor_fallo()
returns integer
language sql
security definer
set search_path = public
as $$
  with nuevo as (insert into public.revisor_intentos default values returning 1)
  select (select count(*)::int from public.revisor_intentos where created_at > now() - interval '1 hour') + 1;
$$;

create or replace function public.revisor_bloqueado()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select count(*) >= 20 from public.revisor_intentos where created_at > now() - interval '1 hour';
$$;
revoke all on function public.revisor_fallo() from public, anon, authenticated;
revoke all on function public.revisor_bloqueado() from public, anon, authenticated;
grant execute on function public.revisor_fallo() to service_role;
grant execute on function public.revisor_bloqueado() to service_role;

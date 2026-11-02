-- Premio real (juegos para negocios): el autor ofrece un cupon de verdad a quien supera un nivel
-- ("10 % en tu proxima compra", codigo PAN10). Lo cambia cuando quiera desde la app, sin publicar
-- version nueva; el juego lo lee al arrancar.
--   autor (app)  -> premio_guardar (vacio = quitarlo) y premio_autor (con cuantos lo han ganado).
--   juego (anon) -> premio_actual y premio_ganado (anota al jugador y le da su codigo personal:
--                   el del negocio + 4 letras propias, asi la tienda distingue a cada uno).
create table if not exists public.juego_premios (
  juego      uuid primary key,
  project    uuid not null references public.projects (id) on delete cascade,
  texto      text not null check (char_length(texto) between 3 and 80),
  codigo     text not null check (codigo ~ '^[A-Z0-9]{3,16}$'),
  tras_nivel integer not null default 3 check (tras_nivel between 1 and 50),
  donde      text not null default '' check (char_length(donde) <= 80),
  web        text not null default '' check (web = '' or web ~ '^https://[^ <>"]{4,200}$'),
  caduca     date,
  updated_at timestamptz not null default now()
);
alter table public.juego_premios enable row level security;

create table if not exists public.juego_premios_ganados (
  juego      uuid not null,
  sesion     text not null,
  created_at timestamptz not null default now(),
  primary key (juego, sesion)
);
alter table public.juego_premios_ganados enable row level security;

-- Textos que ven los jugadores: el mismo filtro que los titulos de eventos, hasta 80 letras.
create or replace function public._premio_texto_ok(p text)
returns boolean
language plpgsql
immutable
as $$
declare
  t text;
  i integer := 1;
begin
  if p is null or char_length(btrim(p)) < 3 or char_length(btrim(p)) > 80 or p ~ '[<>{}\\]' then return false; end if;
  t := regexp_replace(p, '[^[:alnum:]]', '', 'g');
  if char_length(t) < 3 then return false; end if;
  loop
    if not public.alias_valido(substr(t, i, 14)) and char_length(substr(t, i, 14)) >= 3 then return false; end if;
    exit when i + 14 > char_length(t);
    i := i + 3;
  end loop;
  return true;
end;
$$;

create or replace function public.premio_guardar(p_project uuid, p_texto text, p_codigo text, p_tras_nivel integer,
  p_donde text default '', p_web text default '', p_caduca date default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_juego uuid;
begin
  if auth.uid() is null then raise exception 'unknown_user'; end if;
  select telemetria_id into v_juego from public.projects where id = p_project and user_id = auth.uid();
  if not found or v_juego is null then raise exception 'project_not_found'; end if;
  if coalesce(btrim(p_texto), '') = '' then
    delete from public.juego_premios where juego = v_juego;
    return null;
  end if;
  p_codigo := upper(btrim(coalesce(p_codigo, '')));
  p_donde := btrim(coalesce(p_donde, '')); p_web := btrim(coalesce(p_web, ''));
  if not public._premio_texto_ok(p_texto) then raise exception 'bad_text'; end if;
  if p_donde <> '' and not public._premio_texto_ok(p_donde) then raise exception 'bad_place'; end if;
  if p_codigo !~ '^[A-Z0-9]{3,16}$' then raise exception 'bad_code'; end if;
  if p_tras_nivel is null or p_tras_nivel < 1 or p_tras_nivel > 50 then raise exception 'bad_level'; end if;
  if p_web <> '' and p_web !~ '^https://[^ <>"]{4,200}$' then raise exception 'bad_web'; end if;
  if p_caduca is not null and p_caduca < current_date then raise exception 'bad_date'; end if;
  insert into public.juego_premios (juego, project, texto, codigo, tras_nivel, donde, web, caduca, updated_at)
  values (v_juego, p_project, btrim(p_texto), p_codigo, p_tras_nivel, p_donde, p_web, p_caduca, now())
  on conflict (juego) do update set texto = excluded.texto, codigo = excluded.codigo, tras_nivel = excluded.tras_nivel,
    donde = excluded.donde, web = excluded.web, caduca = excluded.caduca, updated_at = now();
  return public.premio_autor(p_project);
end;
$$;

create or replace function public.premio_autor(p_project uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_juego uuid;
  r public.juego_premios%rowtype;
begin
  select telemetria_id into v_juego from public.projects where id = p_project and user_id = auth.uid();
  if not found then raise exception 'project_not_found'; end if;
  select * into r from public.juego_premios where juego = v_juego;
  if not found then return null; end if;
  return jsonb_build_object('texto', r.texto, 'codigo', r.codigo, 'tras_nivel', r.tras_nivel, 'donde', r.donde, 'web', r.web,
    'caduca', r.caduca, 'ganados', (select count(*) from public.juego_premios_ganados g where g.juego = v_juego));
end;
$$;

create or replace function public._premio_codigo(p_codigo text, p_juego uuid, p_sesion text)
returns text
language sql
immutable
as $$
  select p_codigo || '-' || upper(substr(md5(p_juego::text || p_sesion), 1, 4));
$$;

create or replace function public.premio_actual(p_juego uuid, p_sesion text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r public.juego_premios%rowtype;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  select * into r from public.juego_premios where juego = p_juego and (caduca is null or caduca >= current_date);
  if not found then return null; end if;
  return jsonb_build_object('texto', r.texto, 'tras_nivel', r.tras_nivel, 'donde', r.donde, 'web', r.web, 'caduca', r.caduca,
    'ganado', exists (select 1 from public.juego_premios_ganados g where g.juego = p_juego and g.sesion = p_sesion));
end;
$$;

create or replace function public.premio_ganado(p_juego uuid, p_sesion text, p_nivel integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.juego_premios%rowtype;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  select * into r from public.juego_premios where juego = p_juego and (caduca is null or caduca >= current_date);
  if not found then return null; end if;
  -- Hay que haber llegado al nivel del premio.
  if p_nivel is null or p_nivel < r.tras_nivel then raise exception 'not_yet'; end if;
  insert into public.juego_premios_ganados (juego, sesion) values (p_juego, p_sesion) on conflict do nothing;
  return jsonb_build_object('texto', r.texto, 'codigo', public._premio_codigo(r.codigo, p_juego, p_sesion),
    'donde', r.donde, 'web', r.web, 'caduca', r.caduca);
end;
$$;

revoke all on function public.premio_guardar(uuid, text, text, integer, text, text, date) from public, anon;
grant execute on function public.premio_guardar(uuid, text, text, integer, text, text, date) to authenticated;
revoke all on function public.premio_autor(uuid) from public, anon;
grant execute on function public.premio_autor(uuid) to authenticated;
grant execute on function public.premio_actual(uuid, text) to anon, authenticated;
grant execute on function public.premio_ganado(uuid, text, integer) to anon, authenticated;

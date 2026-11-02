-- Guardado en la nube sin cuentas: "Pasar a otro movil".
--   juego (anon) -> nube_guardar: sube la partida (como mucho 256 KB) y devuelve un codigo de 8
--                   letras (fijo para ese movil) y un PIN de 6 cifras (nuevo cada vez: el anterior
--                   deja de valer).
--                -> nube_restaurar: con codigo + PIN baja la partida en el otro movil.
-- Contra adivinar el PIN: 5 fallos por codigo y hora. Las partidas sin tocar en 180 dias se
-- borran (nube_limpiar, lo llama el trabajador).

create table if not exists public.nube_partidas (
  codigo     text primary key,
  juego      uuid not null,
  sesion     text not null,
  pin_hash   text not null,
  datos      jsonb not null,
  updated_at timestamptz not null default now(),
  unique (juego, sesion)
);
alter table public.nube_partidas enable row level security;

create table if not exists public.nube_fallos (
  codigo     text not null,
  created_at timestamptz not null default now()
);
create index if not exists nube_fallos_idx on public.nube_fallos (codigo, created_at);
alter table public.nube_fallos enable row level security;

insert into public.settings (key, value, note) values
  ('nube_fallos_hora', 5, 'PIN equivocados por codigo y hora antes de bloquear')
on conflict (key) do nothing;

create or replace function public._nube_hash(p_codigo text, p_pin text)
returns text
language sql
immutable
as $$ select md5('orq-nube:' || p_codigo || ':' || p_pin); $$;

create or replace function public.nube_guardar(p_juego uuid, p_sesion text, p_datos jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_codigo text;
  v_pin text := lpad((floor(random() * 1000000))::integer::text, 6, '0');
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  if not exists (select 1 from public.projects where telemetria_id = p_juego) then raise exception 'unknown_game'; end if;
  if p_datos is null or jsonb_typeof(p_datos) <> 'object' or octet_length(p_datos::text) > 262144 then raise exception 'bad_data'; end if;
  select codigo into v_codigo from public.nube_partidas where juego = p_juego and sesion = p_sesion;
  if v_codigo is null then
    loop
      -- 8 letras sin las que se confunden.
      v_codigo := translate(upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)), '01', 'KM');
      exit when not exists (select 1 from public.nube_partidas where codigo = v_codigo);
    end loop;
    insert into public.nube_partidas (codigo, juego, sesion, pin_hash, datos)
    values (v_codigo, p_juego, p_sesion, public._nube_hash(v_codigo, v_pin), p_datos);
  else
    update public.nube_partidas set datos = p_datos, pin_hash = public._nube_hash(v_codigo, v_pin), updated_at = now()
     where codigo = v_codigo;
  end if;
  return jsonb_build_object('codigo', v_codigo, 'pin', v_pin);
end;
$$;

create or replace function public.nube_restaurar(p_juego uuid, p_codigo text, p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_codigo text := upper(regexp_replace(coalesce(p_codigo, ''), '[^A-Za-z0-9]', '', 'g'));
  n public.nube_partidas%rowtype;
begin
  if (select count(*) from public.nube_fallos where codigo = v_codigo and created_at > now() - interval '1 hour')
     >= public.setting('nube_fallos_hora') then
    raise exception 'rate_limited';
  end if;
  select * into n from public.nube_partidas where codigo = v_codigo and juego = p_juego;
  if not found or n.pin_hash <> public._nube_hash(v_codigo, coalesce(p_pin, '')) then
    insert into public.nube_fallos (codigo) values (v_codigo);
    -- El fallo se guarda aunque la funcion devuelva vacio (no se lanza error para no deshacerlo).
    return null;
  end if;
  return n.datos;
end;
$$;

create or replace function public.nube_limpiar()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v integer;
begin
  delete from public.nube_partidas where updated_at < now() - interval '180 days';
  get diagnostics v = row_count;
  delete from public.nube_fallos where created_at < now() - interval '1 day';
  return v;
end;
$$;

create or replace function public._nube_borrar_juego()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.nube_partidas where juego = old.telemetria_id;
  return old;
end;
$$;
drop trigger if exists nube_borrar_juego on public.projects;
create trigger nube_borrar_juego after delete on public.projects for each row execute function public._nube_borrar_juego();

revoke all on function public._nube_hash(text, text) from public, anon, authenticated;
revoke all on function public.nube_limpiar() from public, anon, authenticated;
grant execute on function public.nube_limpiar() to service_role;
revoke all on function public._nube_borrar_juego() from public, anon, authenticated;
grant execute on function public.nube_guardar(uuid, text, jsonb) to anon, authenticated;
grant execute on function public.nube_restaurar(uuid, text, text) to anon, authenticated;

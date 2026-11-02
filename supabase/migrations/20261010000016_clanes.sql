-- Clanes de la liga de aldeas: grupos de hasta 20 jugadores que suman sus trofeos.
--   juego (anon) -> clan_crear (nombre limpio, codigo de 6 letras para invitar), clan_unir (con
--                   el codigo), clan_salir, clan_info (tu clan, sus miembros y su puesto) y
--                   clan_top (ranking de clanes). Hay que estar en la liga (haber subido la aldea).
-- Sin chat: solo nombres limpios (los mismos filtros que los apodos) y codigos.

create table if not exists public.liga_clanes (
  id         bigserial primary key,
  juego      uuid not null,
  nombre     text not null,
  codigo     text not null unique,
  created_at timestamptz not null default now(),
  unique (juego, nombre)
);
alter table public.liga_clanes enable row level security;
alter table public.liga_aldeas add column if not exists clan bigint references public.liga_clanes (id) on delete set null;
create index if not exists liga_aldeas_clan_idx on public.liga_aldeas (clan);

insert into public.settings (key, value, note) values
  ('clan_max_miembros', 20, 'Jugadores como mucho en un clan de la liga')
on conflict (key) do nothing;

create or replace function public._clan_yo(p_juego uuid, p_sesion text)
returns public.liga_aldeas
language plpgsql
security definer
set search_path = public
as $$
declare
  yo public.liga_aldeas%rowtype;
begin
  select * into yo from public.liga_aldeas where juego = p_juego and sesion = p_sesion;
  if not found then raise exception 'not_published'; end if;
  return yo;
end;
$$;

create or replace function public.clan_crear(p_juego uuid, p_sesion text, p_nombre text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  yo public.liga_aldeas%rowtype := public._clan_yo(p_juego, p_sesion);
  v_codigo text;
  v_id bigint;
begin
  if not public.alias_valido(p_nombre) then raise exception 'bad_name'; end if;
  if yo.clan is not null then raise exception 'already_in_clan'; end if;
  if exists (select 1 from public.liga_clanes where juego = p_juego and lower(nombre) = lower(p_nombre)) then
    raise exception 'name_taken';
  end if;
  loop
    -- 6 letras sin las que se confunden (0/O, 1/I/L).
    v_codigo := translate(upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6)), '01', 'KM');
    exit when not exists (select 1 from public.liga_clanes where codigo = v_codigo);
  end loop;
  insert into public.liga_clanes (juego, nombre, codigo) values (p_juego, p_nombre, v_codigo) returning id into v_id;
  update public.liga_aldeas set clan = v_id where id = yo.id;
  return jsonb_build_object('codigo', v_codigo, 'nombre', p_nombre);
end;
$$;

create or replace function public.clan_unir(p_juego uuid, p_sesion text, p_codigo text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  yo public.liga_aldeas%rowtype := public._clan_yo(p_juego, p_sesion);
  c public.liga_clanes%rowtype;
begin
  select * into c from public.liga_clanes where codigo = upper(trim(coalesce(p_codigo, ''))) and juego = p_juego for update;
  if not found then raise exception 'unknown_clan'; end if;
  if yo.clan = c.id then return jsonb_build_object('nombre', c.nombre, 'codigo', c.codigo); end if;
  if (select count(*) from public.liga_aldeas where clan = c.id) >= public.setting('clan_max_miembros') then
    raise exception 'clan_full';
  end if;
  update public.liga_aldeas set clan = c.id where id = yo.id;
  -- Un clan que se queda vacio desaparece.
  if yo.clan is not null and not exists (select 1 from public.liga_aldeas where clan = yo.clan) then
    delete from public.liga_clanes where id = yo.clan;
  end if;
  return jsonb_build_object('nombre', c.nombre, 'codigo', c.codigo);
end;
$$;

create or replace function public.clan_salir(p_juego uuid, p_sesion text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  yo public.liga_aldeas%rowtype := public._clan_yo(p_juego, p_sesion);
begin
  if yo.clan is null then return; end if;
  update public.liga_aldeas set clan = null where id = yo.id;
  if not exists (select 1 from public.liga_aldeas where clan = yo.clan) then
    delete from public.liga_clanes where id = yo.clan;
  end if;
end;
$$;

create or replace function public.clan_info(p_juego uuid, p_sesion text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  yo public.liga_aldeas%rowtype;
  c public.liga_clanes%rowtype;
  v_puesto integer;
begin
  select * into yo from public.liga_aldeas where juego = p_juego and sesion = p_sesion;
  if not found or yo.clan is null then return null; end if;
  select * into c from public.liga_clanes where id = yo.clan;
  select r.posicion into v_puesto from (
    select k.id, (rank() over (order by sum(a.trofeos) desc))::integer as posicion
      from public.liga_clanes k join public.liga_aldeas a on a.clan = k.id
     where k.juego = p_juego group by k.id) r where r.id = c.id;
  return jsonb_build_object('nombre', c.nombre, 'codigo', c.codigo, 'puesto', v_puesto,
    'trofeos', (select coalesce(sum(trofeos), 0) from public.liga_aldeas where clan = c.id and not oculta),
    'miembros', (select coalesce(jsonb_agg(jsonb_build_object('alias', a.alias, 'trofeos', a.trofeos, 'tuyo', a.id = yo.id)
                   order by a.trofeos desc), '[]'::jsonb) from public.liga_aldeas a where a.clan = c.id and not a.oculta));
end;
$$;

create or replace function public.clan_top(p_juego uuid, p_limite integer default 10)
returns table (posicion integer, nombre text, trofeos integer, miembros integer)
language sql
stable
security definer
set search_path = public
as $$
  select (rank() over (order by sum(a.trofeos) desc))::integer, k.nombre, sum(a.trofeos)::integer, count(*)::integer
    from public.liga_clanes k join public.liga_aldeas a on a.clan = k.id and not a.oculta
   where k.juego = p_juego
   group by k.id, k.nombre
   order by sum(a.trofeos) desc
   limit least(greatest(p_limite, 1), 50);
$$;

-- Borrar el juego borra sus clanes.
create or replace function public._clanes_borrar_juego()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.liga_clanes where juego = old.telemetria_id;
  return old;
end;
$$;
drop trigger if exists clanes_borrar_juego on public.projects;
create trigger clanes_borrar_juego after delete on public.projects for each row execute function public._clanes_borrar_juego();

revoke all on function public._clan_yo(uuid, text) from public, anon, authenticated;
revoke all on function public._clanes_borrar_juego() from public, anon, authenticated;
grant execute on function public.clan_crear(uuid, text, text) to anon, authenticated;
grant execute on function public.clan_unir(uuid, text, text) to anon, authenticated;
grant execute on function public.clan_salir(uuid, text) to anon, authenticated;
grant execute on function public.clan_info(uuid, text) to anon, authenticated;
grant execute on function public.clan_top(uuid, integer) to anon, authenticated;

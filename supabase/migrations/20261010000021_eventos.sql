-- Eventos en directo de cada juego (los programa el autor desde la app; el juego los ve sin
-- publicar version nueva):
--   'monedas_x2' -> las monedas para la tienda valen doble mientras dura.
--   'regalo'     -> cada jugador recoge una vez un regalo de monedas (1..500).
--   autor (app)  -> evento_crear (dura de 1 h a 14 dias, empieza en los proximos 60 dias, sin
--                   solaparse, como mucho 5 pendientes), eventos_autor y evento_borrar.
--   juego (anon) -> evento_actual (el que esta en marcha, o null) y evento_regalo_cobrar.
-- El titulo lo escribe el autor (lo ven sus jugadores): corto y con el mismo filtro que los apodos.

create table if not exists public.juego_eventos (
  id         bigserial primary key,
  juego      uuid not null,
  tipo       text not null check (tipo in ('monedas_x2', 'regalo')),
  titulo     text not null check (char_length(titulo) between 3 and 40),
  regalo     integer not null default 0 check (regalo between 0 and 500),
  inicio     timestamptz not null,
  fin        timestamptz not null,
  created_at timestamptz not null default now(),
  check (fin > inicio)
);
create index if not exists juego_eventos_idx on public.juego_eventos (juego, inicio);
alter table public.juego_eventos enable row level security;

create table if not exists public.juego_eventos_cobros (
  evento     bigint not null references public.juego_eventos (id) on delete cascade,
  sesion     text not null,
  created_at timestamptz not null default now(),
  primary key (evento, sesion)
);
alter table public.juego_eventos_cobros enable row level security;

-- Titulo valido: el filtro de palabrotas de los apodos aplicado a cada palabra.
create or replace function public._evento_titulo_ok(p text)
returns boolean
language plpgsql
immutable
as $$
declare
  t text;
  i integer := 1;
begin
  if p is null or char_length(btrim(p)) < 3 or char_length(btrim(p)) > 40 or p ~ '[<>{}\\]' then return false; end if;
  -- Solo letras y numeros, en ventanas de 14 que se solapan (asi ninguna palabrota queda partida).
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

create or replace function public.evento_crear(p_project uuid, p_tipo text, p_titulo text,
  p_inicio timestamptz, p_fin timestamptz, p_regalo integer default 0)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_juego uuid;
  v_id bigint;
begin
  select pr.telemetria_id into v_juego from public.projects pr where pr.id = p_project and pr.user_id = auth.uid();
  if not found then raise exception 'project_not_found'; end if;
  if p_tipo not in ('monedas_x2', 'regalo') then raise exception 'bad_type'; end if;
  if not public._evento_titulo_ok(p_titulo) then raise exception 'bad_title'; end if;
  if p_inicio is null or p_fin is null or p_fin - p_inicio < interval '1 hour' or p_fin - p_inicio > interval '14 days'
     or p_inicio > now() + interval '60 days' or p_fin <= now() then
    raise exception 'bad_dates';
  end if;
  if p_tipo = 'regalo' and (p_regalo is null or p_regalo < 1 or p_regalo > 500) then raise exception 'bad_gift'; end if;
  if exists (select 1 from public.juego_eventos where juego = v_juego and inicio < p_fin and fin > p_inicio) then
    raise exception 'overlap';
  end if;
  if (select count(*) from public.juego_eventos where juego = v_juego and fin > now()) >= 5 then
    raise exception 'too_many';
  end if;
  insert into public.juego_eventos (juego, tipo, titulo, regalo, inicio, fin)
  values (v_juego, p_tipo, btrim(p_titulo), case when p_tipo = 'regalo' then p_regalo else 0 end, greatest(p_inicio, now()), p_fin)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.eventos_autor(p_project uuid)
returns table (id bigint, tipo text, titulo text, regalo integer, inicio timestamptz, fin timestamptz, cobros integer)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_juego uuid;
begin
  select pr.telemetria_id into v_juego from public.projects pr where pr.id = p_project and pr.user_id = auth.uid();
  if not found then raise exception 'project_not_found'; end if;
  return query select e.id, e.tipo, e.titulo, e.regalo, e.inicio, e.fin,
      (select count(*)::integer from public.juego_eventos_cobros c where c.evento = e.id)
    from public.juego_eventos e where e.juego = v_juego and e.fin > now() - interval '30 days'
   order by e.inicio desc limit 20;
end;
$$;

create or replace function public.evento_borrar(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.juego_eventos e using public.projects p
   where e.id = p_id and p.telemetria_id = e.juego and p.user_id = auth.uid();
  if not found then raise exception 'not_found'; end if;
end;
$$;

create or replace function public.evento_actual(p_juego uuid, p_sesion text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  e public.juego_eventos%rowtype;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  select * into e from public.juego_eventos where juego = p_juego and inicio <= now() and fin > now() order by inicio limit 1;
  if not found then return null; end if;
  return jsonb_build_object('id', e.id, 'tipo', e.tipo, 'titulo', e.titulo, 'regalo', e.regalo,
    'segundos', greatest(extract(epoch from e.fin - now())::integer, 0),
    'cobrado', exists (select 1 from public.juego_eventos_cobros c where c.evento = e.id and c.sesion = p_sesion));
end;
$$;

create or replace function public.evento_regalo_cobrar(p_juego uuid, p_sesion text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  e public.juego_eventos%rowtype;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  select * into e from public.juego_eventos
   where juego = p_juego and tipo = 'regalo' and inicio <= now() and fin > now() order by inicio limit 1;
  if not found then return 0; end if;
  insert into public.juego_eventos_cobros (evento, sesion) values (e.id, p_sesion) on conflict do nothing;
  if not found then return 0; end if;
  return e.regalo;
end;
$$;

create or replace function public._eventos_borrar_juego()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.juego_eventos where juego = old.telemetria_id;
  return old;
end;
$$;
drop trigger if exists eventos_borrar_juego on public.projects;
create trigger eventos_borrar_juego after delete on public.projects for each row execute function public._eventos_borrar_juego();

revoke all on function public._eventos_borrar_juego() from public, anon, authenticated;
revoke all on function public.evento_crear(uuid, text, text, timestamptz, timestamptz, integer) from public, anon;
revoke all on function public.eventos_autor(uuid) from public, anon;
revoke all on function public.evento_borrar(bigint) from public, anon;
grant execute on function public.evento_crear(uuid, text, text, timestamptz, timestamptz, integer) to authenticated;
grant execute on function public.eventos_autor(uuid) to authenticated;
grant execute on function public.evento_borrar(bigint) to authenticated;
grant execute on function public.evento_actual(uuid, text) to anon, authenticated;
grant execute on function public.evento_regalo_cobrar(uuid, text) to anon, authenticated;

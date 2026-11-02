-- Liga de aldeas (juegos del genero aldea): asaltos asincronos a las aldeas de otros jugadores.
--   juego (anon) -> liga_publicar: sube tu aldea (mapa validado) con tu apodo.
--                -> liga_rival: el servidor elige una aldea con trofeos parecidos y abre un asalto.
--                -> liga_resultado: cierra ESE asalto (una vez, en 15 minutos) y reparte trofeos.
--                -> liga_top / liga_defensas: ranking del juego y quien te ha atacado.
--   autor (sesion) -> liga_autor: ranking con todo para moderar; liga_ocultar: quita una aldea.
-- Del jugador solo se guarda el apodo que elige y el numero aleatorio de su dispositivo.

create table if not exists public.liga_aldeas (
  id         bigserial primary key,
  juego      uuid not null,
  sesion     text not null,
  alias      text not null,
  mapa       text[] not null,
  ayto       integer not null check (ayto between 1 and 3),
  trofeos    integer not null default 0 check (trofeos >= 0),
  victorias  integer not null default 0,
  defensas   integer not null default 0,
  oculta     boolean not null default false,
  updated_at timestamptz not null default now(),
  unique (juego, sesion)
);
create index if not exists liga_aldeas_trofeos_idx on public.liga_aldeas (juego, trofeos desc) where not oculta;
alter table public.liga_aldeas enable row level security;

create table if not exists public.liga_ataques (
  id          bigserial primary key,
  juego       uuid not null,
  atacante    bigint not null references public.liga_aldeas (id) on delete cascade,
  defensor    bigint not null references public.liga_aldeas (id) on delete cascade,
  estrellas   integer check (estrellas between 0 and 3),
  destruccion integer check (destruccion between 0 and 100),
  delta       integer,
  created_at  timestamptz not null default now(),
  cerrado_at  timestamptz
);
create index if not exists liga_ataques_def_idx on public.liga_ataques (defensor, created_at desc);
create index if not exists liga_ataques_atq_idx on public.liga_ataques (atacante, created_at desc);
alter table public.liga_ataques enable row level security;
-- Sin politicas: solo por las funciones de abajo.

insert into public.settings (key, value, note) values
  ('liga_ataques_hora', 30, 'Asaltos de liga que un dispositivo puede abrir por hora'),
  ('liga_publicar_hora', 20, 'Veces que un dispositivo puede subir su aldea por hora')
on conflict (key) do nothing;

-- Mapa de aldea valido: 14 a 24 filas iguales de 14 a 24 letras conocidas y un solo ayuntamiento.
create or replace function public.liga_mapa_valido(p_mapa text[])
returns boolean
language plpgsql
immutable
as $$
declare
  f text;
  w integer;
  n integer;
  todo text := '';
begin
  n := coalesce(array_length(p_mapa, 1), 0);
  if n < 14 or n > 24 then return false; end if;
  w := char_length(p_mapa[1]);
  if w < 14 or w > 24 then return false; end if;
  foreach f in array p_mapa loop
    if f is null or char_length(f) <> w or f !~ '^[.#HGEMKCAO]+$' then return false; end if;
    todo := todo || f;
  end loop;
  return char_length(todo) - char_length(replace(todo, 'H', '')) = 1;
end;
$$;

create or replace function public._liga_juego_ok(p_juego uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.projects where telemetria_id = p_juego and coalesce(spec ->> 'genero', '') = 'aldea');
$$;

create or replace function public.liga_publicar(p_juego uuid, p_sesion text, p_alias text, p_mapa text[], p_ayto integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.liga_aldeas%rowtype;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  if not public.alias_valido(p_alias) then raise exception 'bad_alias'; end if;
  if not public.liga_mapa_valido(p_mapa) then raise exception 'bad_map'; end if;
  if p_ayto is null or p_ayto < 1 or p_ayto > 3 then raise exception 'bad_map'; end if;
  if not public._liga_juego_ok(p_juego) then raise exception 'unknown_game'; end if;
  select * into r from public.liga_aldeas where juego = p_juego and sesion = p_sesion;
  -- Subidas muy seguidas: se queda la anterior (sin error; el juego la vuelve a subir mas tarde).
  if found and r.updated_at > now() - interval '1 hour' * (1.0 / greatest(public.setting('liga_publicar_hora'), 1)) then
    return jsonb_build_object('trofeos', r.trofeos, 'victorias', r.victorias, 'defensas', r.defensas, 'igual', true);
  end if;
  insert into public.liga_aldeas (juego, sesion, alias, mapa, ayto)
  values (p_juego, p_sesion, p_alias, p_mapa, p_ayto)
  on conflict (juego, sesion) do update set alias = excluded.alias, mapa = excluded.mapa, ayto = excluded.ayto, updated_at = now()
  returning * into r;
  return jsonb_build_object('trofeos', r.trofeos, 'victorias', r.victorias, 'defensas', r.defensas);
end;
$$;

create or replace function public.liga_rival(p_juego uuid, p_sesion text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  yo  public.liga_aldeas%rowtype;
  riv public.liga_aldeas%rowtype;
  v_ataque bigint;
begin
  select * into yo from public.liga_aldeas where juego = p_juego and sesion = p_sesion and not oculta;
  if not found then raise exception 'not_published'; end if;
  if (select count(*) from public.liga_ataques where atacante = yo.id and created_at > now() - interval '1 hour')
     >= public.setting('liga_ataques_hora') then
    raise exception 'rate_limited';
  end if;
  -- Trofeos parecidos (cada vez mas margen) y nadie que hayas atacado hace menos de 10 minutos.
  for margen in 1..4 loop
    select a.* into riv from public.liga_aldeas a
     where a.juego = p_juego and a.id <> yo.id and not a.oculta
       and abs(a.trofeos - yo.trofeos) <= margen * 150
       and not exists (select 1 from public.liga_ataques t where t.atacante = yo.id and t.defensor = a.id
                         and t.created_at > now() - interval '10 minutes')
     order by random() limit 1;
    exit when found;
  end loop;
  if riv.id is null then
    select a.* into riv from public.liga_aldeas a
     where a.juego = p_juego and a.id <> yo.id and not a.oculta order by random() limit 1;
  end if;
  if riv.id is null then raise exception 'no_rivals'; end if;
  insert into public.liga_ataques (juego, atacante, defensor) values (p_juego, yo.id, riv.id) returning id into v_ataque;
  return jsonb_build_object('ataque', v_ataque, 'alias', riv.alias, 'mapa', to_jsonb(riv.mapa), 'ayto', riv.ayto, 'trofeos', riv.trofeos);
end;
$$;

-- Trofeos: ganar (1+ estrellas) da 10 + 6 por estrella y quita 4 por estrella al defensor;
-- perder quita 6 al atacante y da 4 al defensor. Nunca por debajo de 0.
create or replace function public.liga_resultado(p_juego uuid, p_sesion text, p_ataque bigint, p_estrellas integer, p_destruccion integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  yo public.liga_aldeas%rowtype;
  t  public.liga_ataques%rowtype;
  v_mio integer;
  v_suyo integer;
begin
  select * into yo from public.liga_aldeas where juego = p_juego and sesion = p_sesion;
  if not found then raise exception 'not_published'; end if;
  select * into t from public.liga_ataques where id = p_ataque and atacante = yo.id for update;
  if not found then raise exception 'unknown_attack'; end if;
  if t.cerrado_at is not null then raise exception 'already_closed'; end if;
  if t.created_at < now() - interval '15 minutes' then raise exception 'expired'; end if;
  if p_estrellas is null or p_estrellas < 0 or p_estrellas > 3 or p_destruccion is null or p_destruccion < 0 or p_destruccion > 100 then
    raise exception 'bad_result';
  end if;
  -- Coherencia minima: 3 estrellas es el 100 %; 1 o mas sin llegar al 50 % solo si cayo el ayuntamiento.
  if (p_estrellas = 3 and p_destruccion < 100) or (p_estrellas = 0 and p_destruccion >= 50) then raise exception 'bad_result'; end if;
  if p_estrellas >= 1 then
    v_mio := 10 + 6 * p_estrellas;
    v_suyo := -4 * p_estrellas;
  else
    v_mio := -6;
    v_suyo := 4;
  end if;
  update public.liga_aldeas set trofeos = greatest(trofeos + v_mio, 0), victorias = victorias + (case when p_estrellas >= 1 then 1 else 0 end)
   where id = yo.id returning trofeos into v_mio;
  update public.liga_aldeas set trofeos = greatest(trofeos + v_suyo, 0), defensas = defensas + (case when p_estrellas = 0 then 1 else 0 end)
   where id = t.defensor;
  update public.liga_ataques set estrellas = p_estrellas, destruccion = p_destruccion, delta = v_suyo, cerrado_at = now() where id = t.id;
  return jsonb_build_object('trofeos', v_mio);
end;
$$;

create or replace function public.liga_top(p_juego uuid, p_sesion text, p_limite integer default 20)
returns table (posicion integer, alias text, trofeos integer, ayto integer, tuyo boolean)
language sql
stable
security definer
set search_path = public
as $$
  with r as (
    select a.alias, a.trofeos, a.ayto, a.sesion = p_sesion as tuyo,
           (rank() over (order by a.trofeos desc))::integer as posicion
      from public.liga_aldeas a where a.juego = p_juego and not a.oculta
  )
  select posicion, alias, trofeos, ayto, tuyo from r
   where posicion <= least(greatest(p_limite, 1), 50) or tuyo
   order by posicion limit 51;
$$;

create or replace function public.liga_defensas(p_juego uuid, p_sesion text)
returns table (alias text, estrellas integer, destruccion integer, trofeos integer, fecha timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select atq.alias, t.estrellas, t.destruccion, t.delta, t.cerrado_at
    from public.liga_ataques t
    join public.liga_aldeas yo on yo.id = t.defensor and yo.juego = p_juego and yo.sesion = p_sesion
    join public.liga_aldeas atq on atq.id = t.atacante
   where t.cerrado_at is not null
   order by t.cerrado_at desc limit 10;
$$;

-- Autor del juego: ve la liga entera y oculta aldeas con apodos feos.
create or replace function public.liga_autor(p_project uuid)
returns table (id bigint, alias text, trofeos integer, ayto integer, oculta boolean)
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
  return query select a.id, a.alias, a.trofeos, a.ayto, a.oculta from public.liga_aldeas a
    where a.juego = v_juego order by a.trofeos desc limit 100;
end;
$$;

create or replace function public.liga_ocultar(p_id bigint, p_oculta boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.liga_aldeas a set oculta = p_oculta
    from public.projects p
   where a.id = p_id and p.telemetria_id = a.juego and p.user_id = auth.uid();
  if not found then raise exception 'not_found'; end if;
end;
$$;

-- Borrar el juego borra su liga.
create or replace function public._liga_borrar_juego()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.liga_aldeas where juego = old.telemetria_id;
  return old;
end;
$$;
drop trigger if exists liga_borrar_juego on public.projects;
create trigger liga_borrar_juego after delete on public.projects for each row execute function public._liga_borrar_juego();

revoke all on function public._liga_juego_ok(uuid) from public, anon, authenticated;
revoke all on function public._liga_borrar_juego() from public, anon, authenticated;
grant execute on function public.liga_publicar(uuid, text, text, text[], integer) to anon, authenticated;
grant execute on function public.liga_rival(uuid, text) to anon, authenticated;
grant execute on function public.liga_resultado(uuid, text, bigint, integer, integer) to anon, authenticated;
grant execute on function public.liga_top(uuid, text, integer) to anon, authenticated;
grant execute on function public.liga_defensas(uuid, text) to anon, authenticated;
revoke all on function public.liga_autor(uuid) from public, anon;
revoke all on function public.liga_ocultar(bigint, boolean) from public, anon;
grant execute on function public.liga_autor(uuid) to authenticated;
grant execute on function public.liga_ocultar(bigint, boolean) to authenticated;

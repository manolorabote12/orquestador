-- Duelos asincronos para CUALQUIER juego (21 nov, El Farero y los juegos de los usuarios): cada jugador
-- sube su equipo de defensa (JSON libre que entiende su juego, max 8 KB) y los demas lo atacan con la
-- IA manejandolo en su propio movil. Como las arenas de AFK Arena o Raid: nadie tiene que estar conectado.
--   juego (anon) -> duelo_publicar: sube/actualiza tu equipo con tu apodo y su poder.
--                -> duelo_rivales: hasta 3 rivales de puntos parecidos (con su equipo).
--                -> duelo_empezar: abre un combate contra uno de ellos (limite por hora).
--                -> duelo_resultado: cierra ESE combate (una vez, en 20 minutos) y reparte puntos.
--                -> duelo_top / duelo_registro: clasificacion y quien te ha atacado.
--   autor (sesion) -> duelo_ocultar: quita un equipo de su juego.
-- Del jugador solo se guarda el apodo que elige y el numero aleatorio de su dispositivo. Coste: dos
-- tablas pequenas; todo el combate se calcula en el movil.

create table if not exists public.duelo_equipos (
  id         bigserial primary key,
  juego      uuid not null,
  sesion     text not null,
  alias      text not null,
  equipo     jsonb not null,
  poder      integer not null default 0 check (poder >= 0),
  puntos     integer not null default 1000 check (puntos >= 0),
  victorias  integer not null default 0,
  derrotas   integer not null default 0,
  oculta     boolean not null default false,
  updated_at timestamptz not null default now(),
  unique (juego, sesion)
);
create index if not exists duelo_equipos_puntos_idx on public.duelo_equipos (juego, puntos desc) where not oculta;
alter table public.duelo_equipos enable row level security;

create table if not exists public.duelo_combates (
  id         bigserial primary key,
  juego      uuid not null,
  atacante   bigint not null references public.duelo_equipos (id) on delete cascade,
  defensor   bigint not null references public.duelo_equipos (id) on delete cascade,
  gano       boolean,
  delta      integer,
  created_at timestamptz not null default now(),
  cerrado_at timestamptz
);
create index if not exists duelo_combates_def_idx on public.duelo_combates (defensor, created_at desc);
create index if not exists duelo_combates_atq_idx on public.duelo_combates (atacante, created_at desc);
alter table public.duelo_combates enable row level security;
-- Sin politicas: solo por las funciones de abajo.

insert into public.settings (key, value, note) values
  ('duelo_combates_hora', 40, 'Duelos que un dispositivo puede empezar por hora'),
  ('duelo_publicar_hora', 30, 'Veces que un dispositivo puede subir su equipo por hora')
on conflict (key) do nothing;

create or replace function public._duelo_juego_ok(p_juego uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.projects where telemetria_id = p_juego);
$$;

create or replace function public._duelo_alias_ok(p_alias text)
returns boolean language sql immutable as $$
  select p_alias ~ '^[[:alnum:]_ ]{3,14}$'
     and lower(p_alias) !~ '(puta|puto|mierda|polla|cabron|maricon|nazi|hitler|fuck|shit|bitch|nigg|cunt|admin|orquestador)';
$$;

create or replace function public.duelo_publicar(p_juego uuid, p_sesion text, p_alias text, p_equipo jsonb, p_poder integer)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.duelo_equipos%rowtype;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  if not public._duelo_juego_ok(p_juego) then raise exception 'unknown_game'; end if;
  if not public._duelo_alias_ok(coalesce(p_alias, '')) then raise exception 'bad_alias'; end if;
  if p_equipo is null or jsonb_typeof(p_equipo) not in ('object', 'array') or length(p_equipo::text) > 8192 then raise exception 'bad_team'; end if;
  if p_poder is null or p_poder < 0 or p_poder > 100000000 then raise exception 'bad_team'; end if;
  insert into public.duelo_equipos (juego, sesion, alias, equipo, poder)
    values (p_juego, p_sesion, p_alias, p_equipo, p_poder)
  on conflict (juego, sesion) do update set alias = excluded.alias, equipo = excluded.equipo, poder = excluded.poder, updated_at = now()
  returning * into r;
  return jsonb_build_object('puntos', r.puntos, 'victorias', r.victorias, 'derrotas', r.derrotas);
end;
$$;

create or replace function public.duelo_rivales(p_juego uuid, p_sesion text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare yo public.duelo_equipos%rowtype; v jsonb;
begin
  select * into yo from public.duelo_equipos where juego = p_juego and sesion = p_sesion and not oculta;
  if not found then raise exception 'not_published'; end if;
  select coalesce(jsonb_agg(x), '[]'::jsonb) into v from (
    select jsonb_build_object('id', a.id, 'alias', a.alias, 'equipo', a.equipo, 'poder', a.poder, 'puntos', a.puntos) as x
      from public.duelo_equipos a
     where a.juego = p_juego and a.id <> yo.id and not a.oculta
     order by abs(a.puntos - yo.puntos) + (random() * 120)::int
     limit 3) s;
  return jsonb_build_object('yo', jsonb_build_object('puntos', yo.puntos, 'victorias', yo.victorias, 'derrotas', yo.derrotas), 'rivales', v);
end;
$$;

create or replace function public.duelo_empezar(p_juego uuid, p_sesion text, p_rival bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare yo public.duelo_equipos%rowtype; riv public.duelo_equipos%rowtype; v_id bigint;
begin
  select * into yo from public.duelo_equipos where juego = p_juego and sesion = p_sesion and not oculta;
  if not found then raise exception 'not_published'; end if;
  if (select count(*) from public.duelo_combates where atacante = yo.id and created_at > now() - interval '1 hour')
     >= public.setting('duelo_combates_hora') then raise exception 'rate_limited'; end if;
  select * into riv from public.duelo_equipos where id = p_rival and juego = p_juego and not oculta and id <> yo.id;
  if not found then raise exception 'unknown_rival'; end if;
  insert into public.duelo_combates (juego, atacante, defensor) values (p_juego, yo.id, riv.id) returning id into v_id;
  return jsonb_build_object('combate', v_id, 'alias', riv.alias, 'equipo', riv.equipo, 'puntos', riv.puntos);
end;
$$;

-- Puntos tipo Elo: ganar contra alguien con mas puntos da mas. Entre 8 y 40 por combate.
create or replace function public.duelo_resultado(p_juego uuid, p_sesion text, p_combate bigint, p_gano boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare yo public.duelo_equipos%rowtype; t public.duelo_combates%rowtype; riv public.duelo_equipos%rowtype;
  v_esp float; v_d integer; v_mios integer;
begin
  select * into yo from public.duelo_equipos where juego = p_juego and sesion = p_sesion;
  if not found then raise exception 'not_published'; end if;
  select * into t from public.duelo_combates where id = p_combate and atacante = yo.id for update;
  if not found then raise exception 'unknown_fight'; end if;
  if t.cerrado_at is not null then raise exception 'already_closed'; end if;
  if t.created_at < now() - interval '20 minutes' then raise exception 'expired'; end if;
  select * into riv from public.duelo_equipos where id = t.defensor;
  v_esp := 1.0 / (1.0 + power(10.0, (riv.puntos - yo.puntos) / 400.0));
  v_d := greatest(8, least(40, round(32 * ((case when p_gano then 1 else 0 end) - v_esp))::int * (case when p_gano then 1 else -1 end)));
  if p_gano then
    update public.duelo_equipos set puntos = puntos + v_d, victorias = victorias + 1 where id = yo.id returning puntos into v_mios;
    update public.duelo_equipos set puntos = greatest(puntos - v_d / 2, 0) where id = riv.id;
  else
    update public.duelo_equipos set puntos = greatest(puntos - v_d / 2, 0), derrotas = derrotas + 1 where id = yo.id returning puntos into v_mios;
    update public.duelo_equipos set puntos = puntos + v_d / 4 where id = riv.id;
  end if;
  update public.duelo_combates set gano = p_gano, delta = v_d, cerrado_at = now() where id = t.id;
  return jsonb_build_object('puntos', v_mios, 'delta', case when p_gano then v_d else -(v_d / 2) end);
end;
$$;

create or replace function public.duelo_top(p_juego uuid, p_sesion text, p_limite integer default 20)
returns table (posicion integer, alias text, puntos integer, poder integer, tuyo boolean)
language sql stable security definer set search_path = public as $$
  select (row_number() over (order by a.puntos desc, a.id))::int, a.alias, a.puntos, a.poder, a.sesion = p_sesion
    from public.duelo_equipos a where a.juego = p_juego and not a.oculta
   order by a.puntos desc, a.id limit least(greatest(coalesce(p_limite, 20), 1), 100);
$$;

create or replace function public.duelo_registro(p_juego uuid, p_sesion text)
returns table (alias text, gano boolean, delta integer, fecha timestamptz)
language sql stable security definer set search_path = public as $$
  select at.alias, t.gano, t.delta, t.cerrado_at
    from public.duelo_combates t
    join public.duelo_equipos yo on yo.id = t.defensor and yo.juego = p_juego and yo.sesion = p_sesion
    join public.duelo_equipos at on at.id = t.atacante
   where t.cerrado_at is not null
   order by t.cerrado_at desc limit 20;
$$;

create or replace function public.duelo_ocultar(p_id bigint, p_oculta boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.duelo_equipos a set oculta = p_oculta
    from public.projects p
   where a.id = p_id and p.telemetria_id = a.juego and p.user_id = auth.uid();
end;
$$;

revoke all on function public._duelo_juego_ok(uuid) from public, anon, authenticated;
grant execute on function public.duelo_publicar(uuid, text, text, jsonb, integer) to anon, authenticated;
grant execute on function public.duelo_rivales(uuid, text) to anon, authenticated;
grant execute on function public.duelo_empezar(uuid, text, bigint) to anon, authenticated;
grant execute on function public.duelo_resultado(uuid, text, bigint, boolean) to anon, authenticated;
grant execute on function public.duelo_top(uuid, text, integer) to anon, authenticated;
grant execute on function public.duelo_registro(uuid, text) to anon, authenticated;
grant execute on function public.duelo_ocultar(bigint, boolean) to authenticated;

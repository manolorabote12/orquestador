-- Orquestador: la Lanzadera. Probadores reales para la prueba cerrada de Google Play.
--
-- Google pide a las cuentas personales nuevas 12 probadores durante 14 dias seguidos antes de
-- pasar a produccion, y comprueba que de verdad jueguen. La Lanzadera es un intercambio justo:
--   - el autor abre una campana para su juego (enlace de su Grupo de Google y enlace de prueba);
--   - otros usuarios se unen al grupo, instalan desde Google Play y lo juegan;
--   - cada dia que juegan, hacen un check-in con su opinion PRIVADA para el autor (+1 punto);
--   - al cumplir 14 dias, +5 puntos; si dejan de jugar 2 dias, abandono (-5).
-- Reglas que la hacen honesta:
--   - Los puntos solo dan VISIBILIDAD (orden en la lista), nunca dinero ni resenas.
--   - NUNCA se piden ni se premian resenas en Google Play (va contra sus normas). La opinion va
--     solo al autor, dentro de Orquestador.
--   - Para que tu campana se vea tienes que estar probando juegos de otros (o ser premium).
--   - No se guarda el correo de Google de nadie: cada probador se une al grupo por su cuenta.
--
--   app (sesion)       -> lz_abrir, lz_lista, lz_unirme, lz_checkin, lz_mis_pruebas, lz_mis_campanas, lz_cerrar
--   reloj (servicio)   -> lz_revisar: marca abandonos y campanas listas.

alter table public.profiles add column if not exists premium_hasta timestamptz;

insert into public.settings (key, value, note) values
  ('lz_dias', 14, 'Dias seguidos que pide Google en prueba cerrada'),
  ('lz_probadores', 12, 'Probadores que pide Google'),
  ('lz_margen', 4, 'Probadores de mas que acepta una campana (por si alguno abandona)'),
  ('lz_minimo_probando', 3, 'Juegos de otros que hay que estar probando para que tu campana se vea (sin premium)'),
  ('lz_max_probando', 10, 'Juegos que una persona puede probar a la vez'),
  ('lz_dias_abandono', 2, 'Dias sin check-in que cuentan como abandono'),
  ('lz_puntos_dia', 1, 'Puntos por cada dia jugado'),
  ('lz_puntos_completar', 5, 'Puntos por cumplir los 14 dias'),
  ('lz_puntos_abandono', -5, 'Puntos por abandonar')
on conflict (key) do nothing;

create table if not exists public.lz_campanas (
  id          uuid primary key default gen_random_uuid(),
  owner       uuid not null references auth.users (id) on delete cascade,
  project_id  uuid not null references public.projects (id) on delete cascade,
  titulo      text not null,
  paquete     text not null,
  enlace_grupo text not null,
  enlace_prueba text not null,
  nota        text not null default '',
  estado      text not null default 'abierta' check (estado in ('abierta', 'lista', 'cerrada')),
  created_at  timestamptz not null default now()
);
create unique index if not exists lz_campana_abierta_idx on public.lz_campanas (project_id) where estado <> 'cerrada';

create table if not exists public.lz_probadores (
  id             bigserial primary key,
  campana        uuid not null references public.lz_campanas (id) on delete cascade,
  tester         uuid not null references auth.users (id) on delete cascade,
  estado         text not null default 'activo' check (estado in ('activo', 'completado', 'abandonado')),
  dias           integer not null default 0,
  ultimo_checkin date,
  created_at     timestamptz not null default now(),
  unique (campana, tester)
);
create index if not exists lz_probadores_tester_idx on public.lz_probadores (tester, estado);

create table if not exists public.lz_checkins (
  probador   bigint not null references public.lz_probadores (id) on delete cascade,
  dia        date not null,
  nivel      integer not null,
  opinion    text not null default '',
  created_at timestamptz not null default now(),
  primary key (probador, dia)
);

create table if not exists public.lz_puntos (
  id         bigserial primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  delta      integer not null,
  motivo     text not null,
  campana    uuid,
  created_at timestamptz not null default now()
);
create index if not exists lz_puntos_user_idx on public.lz_puntos (user_id);

alter table public.lz_campanas enable row level security;
alter table public.lz_probadores enable row level security;
alter table public.lz_checkins enable row level security;
alter table public.lz_puntos enable row level security;
-- Sin politicas: todo pasa por las funciones de abajo.

-- Dia UTC. orq.hoy solo existe en las pruebas (PostgREST no deja fijar ajustes arbitrarios).
create or replace function public.lz_hoy() returns date language sql stable as $$
  select coalesce(nullif(current_setting('orq.hoy', true), '')::date, (now() at time zone 'utc')::date)
$$;

create or replace function public.lz_saldo(p_user uuid) returns integer language sql stable
security definer set search_path = public as $$
  select coalesce(sum(delta), 0)::int from public.lz_puntos where user_id = p_user
$$;

create or replace function public.lz_premium(p_user uuid) returns boolean language sql stable
security definer set search_path = public as $$
  select coalesce((select premium_hasta > now() from public.profiles where id = p_user), false)
$$;

create or replace function public.lz_probando(p_user uuid) returns integer language sql stable
security definer set search_path = public as $$
  select count(*)::int from public.lz_probadores where tester = p_user and estado in ('activo', 'completado')
$$;

-- 1 - Abrir una campana para un juego mio que ya esta en Google Play (prueba cerrada).
create or replace function public.lz_abrir(p_project uuid, p_enlace_grupo text, p_nota text default '')
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_p    public.projects%rowtype;
  v_pkg  text;
  v_id   uuid;
begin
  if v_user is null then raise exception 'unknown_user'; end if;
  select * into v_p from public.projects where id = p_project and user_id = v_user;
  if not found then raise exception 'project_not_found'; end if;
  v_pkg := coalesce(v_p.play ->> 'paquete', '');
  if v_pkg !~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$' then raise exception 'not_on_play'; end if;
  p_enlace_grupo := trim(coalesce(p_enlace_grupo, ''));
  if p_enlace_grupo !~ '^https://groups\.google\.com/g/[A-Za-z0-9._-]{3,80}/?$' then raise exception 'bad_group_link'; end if;
  if length(coalesce(p_nota, '')) > 300 then raise exception 'note_too_long'; end if;
  insert into public.lz_campanas (owner, project_id, titulo, paquete, enlace_grupo, enlace_prueba, nota)
  values (v_user, p_project, left(v_p.title, 60), v_pkg, p_enlace_grupo,
          'https://play.google.com/apps/testing/' || v_pkg, trim(coalesce(p_nota, '')))
  returning id into v_id;
  return v_id;
exception when unique_violation then
  raise exception 'campaign_exists';
end;
$$;

-- 2 - Juegos que puedo probar: primero premium, luego quien mas da a la comunidad.
create or replace function public.lz_lista()
returns table (campana uuid, titulo text, nota text, enlace_grupo text, enlace_prueba text,
  probadores integer, faltan integer, premium boolean, created_at timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_max  int := public.setting('lz_probadores')::int + public.setting('lz_margen')::int;
  v_min  int := public.setting('lz_minimo_probando')::int;
begin
  if v_user is null then raise exception 'unknown_user'; end if;
  return query
    with c as (
      select k.*, (select count(*)::int from public.lz_probadores t where t.campana = k.id and t.estado in ('activo', 'completado')) as n,
             public.lz_premium(k.owner) as prem, public.lz_saldo(k.owner) as saldo
        from public.lz_campanas k
       where k.estado = 'abierta' and k.owner <> v_user
         and not exists (select 1 from public.lz_probadores t where t.campana = k.id and t.tester = v_user)
    )
    select c.id, c.titulo, c.nota, c.enlace_grupo, c.enlace_prueba, c.n,
           greatest(public.setting('lz_probadores')::int - c.n, 0), c.prem, c.created_at
      from c
     where c.n < v_max and (c.prem or public.lz_probando(c.owner) >= v_min)
     order by c.prem desc, (c.n < public.setting('lz_probadores')::int) desc, c.saldo desc, c.created_at
     limit 50;
end;
$$;

-- 3 - Unirme como probador (despues: unirme al grupo e instalar desde el enlace de prueba).
create or replace function public.lz_unirme(p_campana uuid)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_c    public.lz_campanas%rowtype;
  v_n    int;
  v_id   bigint;
begin
  if v_user is null then raise exception 'unknown_user'; end if;
  select * into v_c from public.lz_campanas where id = p_campana and estado = 'abierta' for update;
  if not found then raise exception 'campaign_not_found'; end if;
  if v_c.owner = v_user then raise exception 'own_campaign'; end if;
  if (select count(*) from public.lz_probadores where tester = v_user and estado = 'activo') >= public.setting('lz_max_probando') then
    raise exception 'too_many';
  end if;
  if (select count(*) from public.lz_probadores where tester = v_user and estado = 'abandonado'
        and created_at > now() - interval '30 days') >= 3 then
    raise exception 'too_many_abandoned';
  end if;
  select count(*) into v_n from public.lz_probadores where campana = p_campana and estado in ('activo', 'completado');
  if v_n >= public.setting('lz_probadores') + public.setting('lz_margen') then raise exception 'campaign_full'; end if;
  insert into public.lz_probadores (campana, tester) values (p_campana, v_user) returning id into v_id;
  return v_id;
exception when unique_violation then
  raise exception 'already_joined';
end;
$$;

-- 4 - Check-in diario: "he jugado hoy", hasta que nivel, y una opinion privada para el autor.
create or replace function public.lz_checkin(p_campana uuid, p_nivel integer, p_opinion text default '')
returns table (dias integer, completado boolean, puntos integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_t    public.lz_probadores%rowtype;
  v_hoy  date := public.lz_hoy();
  v_fin  boolean := false;
begin
  if v_user is null then raise exception 'unknown_user'; end if;
  select * into v_t from public.lz_probadores where campana = p_campana and tester = v_user for update;
  if not found then raise exception 'not_joined'; end if;
  if v_t.estado = 'abandonado' then raise exception 'abandoned'; end if;
  if v_t.ultimo_checkin = v_hoy then raise exception 'already_today'; end if;
  if p_nivel is null or p_nivel < 1 or p_nivel > 999 then raise exception 'bad_level'; end if;
  if length(coalesce(p_opinion, '')) > 500 then raise exception 'opinion_too_long'; end if;
  insert into public.lz_checkins (probador, dia, nivel, opinion) values (v_t.id, v_hoy, p_nivel, trim(coalesce(p_opinion, '')));
  update public.lz_probadores set dias = lz_probadores.dias + 1, ultimo_checkin = v_hoy where id = v_t.id
    returning * into v_t;
  if v_t.estado = 'activo' then
    insert into public.lz_puntos (user_id, delta, motivo, campana) values (v_user, public.setting('lz_puntos_dia'), 'dia', p_campana);
    if v_t.dias >= public.setting('lz_dias') then
      update public.lz_probadores set estado = 'completado' where id = v_t.id;
      insert into public.lz_puntos (user_id, delta, motivo, campana) values (v_user, public.setting('lz_puntos_completar'), 'completado', p_campana);
      v_fin := true;
    end if;
  end if;
  return query select v_t.dias, (v_fin or v_t.estado = 'completado'), public.lz_saldo(v_user);
end;
$$;

-- 5 - Lo que estoy probando.
create or replace function public.lz_mis_pruebas()
returns table (campana uuid, titulo text, enlace_grupo text, enlace_prueba text, estado text, dias integer,
  hecho_hoy boolean, objetivo integer)
language sql
stable
security definer
set search_path = public
as $$
  select c.id, c.titulo, c.enlace_grupo, c.enlace_prueba, t.estado, t.dias,
         coalesce(t.ultimo_checkin = public.lz_hoy(), false), public.setting('lz_dias')::int
    from public.lz_probadores t join public.lz_campanas c on c.id = t.campana
   where t.tester = auth.uid()
   order by (t.estado = 'activo') desc, t.created_at desc
$$;

-- 6 - Mis campanas: progreso y opiniones (los probadores salen como "Probador N", sin identidad).
create or replace function public.lz_mis_campanas()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'unknown_user'; end if;
  return jsonb_build_object(
    'puntos', public.lz_saldo(v_user),
    'premium', public.lz_premium(v_user),
    'probando', public.lz_probando(v_user),
    'minimo_probando', public.setting('lz_minimo_probando')::int,
    'visible_si_pruebas', public.lz_premium(v_user) or public.lz_probando(v_user) >= public.setting('lz_minimo_probando'),
    'campanas', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id, 'titulo', c.titulo, 'estado', c.estado, 'enlace_grupo', c.enlace_grupo,
        'enlace_prueba', c.enlace_prueba, 'project_id', c.project_id,
        'activos', (select count(*) from public.lz_probadores t where t.campana = c.id and t.estado = 'activo'),
        'completados', (select count(*) from public.lz_probadores t where t.campana = c.id and t.estado = 'completado'),
        'abandonos', (select count(*) from public.lz_probadores t where t.campana = c.id and t.estado = 'abandonado'),
        'objetivo', public.setting('lz_probadores')::int, 'dias', public.setting('lz_dias')::int,
        'probadores', coalesce((select jsonb_agg(jsonb_build_object('n', x.n, 'dias', x.dias, 'estado', x.estado) order by x.n)
            from (select row_number() over (order by t.id) as n, t.dias, t.estado from public.lz_probadores t where t.campana = c.id) x), '[]'::jsonb),
        'opiniones', coalesce((select jsonb_agg(jsonb_build_object('probador', x.n, 'dia', k.dia, 'nivel', k.nivel, 'opinion', k.opinion)
              order by k.created_at desc)
            from public.lz_checkins k
            join (select row_number() over (order by t.id) as n, t.id from public.lz_probadores t where t.campana = c.id) x on x.id = k.probador
           where k.opinion <> ''), '[]'::jsonb)
      ) order by c.created_at desc)
      from public.lz_campanas c where c.owner = v_user and c.estado <> 'cerrada'), '[]'::jsonb));
end;
$$;

create or replace function public.lz_cerrar(p_campana uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.lz_campanas set estado = 'cerrada' where id = p_campana and owner = auth.uid();
  if not found then raise exception 'campaign_not_found'; end if;
end;
$$;

-- 7 - Reloj (cada 15 minutos): abandonos y campanas que ya pueden pedir produccion.
create or replace function public.lz_revisar()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lim date := public.lz_hoy() - public.setting('lz_dias_abandono')::int;
  v_ab  int;
  v_ls  int;
begin
  with ab as (
    update public.lz_probadores t set estado = 'abandonado'
     where t.estado = 'activo' and coalesce(t.ultimo_checkin, (t.created_at at time zone 'utc')::date) < v_lim
     returning t.tester, t.campana
  ), pts as (
    insert into public.lz_puntos (user_id, delta, motivo, campana)
    select tester, public.setting('lz_puntos_abandono'), 'abandono', campana from ab
    returning 1
  )
  select count(*) into v_ab from pts;
  with ls as (
    update public.lz_campanas c set estado = 'lista'
     where c.estado = 'abierta'
       and (select count(*) from public.lz_probadores t where t.campana = c.id and t.estado = 'completado') >= public.setting('lz_probadores')
     returning 1
  )
  select count(*) into v_ls from ls;
  return jsonb_build_object('abandonos', v_ab, 'listas', v_ls);
end;
$$;

revoke all on function public.lz_abrir(uuid, text, text) from public, anon;
revoke all on function public.lz_lista() from public, anon;
revoke all on function public.lz_unirme(uuid) from public, anon;
revoke all on function public.lz_checkin(uuid, integer, text) from public, anon;
revoke all on function public.lz_mis_pruebas() from public, anon;
revoke all on function public.lz_mis_campanas() from public, anon;
revoke all on function public.lz_cerrar(uuid) from public, anon;
grant execute on function public.lz_abrir(uuid, text, text) to authenticated;
grant execute on function public.lz_lista() to authenticated;
grant execute on function public.lz_unirme(uuid) to authenticated;
grant execute on function public.lz_checkin(uuid, integer, text) to authenticated;
grant execute on function public.lz_mis_pruebas() to authenticated;
grant execute on function public.lz_mis_campanas() to authenticated;
grant execute on function public.lz_cerrar(uuid) to authenticated;
revoke all on function public.lz_revisar() from public, anon, authenticated;
grant execute on function public.lz_revisar() to service_role;
revoke all on function public.lz_saldo(uuid) from public, anon, authenticated;
revoke all on function public.lz_premium(uuid) from public, anon, authenticated;
revoke all on function public.lz_probando(uuid) from public, anon, authenticated;

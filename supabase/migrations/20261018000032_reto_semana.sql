-- Reto de la semana: un tema distinto cada semana (lunes a domingo, UTC). Cada persona presenta
-- UNO de sus juegos ya compartidos en el Escaparate; gana quien mas jugadas y me gusta reciba
-- ESA semana (los me gusta pesan 10). Los 3 primeros cobran tuercas una sola vez.
-- 1 - El tema sale de la fecha (todos ven el mismo, sin tabla que mantener).
-- 2 - reto_participar: solo juegos tuyos y visibles en el Escaparate; uno por persona y semana
--     (presentar otro cambia la entrada).
-- 3 - reto_premiar: solo el servidor (reloj.yml lo llama a menudo; es idempotente). Una semana
--     se premia cuando ha terminado, y nunca dos veces.

insert into public.settings (key, value, note) values
  ('reto_premio_1', 150, 'Tuercas para el ganador del reto de la semana'),
  ('reto_premio_2', 100, 'Tuercas para el segundo del reto de la semana'),
  ('reto_premio_3', 50, 'Tuercas para el tercero del reto de la semana')
on conflict (key) do nothing;

create table if not exists public.reto_entradas (
  semana     integer not null,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  project_id uuid not null references public.escaparate (project_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (semana, user_id)
);
alter table public.reto_entradas enable row level security;

create table if not exists public.reto_premiados (
  semana     integer primary key,
  pagados    integer not null default 0,
  created_at timestamptz not null default now()
);
alter table public.reto_premiados enable row level security;

-- Semana 0 = la que empieza el lunes 5-1-2026.
create or replace function public.reto_semana_de(p_dia date)
returns integer language sql immutable as $$
  select floor((p_dia - date '2026-01-05') / 7.0)::integer;
$$;

create or replace function public.reto_tema(p_semana integer)
returns text language sql immutable as $$
  select (array['Piratas', 'Espacio', 'Dinosaurios', 'Comida', 'Robots', 'Fantasmas', 'Océano', 'Ninjas',
    'Magia', 'Selva', 'Hielo', 'Volcanes', 'Insectos', 'Caballeros', 'Gatos', 'Ciudad de neón', 'Granja',
    'Monstruos simpáticos', 'Deportes', 'Música', 'Dragones', 'Juguetes', 'Desierto', 'Bosque encantado',
    'Zombis', 'Alienígenas', 'Dulces', 'Detectives', 'Superhéroes', 'Vikingos', 'Castillos', 'Tiempo',
    'Sueños', 'Reciclaje', 'Abejas', 'Trenes', 'Laboratorio', 'Pingüinos', 'Mundo al revés', 'Lluvia',
    'Circo', 'Cuevas', 'Nubes', 'Coches', 'Momias', 'Jardín', 'Tormenta', 'Mini mundo', 'Fiesta',
    'Noche', 'Pixel retro', 'Invierno'])[1 + ((p_semana % 52) + 52) % 52];
$$;

create or replace function public.reto_ranking(p_semana integer default null)
returns table (puesto integer, project_id uuid, titulo text, genero text, autor text, version integer, puntos integer)
language sql
stable
security definer
set search_path = public
as $$
  with w as (select coalesce(p_semana, public.reto_semana_de((now() at time zone 'UTC')::date)) as n),
  rango as (select date '2026-01-05' + w.n * 7 as desde, date '2026-01-05' + (w.n + 1) * 7 as hasta from w),
  pts as (
    select en.project_id, coalesce(sum(d.jugadas), 0) + 10 * coalesce(sum(d.megusta), 0) as p
      from public.reto_entradas en
      join w on en.semana = w.n
      cross join rango
      left join public.escaparate_dia d on d.project_id = en.project_id and d.dia >= rango.desde and d.dia < rango.hasta
     group by en.project_id
  )
  select (row_number() over (order by pts.p desc, e.publicado_en))::integer, e.project_id, e.titulo, e.genero, e.autor, e.version, pts.p::integer
    from pts join public.escaparate e on e.project_id = pts.project_id
   where not e.oculto
   order by pts.p desc, e.publicado_en
   limit 20;
$$;

create or replace function public.reto_actual()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with s as (select public.reto_semana_de((now() at time zone 'UTC')::date) as n)
  select jsonb_build_object(
    'semana', s.n,
    'tema', public.reto_tema(s.n),
    'termina', ((date '2026-01-05' + (s.n + 1) * 7)::timestamp at time zone 'UTC'),
    'premios', jsonb_build_array(public.setting('reto_premio_1'), public.setting('reto_premio_2'), public.setting('reto_premio_3')),
    'mi_proyecto', (select e.project_id from public.reto_entradas e where e.semana = s.n and e.user_id = auth.uid()),
    'participantes', (select count(*) from public.reto_entradas e where e.semana = s.n),
    'ganadores_anterior', coalesce((select jsonb_agg(jsonb_build_object('titulo', r.titulo, 'autor', r.autor, 'puesto', r.puesto) order by r.puesto)
      from public.reto_ranking(s.n - 1) r where r.puesto <= 3), '[]'::jsonb)
  ) from s;
$$;

create or replace function public.reto_participar(p_project uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_n integer := public.reto_semana_de((now() at time zone 'UTC')::date);
begin
  if v_user is null then raise exception 'unknown_user'; end if;
  if not exists (select 1 from public.escaparate where project_id = p_project and user_id = v_user and not oculto) then
    raise exception 'not_shared';    -- primero hay que compartirlo en el Escaparate
  end if;
  insert into public.reto_entradas (semana, user_id, project_id) values (v_n, v_user, p_project)
    on conflict (semana, user_id) do update set project_id = excluded.project_id, created_at = now();
  return jsonb_build_object('semana', v_n, 'tema', public.reto_tema(v_n), 'project_id', p_project);
end;
$$;

create or replace function public.reto_premiar(p_semana integer)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  n integer := 0;
begin
  if p_semana >= public.reto_semana_de((now() at time zone 'UTC')::date) then raise exception 'not_finished'; end if;
  -- Bloqueo: dos llamadas a la vez no pagan dos veces.
  insert into public.reto_premiados (semana) values (p_semana) on conflict do nothing;
  if not found then return 0; end if;
  for r in select k.puesto, k.project_id, k.puntos, e.user_id
             from public.reto_ranking(p_semana) k join public.escaparate e on e.project_id = k.project_id
            where k.puesto <= 3 and k.puntos > 0 loop
    update public.profiles set credits = credits + public.setting('reto_premio_' || r.puesto)::integer where id = r.user_id;
    insert into public.credit_ledger (user_id, amount, reason, ref)
      values (r.user_id, public.setting('reto_premio_' || r.puesto)::integer, 'weekly_challenge', p_semana || ':' || r.puesto);
    n := n + 1;
  end loop;
  update public.reto_premiados set pagados = n where semana = p_semana;
  return n;
end;
$$;

-- Lo llama el reloj: premia la semana pasada si aun no se premio (no hace nada si ya esta).
create or replace function public.reto_premiar_anterior()
returns integer
language sql
security definer
set search_path = public
as $$
  select public.reto_premiar(public.reto_semana_de((now() at time zone 'UTC')::date) - 1);
$$;

revoke all on function public.reto_participar(uuid) from public, anon;
revoke all on function public.reto_premiar(integer) from public, anon, authenticated;
revoke all on function public.reto_premiar_anterior() from public, anon, authenticated;
grant execute on function public.reto_participar(uuid) to authenticated;
grant execute on function public.reto_actual() to anon, authenticated;
grant execute on function public.reto_ranking(integer) to anon, authenticated;
grant execute on function public.reto_premiar(integer) to service_role;
grant execute on function public.reto_premiar_anterior() to service_role;

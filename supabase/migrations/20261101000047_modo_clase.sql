-- Modo clase: un profesor (el autor) crea una clase con un codigo; los alumnos lo escriben en el
-- juego con su nombre de pila o un apodo y el profesor ve en la app como va cada uno (niveles,
-- estrellas y minutos). Sin correos ni datos personales: solo el apodo que escribe el alumno.
--   profe (app) -> clase_crear, clase_cerrar, clases_autor
--   juego (anon) -> clase_unirse, clase_progreso
create table if not exists public.clases (
  id         bigint generated always as identity primary key,
  project_id uuid not null references public.projects (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  codigo     text not null unique check (codigo ~ '^[A-Z2-9]{6}$'),
  nombre     text not null check (char_length(nombre) between 1 and 40),
  activa     boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.clases enable row level security;

create table if not exists public.clase_alumnos (
  clase      bigint not null references public.clases (id) on delete cascade,
  sesion     text not null,
  alias      text not null,
  niveles    integer not null default 0,
  estrellas  integer not null default 0,
  minutos    integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (clase, sesion)
);
alter table public.clase_alumnos enable row level security;

create or replace function public.clase_crear(p_project uuid, p_nombre text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_codigo text;
  i integer;
begin
  if auth.uid() is null then raise exception 'unknown_user'; end if;
  if not exists (select 1 from public.projects where id = p_project and user_id = auth.uid()) then raise exception 'project_not_found'; end if;
  if coalesce(btrim(p_nombre), '') = '' or char_length(btrim(p_nombre)) > 40 or p_nombre ~ '[<>{}\\]' then raise exception 'bad_name'; end if;
  if (select count(*) from public.clases where project_id = p_project and activa) >= 10 then raise exception 'too_many'; end if;
  for i in 1..20 loop
    -- Sin 0/O ni 1/I para que no se confundan al dictarlo en clase.
    v_codigo := (select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1), '') from generate_series(1, 6));
    exit when not exists (select 1 from public.clases where codigo = v_codigo);
  end loop;
  insert into public.clases (project_id, user_id, codigo, nombre) values (p_project, auth.uid(), v_codigo, btrim(p_nombre));
  return v_codigo;
end;
$$;

create or replace function public.clase_cerrar(p_codigo text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.clases where codigo = upper(p_codigo) and user_id = auth.uid();
  if not found then raise exception 'not_found'; end if;
end;
$$;

create or replace function public.clases_autor(p_project uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object('codigo', c.codigo, 'nombre', c.nombre, 'creada', c.created_at,
    'alumnos', coalesce((select jsonb_agg(jsonb_build_object('alias', a.alias, 'niveles', a.niveles, 'estrellas', a.estrellas,
      'minutos', a.minutos, 'visto', a.updated_at) order by a.niveles desc, a.estrellas desc, a.alias)
      from public.clase_alumnos a where a.clase = c.id), '[]'::jsonb)) order by c.created_at desc), '[]'::jsonb)
  from public.clases c where c.project_id = p_project and c.user_id = auth.uid();
$$;

create or replace function public._clase_de(p_juego uuid, p_codigo text)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select c.id from public.clases c join public.projects p on p.id = c.project_id
   where c.codigo = upper(btrim(coalesce(p_codigo, ''))) and c.activa and p.telemetria_id = p_juego;
$$;

create or replace function public.clase_unirse(p_juego uuid, p_codigo text, p_sesion text, p_alias text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_clase bigint;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  v_clase := public._clase_de(p_juego, p_codigo);
  if v_clase is null then raise exception 'bad_code'; end if;
  if not public.alias_valido(p_alias) then raise exception 'bad_alias'; end if;
  if not exists (select 1 from public.clase_alumnos where clase = v_clase and sesion = p_sesion)
     and (select count(*) from public.clase_alumnos where clase = v_clase) >= 60 then raise exception 'class_full'; end if;
  insert into public.clase_alumnos (clase, sesion, alias) values (v_clase, p_sesion, btrim(p_alias))
  on conflict (clase, sesion) do update set alias = excluded.alias, updated_at = now();
  return (select jsonb_build_object('nombre', nombre, 'codigo', codigo) from public.clases where id = v_clase);
end;
$$;

create or replace function public.clase_progreso(p_juego uuid, p_codigo text, p_sesion text, p_niveles integer, p_estrellas integer, p_minutos integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_clase bigint;
begin
  v_clase := public._clase_de(p_juego, p_codigo);
  if v_clase is null then raise exception 'bad_code'; end if;
  update public.clase_alumnos set niveles = greatest(niveles, least(coalesce(p_niveles, 0), 500)),
    estrellas = greatest(estrellas, least(coalesce(p_estrellas, 0), 1500)),
    minutos = greatest(minutos, least(coalesce(p_minutos, 0), 100000)), updated_at = now()
   where clase = v_clase and sesion = p_sesion;
  if not found then raise exception 'not_joined'; end if;
end;
$$;

revoke all on function public.clase_crear(uuid, text), public.clase_cerrar(text), public.clases_autor(uuid) from public, anon;
grant execute on function public.clase_crear(uuid, text), public.clase_cerrar(text), public.clases_autor(uuid) to authenticated;
revoke all on function public._clase_de(uuid, text) from public, anon, authenticated;
grant execute on function public.clase_unirse(uuid, text, text, text), public.clase_progreso(uuid, text, text, integer, integer, integer) to anon, authenticated;

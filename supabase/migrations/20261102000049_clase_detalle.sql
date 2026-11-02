-- Modo clase: donde se atasca cada alumno (el nivel en el que esta y cuantas veces ha fallado en
-- el) y vaciar la clase para otro trimestre sin cambiar el codigo.
alter table public.clase_alumnos add column if not exists nivel_actual integer not null default 0;
alter table public.clase_alumnos add column if not exists intentos integer not null default 0;

drop function if exists public.clase_progreso(uuid, text, text, integer, integer, integer);
create or replace function public.clase_progreso(p_juego uuid, p_codigo text, p_sesion text, p_niveles integer, p_estrellas integer,
  p_minutos integer, p_nivel_actual integer default 0, p_intentos integer default 0)
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
    minutos = greatest(minutos, least(coalesce(p_minutos, 0), 100000)),
    nivel_actual = least(greatest(coalesce(p_nivel_actual, 0), 0), 501),
    intentos = least(greatest(coalesce(p_intentos, 0), 0), 9999), updated_at = now()
   where clase = v_clase and sesion = p_sesion;
  if not found then raise exception 'not_joined'; end if;
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
      'minutos', a.minutos, 'visto', a.updated_at, 'nivel_actual', a.nivel_actual, 'intentos', a.intentos)
      order by a.niveles desc, a.estrellas desc, a.alias)
      from public.clase_alumnos a where a.clase = c.id), '[]'::jsonb)) order by c.created_at desc), '[]'::jsonb)
  from public.clases c where c.project_id = p_project and c.user_id = auth.uid();
$$;

-- Vaciar la clase (otro trimestre, otro grupo): se borran los alumnos y se queda el codigo.
create or replace function public.clase_vaciar(p_codigo text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id bigint;
begin
  select id into v_id from public.clases where codigo = upper(btrim(coalesce(p_codigo, ''))) and user_id = auth.uid();
  if not found then raise exception 'not_found'; end if;
  delete from public.clase_alumnos where clase = v_id;
end;
$$;

grant execute on function public.clase_progreso(uuid, text, text, integer, integer, integer, integer, integer) to anon, authenticated;
revoke all on function public.clase_vaciar(text) from public, anon;
grant execute on function public.clase_vaciar(text) to authenticated;

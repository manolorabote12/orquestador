-- Orquestador: aprender de la gente que juega.
--
-- Cada juego publicado envia, de forma anonima, un resumen de cada intento de nivel:
--   {n: nivel, r: gana | muere | sale | reintenta, s: segundos, m: muertes, e: estrellas}
-- con un numero de sesion aleatorio por arranque (no identifica a nadie, no hay ID de publicidad).
--
--   juego (anon)        -> registrar_partida: valida, limita y guarda.
--   autor (su sesion)   -> informe_jugadores(project): por version y nivel, como le va a la gente.
--   fabrica (servicio)  -> estadisticas_globales(): lo mismo agregado por genero, dificultad y
--                          posicion del nivel, para calibrar la dificultad de los juegos nuevos.

alter table public.projects add column if not exists telemetria_id uuid unique default gen_random_uuid();
update public.projects set telemetria_id = gen_random_uuid() where telemetria_id is null;

-- El juego nuevo lleva como id de telemetria el id del trabajo que lo fabrico (se conoce antes
-- de que exista el proyecto): se apunta al crear el proyecto.
create or replace function public.complete_game_job(
  p_job uuid, p_cost_usd numeric, p_units numeric, p_title text, p_spec jsonb, p_files jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job     public.jobs%rowtype;
  v_project uuid;
begin
  select * into v_job from public.jobs where id = p_job and status = 'running' for update;
  if not found then raise exception 'job_not_running'; end if;
  insert into public.projects (user_id, title, spec, files, telemetria_id)
  values (v_job.user_id, left(p_title, 60), p_spec, p_files, v_job.id)
  returning id into v_project;
  insert into public.project_versions (project_id, version, spec, prompt, files)
  values (v_project, 1, p_spec, coalesce(v_job.detail ->> 'idea', ''), p_files);
  update public.jobs set result = p_files, project_id = v_project where id = p_job;
  perform public.finish_job(p_job, p_cost_usd, null, null, p_units);
  return v_project;
end;
$$;

create table if not exists public.partidas (
  id         bigserial primary key,
  juego      uuid not null,
  version    integer not null,
  sesion     text not null,
  nivel      integer not null,
  resultado  text not null check (resultado in ('gana', 'muere', 'sale', 'reintenta')),
  segundos   real not null,
  muertes    integer not null,
  estrellas  integer,
  created_at timestamptz not null default now()
);
create index if not exists partidas_juego_idx on public.partidas (juego, version, nivel);
create index if not exists partidas_sesion_idx on public.partidas (sesion, created_at);
alter table public.partidas enable row level security;
-- Sin politicas: nadie lee ni escribe la tabla directamente; solo por las funciones de abajo.

insert into public.settings (key, value, note) values
  ('partidas_por_sesion_hora', 300, 'Intentos que una sesion puede enviar por hora (frena abusos)'),
  ('partidas_por_juego_dia', 200000, 'Intentos que un juego puede recibir al dia')
on conflict (key) do nothing;

create or replace function public.registrar_partida(p_juego uuid, p_version integer, p_sesion text, p_eventos jsonb)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  e jsonb;
  n integer := 0;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{8,32}$' then raise exception 'bad_session'; end if;
  if jsonb_typeof(p_eventos) <> 'array' or jsonb_array_length(p_eventos) = 0 or jsonb_array_length(p_eventos) > 50 then
    raise exception 'bad_batch';
  end if;
  if p_version is null or p_version < 1 or p_version > 100000 then raise exception 'bad_version'; end if;
  if not exists (select 1 from public.projects where telemetria_id = p_juego) then raise exception 'unknown_game'; end if;
  if (select count(*) from public.partidas where sesion = p_sesion and created_at > now() - interval '1 hour')
     + jsonb_array_length(p_eventos) > public.setting('partidas_por_sesion_hora') then
    raise exception 'rate_limited';
  end if;
  if (select count(*) from public.partidas where juego = p_juego and created_at > now() - interval '1 day')
     >= public.setting('partidas_por_juego_dia') then
    raise exception 'rate_limited';
  end if;
  for e in select * from jsonb_array_elements(p_eventos) loop
    -- Lo que no tiene la forma exacta se ignora (sin convertir nada antes de comprobarlo).
    if jsonb_typeof(e) <> 'object'
       or coalesce(e ->> 'n', '') !~ '^[0-9]{1,2}$'
       or coalesce(e ->> 'r', '') not in ('gana', 'muere', 'sale', 'reintenta')
       or coalesce(e ->> 's', '') !~ '^[0-9]{1,4}(\.[0-9]{1,3})?$'
       or coalesce(e ->> 'm', '') !~ '^[0-9]{1,3}$'
       or coalesce(e ->> 'e', '0') !~ '^[0-3]$' then
      continue;
    end if;
    if (e ->> 's')::real > 7200 then
      continue;
    end if;
    insert into public.partidas (juego, version, sesion, nivel, resultado, segundos, muertes, estrellas)
    values (p_juego, p_version, p_sesion, (e ->> 'n')::int, e ->> 'r', (e ->> 's')::real, (e ->> 'm')::int, (e ->> 'e')::int);
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- Informe para el autor del juego (con su sesion): por version y nivel.
create or replace function public.informe_jugadores(p_project uuid)
returns table (version integer, nivel integer, intentos integer, sesiones integer, ganados integer, salidas integer,
  reintentos integer, muertes_medias numeric, segundos_medios numeric, estrellas_medias numeric)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tel uuid;
begin
  select telemetria_id into v_tel from public.projects where id = p_project and user_id = auth.uid();
  if v_tel is null then raise exception 'project_not_found'; end if;
  return query
    select p.version, p.nivel, count(*)::int, count(distinct p.sesion)::int,
           count(*) filter (where p.resultado = 'gana')::int,
           count(*) filter (where p.resultado = 'sale')::int,
           count(*) filter (where p.resultado = 'reintenta')::int,
           round(avg(p.muertes)::numeric, 2), round(avg(p.segundos)::numeric, 1),
           round(avg(p.estrellas) filter (where p.resultado = 'gana')::numeric, 2)
      from public.partidas p
     where p.juego = v_tel
     group by p.version, p.nivel
     order by p.version desc, p.nivel;
end;
$$;

-- Para la fabrica: como le va a la gente segun genero, dificultad y tramo del nivel (0 = primero,
-- 4 = ultimo). Solo cuenta juegos con al menos 20 intentos para que un juego raro no lo tuerza.
create or replace function public.estadisticas_globales()
returns table (genero text, dificultad text, tramo integer, juegos integer, intentos integer, tasa_victoria numeric,
  tasa_abandono numeric, muertes_medias numeric)
language sql
stable
security definer
set search_path = public
as $$
  with base as (
    select coalesce(pr.spec ->> 'genero', 'plataformas') as genero, coalesce(pr.spec ->> 'dificultad', 'normal') as dificultad,
           pa.juego, pa.nivel, pa.resultado, pa.muertes,
           greatest(1, jsonb_array_length(coalesce(pr.spec -> 'niveles', '[]'::jsonb))) as total
      from public.partidas pa join public.projects pr on pr.telemetria_id = pa.juego
     where pa.created_at > now() - interval '90 days'
  ), validos as (
    select juego from base group by juego having count(*) >= 20
  )
  select b.genero, b.dificultad,
         (case when b.total <= 1 then 0 else least(4, floor(4.0 * b.nivel / (b.total - 1) + 0.5)) end)::int as tramo,
         count(distinct b.juego)::int, count(*)::int,
         round(avg((b.resultado = 'gana')::int)::numeric, 3),
         round(avg((b.resultado = 'sale')::int)::numeric, 3),
         round(avg(b.muertes)::numeric, 2)
    from base b join validos v on v.juego = b.juego
   group by 1, 2, 3
   order by 1, 2, 3;
$$;

revoke all on function public.registrar_partida(uuid, integer, text, jsonb) from public;
grant execute on function public.registrar_partida(uuid, integer, text, jsonb) to anon, authenticated, service_role;
revoke all on function public.informe_jugadores(uuid) from public, anon;
grant execute on function public.informe_jugadores(uuid) to authenticated;
revoke all on function public.estadisticas_globales() from public, anon, authenticated;
grant execute on function public.estadisticas_globales() to service_role;
revoke all on function public.complete_game_job(uuid, numeric, numeric, text, jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.complete_game_job(uuid, numeric, numeric, text, jsonb, jsonb) to service_role;

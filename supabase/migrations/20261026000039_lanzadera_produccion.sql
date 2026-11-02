-- Lanzadera, mejoras para llegar a produccion:
--   1 - Mis campanas trae la fecha de inicio, los check-ins, el nivel medio y el maximo: con eso la
--       app rellena las respuestas que pide Google al solicitar el acceso a produccion (el resto
--       sale de las opiniones privadas que ya habia).
--   2 - Reservas: una campana admite 12 + lz_margen probadores; el margen sube de 4 a 6 para que un par
--       de abandonos no obliguen a empezar otra vez (Google cuenta 12 durante 14 dias seguidos).
--       (En la lista ya salian primero las campanas a las que les faltan probadores.)

update public.settings set value = 6 where key = 'lz_margen' and value::int < 6;

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
        'enlace_prueba', c.enlace_prueba, 'project_id', c.project_id, 'creada', c.created_at,
        -- Para responder a Google al pedir produccion: cuanto se jugo y hasta donde.
        'checkins', (select count(*) from public.lz_checkins k join public.lz_probadores t on t.id = k.probador where t.campana = c.id),
        'nivel_medio', (select round(avg(k.nivel)::numeric, 1) from public.lz_checkins k join public.lz_probadores t on t.id = k.probador where t.campana = c.id),
        'nivel_max', (select max(k.nivel) from public.lz_checkins k join public.lz_probadores t on t.id = k.probador where t.campana = c.id),
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


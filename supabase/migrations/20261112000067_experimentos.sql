-- La fabrica aprende por experimentos (12 de noviembre de 2026).
--
-- Cada juego de un genero con mandos (camara, tamano de los personajes, piezas de nivel) prueba una
-- variante; la critica visual le pone nota al final y aqui se apunta. Las maquinas de la fabrica leen
-- el historial del genero y eligen la siguiente variante con muestreo de Thompson (experimentos.py):
-- lo que puntua mejor sale cada vez mas. Solo la fabrica (clave de servicio) lee y escribe.

create table if not exists public.experimentos (
  id bigint generated always as identity primary key,
  genero text not null check (length(genero) between 1 and 40),
  eleccion jsonb not null default '{}'::jsonb,
  nota smallint not null check (nota between 1 and 10),
  problemas text[] not null default '{}',
  creado timestamptz not null default now()
);
create index if not exists experimentos_genero on public.experimentos (genero, creado desc);
alter table public.experimentos enable row level security;
revoke all on public.experimentos from public, anon, authenticated;

create or replace function public.experimento_anotar(p_genero text, p_eleccion jsonb, p_nota int, p_problemas text[])
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.experimentos (genero, eleccion, nota, problemas)
  values (left(p_genero, 40), coalesce(p_eleccion, '{}'::jsonb), greatest(1, least(10, p_nota)),
    coalesce(p_problemas[1:6], '{}'));
$$;
revoke all on function public.experimento_anotar(text, jsonb, int, text[]) from public, anon, authenticated;
grant execute on function public.experimento_anotar(text, jsonb, int, text[]) to service_role;

-- Los ultimos 120 resultados del genero (los mas recientes al final, como los usa experimentos.py).
create or replace function public.experimentos_historial(p_genero text)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object('eleccion', eleccion, 'nota', nota, 'problemas', to_jsonb(problemas))
  from (select * from public.experimentos where genero = p_genero order by creado desc limit 120) t
  order by creado asc;
$$;
revoke all on function public.experimentos_historial(text) from public, anon, authenticated;
grant execute on function public.experimentos_historial(text) to service_role;

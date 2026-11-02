-- Huellas de originalidad: lo que distingue cada juego que fabrica la fabrica (genero, giros,
-- reglas, palabras del tema y estilo; sin titulos ni usuarios). Antes de fabricar, la idea nueva se
-- compara con las del mismo genero: si sale casi igual, la fabrica le anade un giro para que sea unica.
-- Solo la fabrica (service_role) escribe y lee.

create table if not exists public.huellas (
  id         bigserial primary key,
  genero     text not null check (char_length(genero) between 2 and 20),
  firma      jsonb not null check (pg_column_size(firma) <= 4000),
  created_at timestamptz not null default now()
);
create index if not exists huellas_idx on public.huellas (genero, created_at);
alter table public.huellas enable row level security;

create or replace function public.huella_anotar(p_genero text, p_firma jsonb)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.huellas (genero, firma)
  select p_genero, p_firma where jsonb_typeof(p_firma) = 'object';
$$;

-- Las 4000 mas recientes (ultimos 365 dias), cada una con su genero.
create or replace function public.huellas_recientes()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(firma || jsonb_build_object('genero', genero) order by created_at desc), '[]'::jsonb)
  from (select genero, firma, created_at from public.huellas
        where created_at > now() - interval '365 days' order by created_at desc limit 4000) h;
$$;

do $$
declare f text;
begin
  foreach f in array array['public.huella_anotar(text, jsonb)', 'public.huellas_recientes()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end;
$$;

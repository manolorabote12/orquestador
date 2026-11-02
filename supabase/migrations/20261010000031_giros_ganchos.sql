-- Giros: la fabrica apunta cada uso (genero, giro, si salio bien y, si no, que paso). Todas las
-- maquinas de la fabrica aprenden de lo mismo: giros_estadisticas() lo resume y la funcion
-- 'ganchos' no propone giros que fallan mucho en un genero.
-- Ganchos: 3 propuestas originales (genero + giros + idea) para una idea; cupo diario por usuario.

insert into public.settings (key, value, note) values
  ('ganchos_dia', 20, 'Propuestas de ganchos originales (IA) por usuario y dia')
on conflict (key) do nothing;

create table if not exists public.giros_uso (
  id         bigserial primary key,
  genero     text not null check (char_length(genero) between 2 and 20),
  giro       text not null check (char_length(giro) between 2 and 20),
  ok         boolean not null,
  problema   text not null default '' check (char_length(problema) <= 240),
  created_at timestamptz not null default now()
);
create index if not exists giros_uso_idx on public.giros_uso (genero, giro, created_at);
alter table public.giros_uso enable row level security;

create table if not exists public.ganchos_uso (
  id         bigserial primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  coste_usd  numeric not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists ganchos_uso_idx on public.ganchos_uso (user_id, created_at);
alter table public.ganchos_uso enable row level security;

create or replace function public.giro_anotar(p_genero text, p_giro text, p_ok boolean, p_problema text default '')
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.giros_uso (genero, giro, ok, problema) values (p_genero, p_giro, p_ok, left(coalesce(p_problema, ''), 240));
$$;

-- Ultimos 120 dias: usos y exitos por genero y giro, y las ultimas lecciones (fallos).
create or replace function public.giros_estadisticas()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'stats', coalesce((select jsonb_agg(jsonb_build_object('genero', genero, 'giro', giro, 'usos', usos, 'ok', ok))
      from (select genero, giro, count(*)::int as usos, count(*) filter (where ok)::int as ok
              from public.giros_uso where created_at > now() - interval '120 days' group by genero, giro) s), '[]'::jsonb),
    'lecciones', coalesce((select jsonb_agg(jsonb_build_object('genero', genero, 'giro', giro, 'problema', problema) order by created_at desc)
      from (select * from public.giros_uso where not ok and problema <> '' order by created_at desc limit 30) l), '[]'::jsonb));
$$;

create or replace function public.gancho_reservar(p_user uuid)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id bigint;
begin
  perform pg_advisory_xact_lock(hashtext('ganchos:' || p_user::text));
  if (select count(*) from public.ganchos_uso where user_id = p_user and created_at > now() - interval '1 day')
     >= public.setting('ganchos_dia') then
    raise exception 'rate_limited';
  end if;
  insert into public.ganchos_uso (user_id) values (p_user) returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.gancho_coste(p_id bigint, p_coste numeric)
returns void
language sql
security definer
set search_path = public
as $$
  update public.ganchos_uso set coste_usd = greatest(0, coalesce(p_coste, 0)) where id = p_id;
$$;

do $$
declare f text;
begin
  foreach f in array array['public.giro_anotar(text, text, boolean, text)', 'public.giros_estadisticas()',
      'public.gancho_reservar(uuid)', 'public.gancho_coste(bigint, numeric)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end;
$$;

-- Orquestador: esquema inicial
-- Cuentas con saldo de créditos, historial de movimientos, proyectos con versiones,
-- trabajos de IA y denuncias de contenido (exigidas por Google Play para apps con IA).

-- ============ Tablas ============

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  credits     integer not null default 0 check (credits >= 0),
  created_at  timestamptz not null default now()
);

create table public.credit_ledger (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  amount      integer not null,              -- positivo = ingreso, negativo = gasto
  reason      text not null,                 -- signup | design | edit | refund | purchase | reward_ad
  ref         text,                          -- id del trabajo, de la compra, etc.
  created_at  timestamptz not null default now()
);

create index credit_ledger_user_idx on public.credit_ledger (user_id, created_at desc);

create table public.projects (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  title       text not null,
  spec        jsonb not null,
  version     integer not null default 1,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index projects_user_idx on public.projects (user_id, updated_at desc);

create table public.project_versions (
  project_id  uuid not null references public.projects (id) on delete cascade,
  version     integer not null,
  spec        jsonb not null,
  prompt      text not null,                 -- idea o cambio que pidió el usuario
  created_at  timestamptz not null default now(),
  primary key (project_id, version)
);

create table public.jobs (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles (id) on delete cascade,
  kind         text not null check (kind in ('design', 'edit')),
  status       text not null default 'running' check (status in ('running', 'done', 'failed')),
  cost         integer not null,
  error        text,
  created_at   timestamptz not null default now(),
  finished_at  timestamptz
);

create index jobs_user_idx on public.jobs (user_id, created_at desc);

create table public.content_reports (
  id          bigint generated always as identity primary key,
  reporter    uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  project_id  uuid references public.projects (id) on delete set null,
  reason      text not null check (char_length(reason) between 3 and 500),
  status      text not null default 'pending' check (status in ('pending', 'reviewed', 'actioned')),
  created_at  timestamptz not null default now()
);

-- ============ Seguridad por filas ============
-- La app solo LEE sus propios datos. Todo lo que cuesta créditos o cambia proyectos
-- pasa por funciones del servidor con la clave de servicio.

alter table public.profiles         enable row level security;
alter table public.credit_ledger    enable row level security;
alter table public.projects         enable row level security;
alter table public.project_versions enable row level security;
alter table public.jobs             enable row level security;
alter table public.content_reports  enable row level security;

create policy "ver mi perfil" on public.profiles
  for select to authenticated using (id = auth.uid());

create policy "ver mis movimientos" on public.credit_ledger
  for select to authenticated using (user_id = auth.uid());

create policy "ver mis proyectos" on public.projects
  for select to authenticated using (user_id = auth.uid());

create policy "borrar mis proyectos" on public.projects
  for delete to authenticated using (user_id = auth.uid());

create policy "ver versiones de mis proyectos" on public.project_versions
  for select to authenticated using (
    exists (select 1 from public.projects p where p.id = project_id and p.user_id = auth.uid())
  );

create policy "ver mis trabajos" on public.jobs
  for select to authenticated using (user_id = auth.uid());

create policy "denunciar contenido" on public.content_reports
  for insert to authenticated with check (reporter = auth.uid());

create policy "ver mis denuncias" on public.content_reports
  for select to authenticated using (reporter = auth.uid());

-- ============ Créditos (solo el servidor puede tocarlos) ============

create or replace function public.spend_credits(p_user uuid, p_amount integer, p_reason text, p_ref text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_balance integer;
begin
  if p_amount <= 0 then
    raise exception 'invalid_amount';
  end if;

  update public.profiles
     set credits = credits - p_amount
   where id = p_user and credits >= p_amount
  returning credits into v_balance;

  if not found then
    raise exception 'insufficient_credits';
  end if;

  insert into public.credit_ledger (user_id, amount, reason, ref)
  values (p_user, -p_amount, p_reason, p_ref);

  return v_balance;
end;
$$;

create or replace function public.add_credits(p_user uuid, p_amount integer, p_reason text, p_ref text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_balance integer;
begin
  if p_amount <= 0 then
    raise exception 'invalid_amount';
  end if;

  update public.profiles
     set credits = credits + p_amount
   where id = p_user
  returning credits into v_balance;

  if not found then
    raise exception 'unknown_user';
  end if;

  insert into public.credit_ledger (user_id, amount, reason, ref)
  values (p_user, p_amount, p_reason, p_ref);

  return v_balance;
end;
$$;

revoke all on function public.spend_credits(uuid, integer, text, text) from public, anon, authenticated;
revoke all on function public.add_credits(uuid, integer, text, text)   from public, anon, authenticated;
grant execute on function public.spend_credits(uuid, integer, text, text) to service_role;
grant execute on function public.add_credits(uuid, integer, text, text)   to service_role;

-- ============ Alta de usuario: perfil + créditos de bienvenida ============

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, credits) values (new.id, 60);
  insert into public.credit_ledger (user_id, amount, reason) values (new.id, 60, 'signup');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

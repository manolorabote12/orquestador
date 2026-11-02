-- Reseñas de Google Play: la IA propone respuestas y el autor las envía (función play-resenas).
--   resena_borrador_reservar(p_user, p_project): cupo diario de borradores con IA (gratis, sin
--     tuercas; tope en settings para que nadie la use de chat). Devuelve el titulo del juego.
--   resena_anotar(...): registro de lo que el autor envió a Google (para soporte y abuso).
-- Solo el servidor (service_role) las llama; la app nunca toca estas tablas.

insert into public.settings (key, value, note) values
  ('resenas_borradores_dia', 60, 'Borradores de respuesta con IA por usuario y dia')
on conflict (key) do nothing;

create table if not exists public.resenas_borradores (
  id          bigserial primary key,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  project_id  uuid not null references public.projects (id) on delete cascade,
  coste_usd   numeric not null default 0,
  created_at  timestamptz not null default now()
);
create index if not exists resenas_borradores_user_idx on public.resenas_borradores (user_id, created_at);

create table if not exists public.resenas_respuestas (
  id          bigserial primary key,
  project_id  uuid not null references public.projects (id) on delete cascade,
  review_id   text not null,
  texto       text not null check (char_length(texto) between 1 and 350),
  created_at  timestamptz not null default now()
);
create index if not exists resenas_respuestas_idx on public.resenas_respuestas (project_id, created_at desc);

alter table public.resenas_borradores enable row level security;
alter table public.resenas_respuestas enable row level security;

create or replace function public.resena_borrador_reservar(p_user uuid, p_project uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_titulo text;
  v_id bigint;
begin
  select coalesce(nullif(pr.spec ->> 'titulo', ''), pr.title) into v_titulo
    from public.projects pr where pr.id = p_project and pr.user_id = p_user;
  if not found then raise exception 'project_not_found'; end if;
  perform pg_advisory_xact_lock(hashtext('resenas:' || p_user::text));
  if (select count(*) from public.resenas_borradores where user_id = p_user and created_at > now() - interval '1 day')
     >= public.setting('resenas_borradores_dia') then
    raise exception 'rate_limited';
  end if;
  insert into public.resenas_borradores (user_id, project_id) values (p_user, p_project) returning id into v_id;
  return jsonb_build_object('id', v_id, 'titulo', v_titulo);
end;
$$;

create or replace function public.resena_borrador_coste(p_id bigint, p_coste numeric)
returns void
language sql
security definer
set search_path = public
as $$
  update public.resenas_borradores set coste_usd = greatest(0, coalesce(p_coste, 0)) where id = p_id;
$$;

create or replace function public.resena_anotar(p_user uuid, p_project uuid, p_review text, p_texto text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.projects where id = p_project and user_id = p_user) then
    raise exception 'project_not_found';
  end if;
  insert into public.resenas_respuestas (project_id, review_id, texto) values (p_project, p_review, p_texto);
end;
$$;

revoke all on function public.resena_borrador_reservar(uuid, uuid) from public, anon, authenticated;
revoke all on function public.resena_borrador_coste(bigint, numeric) from public, anon, authenticated;
revoke all on function public.resena_anotar(uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function public.resena_borrador_reservar(uuid, uuid) to service_role;
grant execute on function public.resena_borrador_coste(bigint, numeric) to service_role;
grant execute on function public.resena_anotar(uuid, uuid, text, text) to service_role;

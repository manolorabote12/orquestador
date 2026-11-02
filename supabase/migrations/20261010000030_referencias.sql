-- Tu dibujo (o la foto de tu mascota o tu juguete) como protagonista.
-- 1 - La app sube la imagen a referencias/<user_id>/<project_id>/heroe.png (solo su carpeta).
-- 2 - La funcion heroe-dibujo la revisa con la IA (nada de fotos de personas reales, personajes
--     conocidos ni contenido no apto) y apunta aqui el resultado y una descripcion visual.
-- 3 - plan-change solo acepta 'redibujar' con referencia si esta aprobada (y es reciente).
-- 4 - El trabajador la baja y la fabrica la convierte en el personaje con el estilo del juego.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('referencias', 'referencias', false, 4194304, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do nothing;

drop policy if exists "subir mis referencias" on storage.objects;
create policy "subir mis referencias" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'referencias' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "cambiar mis referencias" on storage.objects;
create policy "cambiar mis referencias" on storage.objects
  for update to authenticated
  using (bucket_id = 'referencias' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "ver mis referencias" on storage.objects;
create policy "ver mis referencias" on storage.objects
  for select to authenticated
  using (bucket_id = 'referencias' and (storage.foldername(name))[1] = auth.uid()::text);

insert into public.settings (key, value, note) values
  ('referencias_dia', 10, 'Revisiones de dibujos (IA) por usuario y dia')
on conflict (key) do nothing;

create table if not exists public.referencias (
  project_id  uuid not null references public.projects (id) on delete cascade,
  que         text not null default 'heroe' check (que in ('heroe')),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  estado      text not null check (estado in ('pendiente', 'aprobada', 'rechazada')),
  descripcion text not null default '' check (char_length(descripcion) <= 240),
  motivo      text not null default '',
  coste_usd   numeric not null default 0,
  revisiones  integer not null default 0,
  updated_at  timestamptz not null default now(),
  primary key (project_id, que)
);
alter table public.referencias enable row level security;
create index if not exists referencias_user_idx on public.referencias (user_id, updated_at);

-- Cupo diario de revisiones (cada una es una llamada a la IA). Lo llama el servidor.
create or replace function public.referencia_reservar(p_user uuid, p_project uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.projects where id = p_project and user_id = p_user) then
    raise exception 'project_not_found';
  end if;
  perform pg_advisory_xact_lock(hashtext('referencias:' || p_user::text));
  if (select coalesce(sum(revisiones), 0) from public.referencias where user_id = p_user and updated_at > now() - interval '1 day')
     >= public.setting('referencias_dia') then
    raise exception 'rate_limited';
  end if;
  insert into public.referencias (project_id, que, user_id, estado, revisiones)
  values (p_project, 'heroe', p_user, 'pendiente', 1)
  on conflict (project_id, que) do update
    set estado = 'pendiente', descripcion = '', motivo = '', updated_at = now(),
        revisiones = case when referencias.updated_at > now() - interval '1 day' then referencias.revisiones + 1 else 1 end;
end;
$$;

create or replace function public.referencia_resultado(p_project uuid, p_ok boolean, p_descripcion text, p_motivo text, p_coste numeric)
returns void
language sql
security definer
set search_path = public
as $$
  update public.referencias
     set estado = case when p_ok then 'aprobada' else 'rechazada' end,
         descripcion = left(coalesce(p_descripcion, ''), 240), motivo = left(coalesce(p_motivo, ''), 200),
         coste_usd = coste_usd + greatest(0, coalesce(p_coste, 0)), updated_at = now()
   where project_id = p_project and que = 'heroe';
$$;

revoke all on function public.referencia_reservar(uuid, uuid) from public, anon, authenticated;
revoke all on function public.referencia_resultado(uuid, boolean, text, text, numeric) from public, anon, authenticated;
grant execute on function public.referencia_reservar(uuid, uuid) to service_role;
grant execute on function public.referencia_resultado(uuid, boolean, text, text, numeric) to service_role;

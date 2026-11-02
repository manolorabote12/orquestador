-- Orquestador: el Escaparate. Compartir un juego con un enlace que cualquiera juega en el
-- navegador (web/jugar.html?j=<id>), una galeria de la comunidad y remezclar juegos de otros.
--
--   app -> escaparate (funcion): publicar | retirar | remix   (copia archivos con la clave de servicio)
--   web y app -> escaparate_lista / escaparate_ficha / escaparate_jugada (publicos, sin sesion)
--   app -> escaparate_megusta (con sesion, uno por persona)
-- Lo publico vive en el almacen publico 'escaparate/<proyecto>/': index.pck, icono.png y ficha.json.

alter table public.projects add column if not exists remix_de uuid references public.projects (id) on delete set null;

create table if not exists public.escaparate (
  project_id   uuid primary key references public.projects (id) on delete cascade,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  titulo       text not null,
  genero       text not null default '',
  resumen      text not null default '',
  autor        text not null default '',
  version      integer not null,
  jugadas      integer not null default 0,
  megusta      integer not null default 0,
  remixes      integer not null default 0,
  oculto       boolean not null default false,
  publicado_en timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists escaparate_top_idx on public.escaparate (oculto, megusta desc, jugadas desc);
create index if not exists escaparate_nuevos_idx on public.escaparate (oculto, publicado_en desc);
alter table public.escaparate enable row level security;
-- Sin politicas: se lee con las funciones (que nunca devuelven user_id).

create table if not exists public.escaparate_megusta (
  project_id uuid not null references public.escaparate (project_id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (project_id, user_id)
);
alter table public.escaparate_megusta enable row level security;

alter table public.content_reports drop constraint if exists content_reports_tipo_check;
alter table public.content_reports add constraint content_reports_tipo_check check (tipo in ('juego', 'lanzadera', 'escaparate'));

-- 1 - Publicar / actualizar (lo llama la funcion despues de copiar los archivos).
create or replace function public.escaparate_publicar(p_user uuid, p_project uuid, p_autor text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.projects%rowtype;
begin
  select * into v from public.projects where id = p_project and user_id = p_user;
  if not found then raise exception 'project_not_found'; end if;
  if coalesce(v.files ->> 'web', '') = '' then raise exception 'no_web_build'; end if;
  insert into public.escaparate (project_id, user_id, titulo, genero, resumen, autor, version)
  values (p_project, p_user, left(v.title, 60), coalesce(v.spec ->> 'genero', ''), left(coalesce(v.spec ->> 'resumen', ''), 200),
    left(trim(coalesce(p_autor, '')), 40), v.version)
  on conflict (project_id) do update set titulo = excluded.titulo, genero = excluded.genero, resumen = excluded.resumen,
    autor = excluded.autor, version = excluded.version, updated_at = now();
end;
$$;

create or replace function public.escaparate_retirar(p_user uuid, p_project uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.escaparate where project_id = p_project and user_id = p_user;
$$;

-- 2 - Remix: un proyecto nuevo del usuario con los archivos copiados (los copia la funcion antes).
create or replace function public.escaparate_remix(p_user uuid, p_origen uuid, p_files jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_e public.escaparate%rowtype;
  v_p public.projects%rowtype;
  v_nuevo uuid;
begin
  select * into v_e from public.escaparate where project_id = p_origen and not oculto;
  if not found then raise exception 'not_found'; end if;
  if v_e.user_id = p_user then raise exception 'own_game'; end if;
  if (select count(*) from public.projects where user_id = p_user and remix_de is not null
      and created_at > now() - interval '1 day') >= 5 then
    raise exception 'daily_limit';
  end if;
  select * into v_p from public.projects where id = p_origen;
  -- Misma version que el original: la memoria del proyecto (dentro del zip) lleva ese numero.
  insert into public.projects (user_id, title, spec, files, remix_de, version)
  values (p_user, left(v_p.title || ' (remix)', 60), v_p.spec, p_files, p_origen, v_p.version)
  returning id into v_nuevo;
  insert into public.project_versions (project_id, version, spec, prompt, files)
  values (v_nuevo, v_p.version, v_p.spec, 'Remix de «' || v_p.title || '»', p_files);
  update public.escaparate set remixes = remixes + 1 where project_id = p_origen;
  return v_nuevo;
end;
$$;

-- 3 - Lectura publica (web sin sesion y app). Nunca devuelve quien es el usuario.
create or replace function public.escaparate_lista(p_orden text default 'top', p_genero text default null)
returns table (project_id uuid, titulo text, genero text, resumen text, autor text, version integer,
  jugadas integer, megusta integer, remixes integer, publicado_en timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select e.project_id, e.titulo, e.genero, e.resumen, e.autor, e.version, e.jugadas, e.megusta, e.remixes, e.publicado_en
    from public.escaparate e
   where not e.oculto and (p_genero is null or e.genero = p_genero)
   order by case when p_orden = 'nuevos' then extract(epoch from e.publicado_en) else 0 end desc,
            -- "top": me gusta y jugadas con un poco de frescura para que lo nuevo tenga hueco
            (e.megusta * 5 + e.jugadas) / power(extract(epoch from now() - e.publicado_en) / 3600 + 2, 0.8) desc
   limit 60;
$$;

create or replace function public.escaparate_ficha(p_project uuid)
returns table (project_id uuid, titulo text, genero text, resumen text, autor text, version integer,
  jugadas integer, megusta integer, remixes integer, publicado_en timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select e.project_id, e.titulo, e.genero, e.resumen, e.autor, e.version, e.jugadas, e.megusta, e.remixes, e.publicado_en
    from public.escaparate e where e.project_id = p_project and not e.oculto;
$$;

create or replace function public.escaparate_jugada(p_project uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.escaparate set jugadas = jugadas + 1 where project_id = p_project and not oculto;
$$;

create or replace function public.escaparate_megusta(p_project uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  n int;
begin
  if v_user is null then raise exception 'unknown_user'; end if;
  if not exists (select 1 from public.escaparate where project_id = p_project and not oculto) then raise exception 'not_found'; end if;
  insert into public.escaparate_megusta (project_id, user_id) values (p_project, v_user) on conflict do nothing;
  get diagnostics n = row_count;
  if n = 0 then
    delete from public.escaparate_megusta where project_id = p_project and user_id = v_user;
    update public.escaparate set megusta = greatest(megusta - 1, 0) where project_id = p_project;
  else
    update public.escaparate set megusta = megusta + 1 where project_id = p_project;
  end if;
  return (select megusta from public.escaparate where project_id = p_project);
end;
$$;

-- 4 - Denuncias: tambien las del escaparate; con 3 personas distintas se oculta solo.
create or replace function public.denunciar(p_project uuid, p_campana uuid, p_motivo text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_proj uuid := p_project;
begin
  if v_user is null then raise exception 'unknown_user'; end if;
  if p_motivo is null or char_length(trim(p_motivo)) not between 3 and 500 then raise exception 'bad_reason'; end if;
  if (select count(*) from public.content_reports where reporter = v_user and created_at > now() - interval '1 day') >= 20 then
    raise exception 'rate_limited';
  end if;
  if p_campana is not null then
    select project_id into v_proj from public.lz_campanas where id = p_campana;
    if not found then raise exception 'not_found'; end if;
    if exists (select 1 from public.content_reports where reporter = v_user and campana = p_campana) then return; end if;
    insert into public.content_reports (reporter, project_id, campana, reason, tipo)
    values (v_user, v_proj, p_campana, trim(p_motivo), 'lanzadera');
    update public.lz_campanas set oculta = true
     where id = p_campana and (select count(distinct reporter) from public.content_reports where campana = p_campana) >= 3;
  elsif exists (select 1 from public.projects where id = v_proj and user_id = v_user) then
    -- Un juego propio: lo que ha generado la IA para ti.
    insert into public.content_reports (reporter, project_id, reason, tipo) values (v_user, v_proj, trim(p_motivo), 'juego');
  elsif exists (select 1 from public.escaparate where project_id = v_proj) then
    if exists (select 1 from public.content_reports where reporter = v_user and project_id = v_proj and tipo = 'escaparate') then return; end if;
    insert into public.content_reports (reporter, project_id, reason, tipo) values (v_user, v_proj, trim(p_motivo), 'escaparate');
    update public.escaparate set oculto = true
     where project_id = v_proj and (select count(distinct reporter) from public.content_reports
       where project_id = v_proj and tipo = 'escaparate') >= 3;
  else
    raise exception 'not_found';
  end if;
end;
$$;

revoke all on function public.escaparate_publicar(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.escaparate_retirar(uuid, uuid) from public, anon, authenticated;
revoke all on function public.escaparate_remix(uuid, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.escaparate_publicar(uuid, uuid, text) to service_role;
grant execute on function public.escaparate_retirar(uuid, uuid) to service_role;
grant execute on function public.escaparate_remix(uuid, uuid, jsonb) to service_role;
grant execute on function public.escaparate_lista(text, text) to anon, authenticated;
grant execute on function public.escaparate_ficha(uuid) to anon, authenticated;
grant execute on function public.escaparate_jugada(uuid) to anon, authenticated;
revoke all on function public.escaparate_megusta(uuid) from public, anon;
grant execute on function public.escaparate_megusta(uuid) to authenticated;

-- Almacen publico de lo compartido. Solo escribe el servidor.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('escaparate', 'escaparate', true, 20971520, array['application/octet-stream', 'image/png', 'image/jpeg', 'application/json'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "leer escaparate" on storage.objects;
create policy "leer escaparate" on storage.objects for select to anon, authenticated using (bucket_id = 'escaparate');

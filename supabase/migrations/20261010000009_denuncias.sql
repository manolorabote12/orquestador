-- Orquestador: denunciar contenido (politicas de Google Play de contenido generado por IA y por
-- usuarios: hay que poder marcar contenido ofensivo sin salir de la app).
--
--   app -> denunciar(proyecto | campana, motivo): guarda la denuncia para revisarla.
--   Una campana de la Lanzadera con 3 denuncias de personas distintas se oculta sola hasta revisarla,
--   y quien denuncia deja de verla al momento.

alter table public.lz_campanas add column if not exists oculta boolean not null default false;
alter table public.content_reports add column if not exists campana uuid references public.lz_campanas (id) on delete set null;
alter table public.content_reports add column if not exists tipo text not null default 'juego'
  check (tipo in ('juego', 'lanzadera'));
create index if not exists content_reports_campana_idx on public.content_reports (campana);

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
  else
    -- Un juego propio: lo que ha generado la IA para ti.
    if not exists (select 1 from public.projects where id = v_proj and user_id = v_user) then raise exception 'not_found'; end if;
    insert into public.content_reports (reporter, project_id, reason, tipo) values (v_user, v_proj, trim(p_motivo), 'juego');
  end if;
end;
$$;
revoke all on function public.denunciar(uuid, uuid, text) from public, anon;
grant execute on function public.denunciar(uuid, uuid, text) to authenticated;

create or replace function public.lz_lista()
returns table (campana uuid, titulo text, nota text, enlace_grupo text, enlace_prueba text,
  probadores integer, faltan integer, premium boolean, created_at timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_max  int := public.setting('lz_probadores')::int + public.setting('lz_margen')::int;
  v_min  int := public.setting('lz_minimo_probando')::int;
begin
  if v_user is null then raise exception 'unknown_user'; end if;
  return query
    with c as (
      select k.*, (select count(*)::int from public.lz_probadores t where t.campana = k.id and t.estado in ('activo', 'completado')) as n,
             public.lz_premium(k.owner) as prem, public.lz_saldo(k.owner) as saldo
        from public.lz_campanas k
       where k.estado = 'abierta' and k.owner <> v_user and not k.oculta
         and not exists (select 1 from public.content_reports r where r.campana = k.id and r.reporter = v_user)
         and not exists (select 1 from public.lz_probadores t where t.campana = k.id and t.tester = v_user)
    )
    select c.id, c.titulo, c.nota, c.enlace_grupo, c.enlace_prueba, c.n,
           greatest(public.setting('lz_probadores')::int - c.n, 0), c.prem, c.created_at
      from c
     where c.n < v_max and (c.prem or public.lz_probando(c.owner) >= v_min)
     order by c.prem desc, (c.n < public.setting('lz_probadores')::int) desc, c.saldo desc, c.created_at
     limit 50;
end;
$$;

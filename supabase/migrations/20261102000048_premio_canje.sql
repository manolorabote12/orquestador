-- Canjear el premio real en la tienda: cada codigo personal (CAFE-7F3A) se guarda al ganarlo y el
-- dueno lo marca como usado desde la app. Un codigo ya canjeado no vale otra vez.
--   autor (app) -> premio_canjear (marca y dice si ya estaba usado); premio_autor cuenta los canjeados.
alter table public.juego_premios_ganados add column if not exists codigo text;
alter table public.juego_premios_ganados add column if not exists canjeado_en timestamptz;
update public.juego_premios_ganados g set codigo = public._premio_codigo(p.codigo, g.juego, g.sesion)
  from public.juego_premios p where p.juego = g.juego and g.codigo is null;
create index if not exists juego_premios_ganados_codigo on public.juego_premios_ganados (juego, codigo);

create or replace function public.premio_ganado(p_juego uuid, p_sesion text, p_nivel integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.juego_premios%rowtype;
  v_codigo text;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  select * into r from public.juego_premios where juego = p_juego and (caduca is null or caduca >= current_date);
  if not found then return null; end if;
  if p_nivel is null or p_nivel < r.tras_nivel then raise exception 'not_yet'; end if;
  v_codigo := public._premio_codigo(r.codigo, p_juego, p_sesion);
  insert into public.juego_premios_ganados (juego, sesion, codigo) values (p_juego, p_sesion, v_codigo)
  on conflict (juego, sesion) do update set codigo = coalesce(public.juego_premios_ganados.codigo, excluded.codigo);
  return jsonb_build_object('texto', r.texto, 'codigo', v_codigo, 'donde', r.donde, 'web', r.web, 'caduca', r.caduca);
end;
$$;

create or replace function public.premio_canjear(p_project uuid, p_codigo text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_juego uuid;
  g public.juego_premios_ganados%rowtype;
  v_cod text := upper(regexp_replace(coalesce(p_codigo, ''), '\s', '', 'g'));
begin
  if auth.uid() is null then raise exception 'unknown_user'; end if;
  select telemetria_id into v_juego from public.projects where id = p_project and user_id = auth.uid();
  if not found then raise exception 'project_not_found'; end if;
  if v_cod !~ '^[A-Z0-9]{3,16}-[0-9A-F]{4}$' then raise exception 'bad_code'; end if;
  select * into g from public.juego_premios_ganados where juego = v_juego and codigo = v_cod for update;
  if not found then return jsonb_build_object('estado', 'no_existe'); end if;
  if g.canjeado_en is not null then
    return jsonb_build_object('estado', 'ya_usado', 'canjeado_en', g.canjeado_en, 'ganado_en', g.created_at);
  end if;
  update public.juego_premios_ganados set canjeado_en = now() where juego = g.juego and sesion = g.sesion;
  return jsonb_build_object('estado', 'ok', 'ganado_en', g.created_at);
end;
$$;

create or replace function public.premio_autor(p_project uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_juego uuid;
  r public.juego_premios%rowtype;
begin
  select telemetria_id into v_juego from public.projects where id = p_project and user_id = auth.uid();
  if not found then raise exception 'project_not_found'; end if;
  select * into r from public.juego_premios where juego = v_juego;
  if not found then return null; end if;
  return jsonb_build_object('texto', r.texto, 'codigo', r.codigo, 'tras_nivel', r.tras_nivel, 'donde', r.donde, 'web', r.web,
    'caduca', r.caduca, 'ganados', (select count(*) from public.juego_premios_ganados g where g.juego = v_juego),
    'canjeados', (select count(*) from public.juego_premios_ganados g where g.juego = v_juego and g.canjeado_en is not null));
end;
$$;

revoke all on function public.premio_canjear(uuid, text) from public, anon;
grant execute on function public.premio_canjear(uuid, text) to authenticated;

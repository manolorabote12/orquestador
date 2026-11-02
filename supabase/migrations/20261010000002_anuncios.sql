-- Orquestador: anuncios de verdad (AdMob) en la version de tienda de cada juego.
--
-- Cada juego es una app distinta en AdMob. El autor pega en la app su ID de app y dos bloques
-- (intersticial y bonificado); se guardan en projects.admob y viajan con el trabajo de publicacion.
-- Sin ids, el juego se publica sin anuncios (la guia de Play Console lo declara asi).

alter table public.projects add column if not exists admob jsonb;

create or replace function public.set_project_admob(p_project uuid, p_app_id text, p_interstitial text, p_rewarded text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v jsonb;
begin
  if auth.uid() is null then raise exception 'unknown_user'; end if;
  if not exists (select 1 from public.projects where id = p_project and user_id = auth.uid()) then
    raise exception 'project_not_found';
  end if;
  -- Todo vacio = quitar los anuncios.
  if coalesce(p_app_id, '') = '' and coalesce(p_interstitial, '') = '' and coalesce(p_rewarded, '') = '' then
    update public.projects set admob = null where id = p_project;
    return null;
  end if;
  p_app_id := trim(p_app_id); p_interstitial := trim(p_interstitial); p_rewarded := trim(p_rewarded);
  if p_app_id !~ '^ca-app-pub-[0-9]{16}~[0-9]{10}$' then raise exception 'bad_app_id'; end if;
  if p_interstitial !~ '^ca-app-pub-[0-9]{16}/[0-9]{10}$' or p_rewarded !~ '^ca-app-pub-[0-9]{16}/[0-9]{10}$' then
    raise exception 'bad_ad_unit';
  end if;
  if split_part(p_app_id, '~', 1) <> split_part(p_interstitial, '/', 1) or split_part(p_app_id, '~', 1) <> split_part(p_rewarded, '/', 1) then
    raise exception 'mixed_accounts';
  end if;
  if p_app_id = 'ca-app-pub-3940256099942544~3347511713' then raise exception 'test_ids'; end if;
  v := jsonb_build_object('app_id', p_app_id, 'interstitial', p_interstitial, 'rewarded', p_rewarded);
  update public.projects set admob = v where id = p_project;
  return v;
end;
$$;

revoke all on function public.set_project_admob(uuid, text, text, text) from public, anon;
grant execute on function public.set_project_admob(uuid, text, text, text) to authenticated;

-- La publicacion lleva los ids de AdMob del juego (si los hay).
create or replace function public.queue_publish(p_user uuid, p_project uuid, p_modo text, p_pista text)
returns table (job_id uuid, credits_left integer, cost integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_cuenta public.play_cuentas%rowtype;
  v_play jsonb;
  v_admob jsonb;
begin
  if p_modo not in ('primer_aab', 'subir') then raise exception 'bad_mode'; end if;
  if p_pista not in ('internal', 'alpha', 'beta', 'production') then raise exception 'bad_track'; end if;
  select * into v_cuenta from public.play_cuentas where user_id = p_user;
  if not found then raise exception 'play_setup_missing'; end if;
  select play, admob into v_play, v_admob from public.projects where id = p_project and user_id = p_user;
  if not found then raise exception 'project_not_found'; end if;
  if p_modo = 'subir' and coalesce(v_play ->> 'paquete', '') = '' then raise exception 'first_aab_missing'; end if;
  if exists (select 1 from public.jobs where project_id = p_project and status in ('queued', 'running')) then
    raise exception 'project_busy';
  end if;
  select * into r from public.reserve_job(p_user, 'game_publish', jsonb_build_object(
    'modo', p_modo, 'pista', p_pista, 'estudio', v_cuenta.estudio, 'correo', v_cuenta.correo,
    'paquete', v_play ->> 'paquete', 'version_code', coalesce((v_play ->> 'version_code')::int, 0),
    'admob', v_admob));
  update public.jobs set status = 'queued', project_id = p_project where id = r.job_id;
  return query select r.job_id, r.credits_left, r.cost;
end;
$$;

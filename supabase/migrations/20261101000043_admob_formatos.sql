-- Monetizacion completa por juego (orqkit/kit/monetize.gd): ademas del intersticial y el bonificado,
-- bloques opcionales de banner y de apertura de app, y el perfil de monetizacion si el autor elige
-- otro distinto del de su tipo de juego. Todo va en projects.admob y viaja con la publicacion.
drop function if exists public.set_project_admob(uuid, text, text, text);

create or replace function public.set_project_admob(p_project uuid, p_app_id text, p_interstitial text, p_rewarded text,
  p_banner text default '', p_app_open text default '', p_perfil text default '')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v jsonb;
  v_cuenta text;
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
  p_banner := trim(coalesce(p_banner, '')); p_app_open := trim(coalesce(p_app_open, '')); p_perfil := trim(coalesce(p_perfil, ''));
  if p_app_id !~ '^ca-app-pub-[0-9]{16}~[0-9]{10}$' then raise exception 'bad_app_id'; end if;
  if p_interstitial !~ '^ca-app-pub-[0-9]{16}/[0-9]{10}$' or p_rewarded !~ '^ca-app-pub-[0-9]{16}/[0-9]{10}$'
     or (p_banner <> '' and p_banner !~ '^ca-app-pub-[0-9]{16}/[0-9]{10}$')
     or (p_app_open <> '' and p_app_open !~ '^ca-app-pub-[0-9]{16}/[0-9]{10}$') then
    raise exception 'bad_ad_unit';
  end if;
  v_cuenta := split_part(p_app_id, '~', 1);
  if v_cuenta <> split_part(p_interstitial, '/', 1) or v_cuenta <> split_part(p_rewarded, '/', 1)
     or (p_banner <> '' and v_cuenta <> split_part(p_banner, '/', 1))
     or (p_app_open <> '' and v_cuenta <> split_part(p_app_open, '/', 1)) then
    raise exception 'mixed_accounts';
  end if;
  if p_app_id = 'ca-app-pub-3940256099942544~3347511713' then raise exception 'test_ids'; end if;
  if p_perfil not in ('', 'hipercasual', 'puzle', 'arcade', 'estrategia', 'idle', 'tablero', 'casino') then
    raise exception 'bad_profile';
  end if;
  v := jsonb_build_object('app_id', p_app_id, 'interstitial', p_interstitial, 'rewarded', p_rewarded);
  if p_banner <> '' then v := v || jsonb_build_object('banner', p_banner); end if;
  if p_app_open <> '' then v := v || jsonb_build_object('app_open', p_app_open); end if;
  if p_perfil <> '' then v := v || jsonb_build_object('perfil', p_perfil); end if;
  update public.projects set admob = v where id = p_project;
  return v;
end;
$$;

revoke all on function public.set_project_admob(uuid, text, text, text, text, text, text) from public, anon;
grant execute on function public.set_project_admob(uuid, text, text, text, text, text, text) to authenticated;

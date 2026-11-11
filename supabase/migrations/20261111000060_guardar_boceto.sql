-- Guardar gratis el boceto (11 de noviembre de 2026): algo tuyo que conservar sin pagar.
--
-- La vista previa gratis ya deja un boceto jugable. Con «Guardar gratis» ese boceto pasa a Mis juegos
-- como un juego en borrador (files.borrador = true): se juega en la app con los dibujos provisionales.
-- No tiene APK, ficha ni taller; desde el se fabrica el juego completo (queue_game con su vista previa).
-- No gasta nada en la fabrica: solo apunta el boceto que ya existia. Hasta 3 borradores por persona.

create or replace function public.guardar_boceto(p_preview uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_job public.jobs%rowtype;
  v_diseno jsonb;
  v_files jsonb;
  v_project uuid;
begin
  if v_user is null then raise exception 'unknown_user'; end if;
  select * into v_job from public.jobs
   where id = p_preview and user_id = v_user and kind = 'game_preview' and status = 'done' for update;
  if not found then raise exception 'bad_preview'; end if;
  if v_job.result ? 'guardado' then return (v_job.result ->> 'guardado')::uuid; end if;
  v_diseno := v_job.result -> 'diseno';
  if v_diseno is null or not (v_job.result ? 'boceto') then raise exception 'bad_preview'; end if;
  if (select count(*) from public.projects where user_id = v_user and files ->> 'borrador' = 'true') >= 3 then
    raise exception 'too_many_drafts';
  end if;
  v_files := jsonb_build_object('web', v_job.result ->> 'boceto', 'capturas', '[]'::jsonb, 'version', 1,
    'borrador', true, 'preview', p_preview, 'idea', coalesce(v_job.detail ->> 'idea', ''));
  insert into public.projects (user_id, title, spec, files)
  values (v_user, left(coalesce(v_diseno ->> 'titulo', 'Mi boceto'), 60), v_diseno, v_files)
  returning id into v_project;
  insert into public.project_versions (project_id, version, spec, prompt, files)
  values (v_project, 1, v_diseno, coalesce(v_job.detail ->> 'idea', ''), v_files);
  -- El boceto ya es de un juego guardado: sale de la limpieza de vistas previas (que mira result.boceto).
  update public.jobs set result = (result - 'boceto') || jsonb_build_object('guardado', v_project) where id = p_preview;
  return v_project;
end;
$$;

revoke all on function public.guardar_boceto(uuid) from public, anon;
grant execute on function public.guardar_boceto(uuid) to authenticated;

-- Fabricar el juego completo desde un borrador guardado: su vista previa vale aunque pasen los 2 dias.
create or replace function public.queue_game(p_user uuid, p_idea text, p_preview uuid default null)
returns table (job_id uuid, credits_left integer, cost integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_detalle jsonb := jsonb_build_object('idea', p_idea);
  v_diseno jsonb;
begin
  if char_length(coalesce(p_idea, '')) not between 15 and 700 then
    raise exception 'bad_idea';
  end if;
  if p_preview is not null then
    select result -> 'diseno' into v_diseno from public.jobs
     where id = p_preview and user_id = p_user
       and ((kind = 'game_preview' and status = 'done') or (kind = 'game' and status = 'failed'))
       and (created_at > now() - interval '2 days' or result ? 'guardado');
    if v_diseno is null or jsonb_typeof(v_diseno) <> 'object' then raise exception 'bad_preview'; end if;
    v_detalle := v_detalle || jsonb_build_object('diseno', v_diseno, 'preview', p_preview);
  end if;
  select * into r from public.reserve_job(p_user, 'game', v_detalle);
  update public.jobs set status = 'queued' where id = r.job_id;
  return query select r.job_id, r.credits_left, r.cost;
end;
$$;

revoke all on function public.queue_game(uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.queue_game(uuid, text, uuid) to service_role;

-- Borrar un borrador (para dejar sitio a otro). El boceto vuelve a su vista previa y la limpieza
-- de siempre (limpiar_previas) borra el archivo cuando le toque.
create or replace function public.borrar_boceto(p_project uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_files jsonb;
begin
  if v_user is null then raise exception 'unknown_user'; end if;
  select files into v_files from public.projects
   where id = p_project and user_id = v_user and files ->> 'borrador' = 'true' for update;
  if not found then raise exception 'project_not_found'; end if;
  update public.jobs set result = (result - 'guardado') || jsonb_build_object('boceto', v_files ->> 'web')
   where id = (v_files ->> 'preview')::uuid and user_id = v_user and kind = 'game_preview';
  delete from public.projects where id = p_project;
end;
$$;

revoke all on function public.borrar_boceto(uuid) from public, anon;
grant execute on function public.borrar_boceto(uuid) to authenticated;

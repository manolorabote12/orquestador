-- Perfil de creador: lo que has hecho y lo que ha conseguido (para el nivel y las insignias de la
-- app). Solo lectura y solo de uno mismo.

create or replace function public.perfil_creador()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'juegos', (select count(*) from public.projects where user_id = auth.uid()),
    'publicados', (select count(*) from public.escaparate where user_id = auth.uid() and not oculto),
    'jugadas', coalesce((select sum(jugadas) from public.escaparate where user_id = auth.uid()), 0),
    'megusta', coalesce((select sum(megusta) from public.escaparate where user_id = auth.uid()), 0),
    'remixes', coalesce((select sum(remixes) from public.escaparate where user_id = auth.uid()), 0),
    'en_tienda', (select count(*) from public.projects where user_id = auth.uid() and play ->> 'estado' = 'subido'),
    'podios', (select count(*) from public.credit_ledger where user_id = auth.uid() and reason = 'weekly_challenge'),
    'victorias', (select count(*) from public.credit_ledger where user_id = auth.uid() and reason = 'weekly_challenge' and ref like '%:1')
  ) where auth.uid() is not null;
$$;

revoke all on function public.perfil_creador() from public, anon;
grant execute on function public.perfil_creador() to authenticated;

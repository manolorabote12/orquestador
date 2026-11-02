-- Guerra de clanes semanal (liga de aldeas): cada estrella ganada en un asalto suma para el clan
-- del atacante esa semana. Los miembros que aportaron estrellas a uno de los 3 primeros clanes
-- de la semana pasada cobran premio una vez (250 / 150 / 80 monedas).
--   juego (anon) -> clan_guerra: semana, segundos que quedan, top de clanes, tu clan y tus estrellas,
--                   y tu premio sin cobrar.  clan_guerra_cobrar: cobra ese premio (0 si no hay).
-- El clan se apunta al cerrar el asalto: cambiarse de clan despues no se lleva las estrellas.

alter table public.liga_ataques add column if not exists clan bigint references public.liga_clanes (id) on delete set null;
create index if not exists liga_ataques_guerra_idx on public.liga_ataques (juego, clan, cerrado_at) where clan is not null;

create table if not exists public.guerra_cobros (
  juego      uuid not null,
  semana     text not null,
  sesion     text not null,
  premio     integer not null,
  created_at timestamptz not null default now(),
  primary key (juego, semana, sesion)
);
alter table public.guerra_cobros enable row level security;

create or replace function public._guerra_apuntar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.cerrado_at is not null and old.cerrado_at is null then
    select clan into new.clan from public.liga_aldeas where id = new.atacante;
  end if;
  return new;
end;
$$;
drop trigger if exists guerra_apuntar on public.liga_ataques;
create trigger guerra_apuntar before update on public.liga_ataques for each row execute function public._guerra_apuntar();

-- Estrellas por clan en una semana ('IYYY-"S"IW', como el torneo).
create or replace function public._guerra_tabla(p_juego uuid, p_semana text)
returns table (clan bigint, nombre text, estrellas integer, posicion integer)
language sql
stable
security definer
set search_path = public
as $$
  select k.id, k.nombre, sum(t.estrellas)::integer,
         (rank() over (order by sum(t.estrellas) desc, min(t.cerrado_at)))::integer
    from public.liga_ataques t join public.liga_clanes k on k.id = t.clan
   where t.juego = p_juego and t.cerrado_at is not null and coalesce(t.estrellas, 0) > 0
     and public.torneo_semana(t.cerrado_at) = p_semana
   group by k.id, k.nombre;
$$;

create or replace function public._guerra_premio(p_juego uuid, p_sesion text, p_semana text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_puesto integer;
begin
  if exists (select 1 from public.guerra_cobros where juego = p_juego and semana = p_semana and sesion = p_sesion) then
    return jsonb_build_object('premio', 0, 'puesto', 0);
  end if;
  -- El mejor puesto de un clan al que aportaste estrellas esa semana.
  select min(g.posicion) into v_puesto
    from public._guerra_tabla(p_juego, p_semana) g
   where g.posicion <= 3 and exists (
     select 1 from public.liga_ataques t join public.liga_aldeas a on a.id = t.atacante
      where t.juego = p_juego and t.clan = g.clan and a.sesion = p_sesion and coalesce(t.estrellas, 0) > 0
        and t.cerrado_at is not null and public.torneo_semana(t.cerrado_at) = p_semana);
  return jsonb_build_object('premio', case v_puesto when 1 then 250 when 2 then 150 when 3 then 80 else 0 end,
    'puesto', coalesce(v_puesto, 0));
end;
$$;

create or replace function public.clan_guerra(p_juego uuid, p_sesion text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_semana text := public.torneo_semana();
  v_fin timestamptz := date_trunc('week', now() at time zone 'UTC') at time zone 'UTC' + interval '7 days';
  yo public.liga_aldeas%rowtype;
  v_mio jsonb := null;
  v_premio jsonb;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  select * into yo from public.liga_aldeas where juego = p_juego and sesion = p_sesion;
  if found and yo.clan is not null then
    select jsonb_build_object('nombre', k.nombre, 'puesto', coalesce(g.posicion, 0), 'estrellas', coalesce(g.estrellas, 0),
             'tus_estrellas', (select coalesce(sum(t.estrellas), 0) from public.liga_ataques t
                                where t.atacante = yo.id and t.clan = yo.clan and t.cerrado_at is not null
                                  and public.torneo_semana(t.cerrado_at) = v_semana))
      into v_mio
      from public.liga_clanes k left join public._guerra_tabla(p_juego, v_semana) g on g.clan = k.id
     where k.id = yo.clan;
  end if;
  v_premio := public._guerra_premio(p_juego, p_sesion, public.torneo_semana(now() - interval '7 days'));
  return jsonb_build_object('semana', v_semana, 'segundos', greatest(extract(epoch from v_fin - now())::integer, 0),
    'top', (select coalesce(jsonb_agg(jsonb_build_object('posicion', g.posicion, 'nombre', g.nombre, 'estrellas', g.estrellas,
              'tuyo', g.clan = yo.clan) order by g.posicion), '[]'::jsonb)
              from (select * from public._guerra_tabla(p_juego, v_semana) order by posicion limit 10) g),
    'clan', v_mio, 'premio', (v_premio ->> 'premio')::integer, 'puesto_pasado', (v_premio ->> 'puesto')::integer);
end;
$$;

create or replace function public.clan_guerra_cobrar(p_juego uuid, p_sesion text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_semana text := public.torneo_semana(now() - interval '7 days');
  v_premio integer;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  v_premio := (public._guerra_premio(p_juego, p_sesion, v_semana) ->> 'premio')::integer;
  if v_premio <= 0 then return 0; end if;
  insert into public.guerra_cobros (juego, semana, sesion, premio) values (p_juego, v_semana, p_sesion, v_premio)
  on conflict do nothing;
  if not found then return 0; end if;
  return v_premio;
end;
$$;

create or replace function public._guerra_borrar_juego()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.guerra_cobros where juego = old.telemetria_id;
  return old;
end;
$$;
drop trigger if exists guerra_borrar_juego on public.projects;
create trigger guerra_borrar_juego after delete on public.projects for each row execute function public._guerra_borrar_juego();

revoke all on function public._guerra_apuntar() from public, anon, authenticated;
revoke all on function public._guerra_tabla(uuid, text) from public, anon, authenticated;
revoke all on function public._guerra_premio(uuid, text, text) from public, anon, authenticated;
revoke all on function public._guerra_borrar_juego() from public, anon, authenticated;
grant execute on function public.clan_guerra(uuid, text) to anon, authenticated;
grant execute on function public.clan_guerra_cobrar(uuid, text) to anon, authenticated;

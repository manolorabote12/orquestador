-- Invita a un amigo y ranking semanal del Escaparate.
--
-- Invitaciones: cada cuenta tiene un codigo (se crea al pedirlo). Quien se acaba de registrar
-- (7 dias como mucho y sin juegos todavia) puede apuntar el codigo de quien le invito. Cuando el
-- invitado FABRICA SU PRIMER JUEGO (gasto real de tuercas, no solo registrarse), los dos ganan
-- 'invitacion_tuercas'. Tope de invitaciones pagadas por persona y mes (contra cuentas falsas).
--   mi_invitacion()            -> { codigo, invitados, pagados, ganadas, por_amigo }
--   usar_invitacion(p_codigo)  -> 'ok' (errores: bad_code, own_code, too_late, already_invited)
-- El premio lo da el servidor (disparador al crear el primer proyecto): la app nunca lo pide.
--
-- Ranking semanal: jugadas y me gusta por dia; escaparate_lista('semana') ordena por los
-- ultimos 7 dias (los me gusta valen mas: son uno por persona; las jugadas, con raiz cuadrada).

insert into public.settings (key, value, note) values
  ('invitacion_tuercas', 30, 'Tuercas para quien invita y para el invitado cuando este fabrica su primer juego'),
  ('invitaciones_mes', 20, 'Invitaciones pagadas como mucho por persona y mes')
on conflict (key) do nothing;

alter table public.profiles add column if not exists codigo_invitacion text unique;
alter table public.profiles add column if not exists invitado_por uuid references public.profiles (id) on delete set null;
alter table public.profiles add column if not exists invitacion_pagada boolean not null default false;
create index if not exists profiles_invitado_por_idx on public.profiles (invitado_por);

create or replace function public.mi_invitacion()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_codigo text;
  v_letras text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  i int;
begin
  if v_user is null then raise exception 'unknown_user'; end if;
  select codigo_invitacion into v_codigo from public.profiles where id = v_user;
  while v_codigo is null loop
    v_codigo := '';
    for i in 1..7 loop
      v_codigo := v_codigo || substr(v_letras, 1 + floor(random() * length(v_letras))::int, 1);
    end loop;
    begin
      update public.profiles set codigo_invitacion = v_codigo where id = v_user and codigo_invitacion is null;
    exception when unique_violation then
      v_codigo := null;
    end;
  end loop;
  return jsonb_build_object(
    'codigo', v_codigo,
    'invitados', (select count(*) from public.profiles where invitado_por = v_user),
    'pagados', (select count(*) from public.profiles where invitado_por = v_user and invitacion_pagada),
    'ganadas', (select coalesce(sum(amount), 0) from public.credit_ledger where user_id = v_user and reason = 'invite'),
    'por_amigo', public.setting('invitacion_tuercas')::int,
    'me_invito', (select invitado_por is not null from public.profiles where id = v_user));
end;
$$;

create or replace function public.usar_invitacion(p_codigo text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_de uuid;
  v_perfil record;
begin
  if v_user is null then raise exception 'unknown_user'; end if;
  select id into v_de from public.profiles where codigo_invitacion = upper(trim(coalesce(p_codigo, '')));
  if v_de is null then raise exception 'bad_code'; end if;
  if v_de = v_user then raise exception 'own_code'; end if;
  select invitado_por, created_at into v_perfil from public.profiles where id = v_user for update;
  if v_perfil.invitado_por is not null then raise exception 'already_invited'; end if;
  if v_perfil.created_at < now() - interval '7 days' or exists (select 1 from public.projects where user_id = v_user) then
    raise exception 'too_late';
  end if;
  -- Nada de invitarse en circulo (A invita a B y B a A).
  if exists (select 1 from public.profiles where id = v_de and invitado_por = v_user) then raise exception 'own_code'; end if;
  update public.profiles set invitado_por = v_de where id = v_user;
  return 'ok';
end;
$$;

-- El premio: al crear el primer proyecto del invitado (la fabrica solo crea proyectos tras un
-- juego fabricado y cobrado).
create or replace function public.pagar_invitacion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_de uuid;
  v_n integer := public.setting('invitacion_tuercas')::integer;
begin
  select invitado_por into v_de from public.profiles where id = new.user_id and not invitacion_pagada and invitado_por is not null for update;
  if v_de is null or new.remix_de is not null then return new; end if;
  if (select count(*) from public.projects where user_id = new.user_id) > 1 then return new; end if;
  update public.profiles set invitacion_pagada = true where id = new.user_id;
  if (select count(*) from public.credit_ledger where user_id = v_de and reason = 'invite' and created_at > now() - interval '30 days')
     >= public.setting('invitaciones_mes') then
    return new;    -- el invitado tampoco cobra: asi no compensa crear cuentas en cadena
  end if;
  update public.profiles set credits = credits + v_n where id in (v_de, new.user_id);
  insert into public.credit_ledger (user_id, amount, reason, ref) values
    (v_de, v_n, 'invite', new.user_id::text), (new.user_id, v_n, 'invite', v_de::text);
  return new;
end;
$$;

drop trigger if exists pagar_invitacion on public.projects;
create trigger pagar_invitacion after insert on public.projects
  for each row execute function public.pagar_invitacion();

revoke all on function public.mi_invitacion() from public, anon;
revoke all on function public.usar_invitacion(text) from public, anon;
revoke all on function public.pagar_invitacion() from public, anon, authenticated;
grant execute on function public.mi_invitacion() to authenticated;
grant execute on function public.usar_invitacion(text) to authenticated;

-- ------------------------------------------------------------------ ranking semanal

create table if not exists public.escaparate_dia (
  project_id uuid not null references public.escaparate (project_id) on delete cascade,
  dia        date not null default (now() at time zone 'UTC')::date,
  jugadas    integer not null default 0,
  megusta    integer not null default 0,
  primary key (project_id, dia)
);
alter table public.escaparate_dia enable row level security;

create or replace function public.escaparate_jugada(p_project uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.escaparate set jugadas = jugadas + 1 where project_id = p_project and not oculto;
  if found then
    insert into public.escaparate_dia (project_id, jugadas) values (p_project, 1)
      on conflict (project_id, dia) do update set jugadas = escaparate_dia.jugadas + 1;
  end if;
end;
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
  d int;
begin
  if v_user is null then raise exception 'unknown_user'; end if;
  if not exists (select 1 from public.escaparate where project_id = p_project and not oculto) then raise exception 'not_found'; end if;
  insert into public.escaparate_megusta (project_id, user_id) values (p_project, v_user) on conflict do nothing;
  get diagnostics n = row_count;
  if n = 0 then
    delete from public.escaparate_megusta where project_id = p_project and user_id = v_user;
    update public.escaparate set megusta = greatest(megusta - 1, 0) where project_id = p_project;
    d := -1;
  else
    update public.escaparate set megusta = megusta + 1 where project_id = p_project;
    d := 1;
  end if;
  insert into public.escaparate_dia (project_id, megusta) values (p_project, greatest(d, 0))
    on conflict (project_id, dia) do update set megusta = greatest(escaparate_dia.megusta + d, 0);
  return (select megusta from public.escaparate where project_id = p_project);
end;
$$;

create or replace function public.escaparate_lista(p_orden text default 'top', p_genero text default null)
returns table (project_id uuid, titulo text, genero text, resumen text, autor text, version integer,
  jugadas integer, megusta integer, remixes integer, publicado_en timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  with semana as (
    select d.project_id, sum(d.jugadas) as j, sum(d.megusta) as m
      from public.escaparate_dia d
     where d.dia > (now() at time zone 'UTC')::date - 7
     group by d.project_id
  )
  select e.project_id, e.titulo, e.genero, e.resumen, e.autor, e.version, e.jugadas, e.megusta, e.remixes, e.publicado_en
    from public.escaparate e
    left join semana s on s.project_id = e.project_id
   where not e.oculto and (p_genero is null or e.genero = p_genero)
     and (p_orden <> 'semana' or s.project_id is not null)
   order by case when p_orden = 'nuevos' then extract(epoch from e.publicado_en) else 0 end desc,
            case when p_orden = 'semana' then coalesce(s.m, 0) * 10 + sqrt(coalesce(s.j, 0)) * 5 else 0 end desc,
            -- "top": me gusta y jugadas con un poco de frescura para que lo nuevo tenga hueco
            (e.megusta * 5 + e.jugadas) / power(extract(epoch from now() - e.publicado_en) / 3600 + 2, 0.8) desc
   limit case when p_orden = 'semana' then 20 else 60 end;
$$;

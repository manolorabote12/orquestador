-- Amigos: cada dispositivo tiene un codigo por juego; con el codigo de otro lo sigues y ves sus
-- marcas en la clasificacion de cada nivel ("Amigos"). Sin nombres reales: solo el apodo.
--   amigo_codigo (tu codigo), amigo_anadir (con el codigo de otro, hasta 50), amigo_quitar y
--   amigos_top (la clasificacion de un nivel solo con tus amigos y tu).

create table if not exists public.amigos_codigos (
  juego   uuid not null,
  sesion  text not null,
  codigo  text not null,
  primary key (juego, sesion),
  unique (juego, codigo)
);
alter table public.amigos_codigos enable row level security;

create table if not exists public.amigos (
  juego      uuid not null,
  sesion     text not null,
  amigo      text not null,
  created_at timestamptz not null default now(),
  primary key (juego, sesion, amigo)
);
alter table public.amigos enable row level security;

create or replace function public.amigo_codigo(p_juego uuid, p_sesion text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v text;
begin
  if p_sesion is null or p_sesion !~ '^[0-9a-f]{16}$' then raise exception 'bad_session'; end if;
  if not exists (select 1 from public.projects where telemetria_id = p_juego) then raise exception 'unknown_game'; end if;
  select codigo into v from public.amigos_codigos where juego = p_juego and sesion = p_sesion;
  if v is not null then return v; end if;
  loop
    v := translate(upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6)), '01', 'KM');
    begin
      insert into public.amigos_codigos (juego, sesion, codigo) values (p_juego, p_sesion, v);
      return v;
    exception when unique_violation then
      -- Codigo repetido (raro): se prueba otro.
      null;
    end;
  end loop;
end;
$$;

create or replace function public.amigo_anadir(p_juego uuid, p_sesion text, p_codigo text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_amigo text;
  v_alias text;
begin
  perform public.amigo_codigo(p_juego, p_sesion);
  select sesion into v_amigo from public.amigos_codigos where juego = p_juego and codigo = upper(trim(coalesce(p_codigo, '')));
  if v_amigo is null then raise exception 'unknown_code'; end if;
  if v_amigo = p_sesion then raise exception 'own_code'; end if;
  if (select count(*) from public.amigos where juego = p_juego and sesion = p_sesion) >= 50 then raise exception 'too_many'; end if;
  insert into public.amigos (juego, sesion, amigo) values (p_juego, p_sesion, v_amigo) on conflict do nothing;
  select alias into v_alias from public.marcadores where juego = p_juego and sesion = v_amigo and not oculta order by updated_at desc limit 1;
  return jsonb_build_object('alias', coalesce(v_alias, ''));
end;
$$;

create or replace function public.amigo_quitar(p_juego uuid, p_sesion text, p_codigo text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.amigos a using public.amigos_codigos c
   where a.juego = p_juego and a.sesion = p_sesion and c.juego = p_juego and c.codigo = upper(trim(p_codigo)) and a.amigo = c.sesion;
$$;

create or replace function public.amigos_top(p_juego uuid, p_sesion text, p_nivel integer)
returns table (posicion integer, alias text, puntos integer, tuyo boolean)
language sql
stable
security definer
set search_path = public
as $$
  select (rank() over (order by m.puntos desc))::integer, m.alias, m.puntos, m.sesion = p_sesion
    from public.marcadores m
   where m.juego = p_juego and m.nivel = p_nivel and not m.oculta
     and (m.sesion = p_sesion or m.sesion in (select amigo from public.amigos where juego = p_juego and sesion = p_sesion))
   order by m.puntos desc
   limit 51;
$$;

create or replace function public._amigos_borrar_juego()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.amigos where juego = old.telemetria_id;
  delete from public.amigos_codigos where juego = old.telemetria_id;
  return old;
end;
$$;
drop trigger if exists amigos_borrar_juego on public.projects;
create trigger amigos_borrar_juego after delete on public.projects for each row execute function public._amigos_borrar_juego();

revoke all on function public._amigos_borrar_juego() from public, anon, authenticated;
grant execute on function public.amigo_codigo(uuid, text) to anon, authenticated;
grant execute on function public.amigo_anadir(uuid, text, text) to anon, authenticated;
grant execute on function public.amigo_quitar(uuid, text, text) to anon, authenticated;
grant execute on function public.amigos_top(uuid, text, integer) to anon, authenticated;

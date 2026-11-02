-- Karts 3D online: los juegos de genero "karts" tienen salas en directo (hasta 4 pilotos, los
-- huecos de la parrilla los ocupan bots). Carrera de todos contra todos con trofeos: el puesto
-- que se anota es el puesto entre las personas de la sala (1-4), no contando los bots.
--   * _arena_niveles: tambien los juegos de karts (el resto de la arena ya sirve tal cual).

create or replace function public._arena_niveles(p_juego uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select case when coalesce(spec ->> 'genero', '') in ('arena', 'royale', 'zombis', 'karts')
    then greatest(coalesce(jsonb_array_length(case when jsonb_typeof(spec -> 'niveles') = 'array' then spec -> 'niveles' end), 1), 1)
    end
  from public.projects where telemetria_id = p_juego;
$$;

revoke all on function public._arena_niveles(uuid) from public, anon, authenticated;

\set ON_ERROR_STOP 1
-- Un juego que falla en la fabrica se devuelve siempre; lo barato sigue con su tope diario.
do $$
declare
  u uuid; j uuid; i integer; antes integer; devuelto boolean;
begin
  insert into auth.users (email, email_confirmed_at) values ('mala.suerte@example.com', now()) returning id into u;
  update public.profiles set credits = 1000 where id = u;
  antes := (select credits from public.profiles where id = u);
  -- 5 juegos fallidos el mismo dia: los 5 se devuelven (antes el 4o y el 5o no).
  for i in 1..5 loop
    insert into public.jobs (user_id, kind, cost, status, started_at) values (u, 'game', 80, 'running', now()) returning id into j;
    update public.profiles set credits = credits - 80 where id = u;
    devuelto := public.fail_job(j, 'fallo de la fabrica', 0.30, true);
    assert devuelto, 'juego ' || i || ' devuelto';
  end loop;
  assert (select credits from public.profiles where id = u) = antes, 'todas las tuercas de vuelta';
  -- Un cambio del taller tambien.
  insert into public.jobs (user_id, kind, cost, status, started_at) values (u, 'game_change', 8, 'running', now()) returning id into j;
  assert public.fail_job(j, 'fallo', 0.01, true), 'cambio devuelto';
  -- Lo barato (charla) mantiene el tope de max_refunds_per_day.
  for i in 1..(public.setting('max_refunds_per_day')::int) loop
    insert into public.jobs (user_id, kind, cost, status, started_at) values (u, 'design', 2, 'running', now()) returning id into j;
    assert public.fail_job(j, 'fallo', 0.01, true), 'barato dentro del tope';
  end loop;
  insert into public.jobs (user_id, kind, cost, status, started_at) values (u, 'design', 2, 'running', now()) returning id into j;
  assert not public.fail_job(j, 'fallo', 0.01, true), 'barato por encima del tope no se devuelve';
  -- Con p_refund = false (culpa del jugador) nada.
  insert into public.jobs (user_id, kind, cost, status, started_at) values (u, 'game', 80, 'running', now()) returning id into j;
  assert not public.fail_job(j, 'culpa suya', 0.0, false), 'sin devolucion si no es nuestro';
  assert not has_function_privilege('authenticated', 'public.fail_job(uuid, text, numeric, boolean)', 'execute');
  raise notice 'devoluciones OK';
end;
$$;

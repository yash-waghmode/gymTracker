-- Additive solo product support. All callable functions run as the caller under RLS.
alter table public.workouts add column title text not null default 'Workout'
  check (char_length(btrim(title)) between 1 and 120);
update public.workouts w set title = s.title
  from public.workout_sessions s where s.id = w.session_id and s.title is not null;

insert into public.exercises (name) values
  ('Barbell bench press'), ('Barbell squat'), ('Deadlift'),
  ('Romanian deadlift'), ('Overhead press'), ('Barbell row'),
  ('Dumbbell bench press'), ('Incline dumbbell press'), ('Dumbbell row'),
  ('Lateral raise'), ('Biceps curl'), ('Hammer curl'), ('Triceps pushdown'),
  ('Lat pulldown'), ('Seated cable row'), ('Pull-up'), ('Push-up'),
  ('Leg press'), ('Leg extension'), ('Leg curl'), ('Calf raise'),
  ('Bulgarian split squat'), ('Walking lunge'), ('Hip thrust'), ('Cable crunch')
on conflict do nothing;

create function public.save_routine(p_id uuid, p_name text, p_exercises uuid[])
returns uuid language plpgsql security invoker set search_path = '' as $$
declare result_id uuid;
begin
  if auth.uid() is null then raise insufficient_privilege; end if;
  if p_name is null or char_length(btrim(p_name)) not between 1 and 120
    or p_exercises is null or cardinality(p_exercises) > 50 then
    raise exception 'Invalid routine' using errcode = '22023';
  end if;
  if p_id is null then
    insert into public.routines (owner_id, name) values (auth.uid(), btrim(p_name)) returning id into result_id;
  else
    update public.routines set name = btrim(p_name) where id = p_id and owner_id = auth.uid() returning id into result_id;
    if result_id is null then raise insufficient_privilege; end if;
    delete from public.routine_exercises where routine_id = result_id;
  end if;
  insert into public.routine_exercises (routine_id, owner_id, exercise_id, position)
    select result_id, auth.uid(), exercise_id, ordinality - 1
    from unnest(p_exercises) with ordinality as items(exercise_id, ordinality);
  return result_id;
end;
$$;

create function public.start_workout(p_routine uuid default null)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare result_id uuid; session_id uuid; workout_title text := 'Free workout';
begin
  if auth.uid() is null then raise insufficient_privilege; end if;
  -- Serialize repeated taps, retries and starts from multiple tabs per user.
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));
  select id into result_id from public.workouts where owner_id = auth.uid() and completed_at is null order by started_at limit 1;
  if result_id is not null then return result_id; end if;
  if p_routine is not null then
    select name into workout_title from public.routines where id = p_routine and owner_id = auth.uid() for update;
    if workout_title is null then raise insufficient_privilege; end if;
  end if;
  insert into public.workout_sessions (created_by, title, started_at)
    values (auth.uid(), workout_title, now()) returning id into session_id;
  insert into public.workouts (session_id, owner_id, routine_id, title)
    values (session_id, auth.uid(), p_routine, workout_title) returning id into result_id;
  insert into public.workout_exercises (workout_id, owner_id, exercise_id, position)
    select result_id, auth.uid(), exercise_id, position from public.routine_exercises where routine_id = p_routine order by position;
  return result_id;
end;
$$;

create function public.change_workout(
  p_workout uuid, p_operation text, p_target uuid default null,
  p_weight numeric default null, p_reps integer default null
)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare w public.workouts; target_id uuid; next_position integer;
begin
  select * into w from public.workouts where id = p_workout and owner_id = auth.uid() for update;
  if w.id is null then raise insufficient_privilege; end if;
  if w.completed_at is not null then
    if p_operation = 'finish' then return w.id; end if;
    raise exception 'Workout is already finished' using errcode = '22023';
  end if;
  if p_operation = 'add_exercise' then
    select coalesce(max(position), -1) + 1 into next_position from public.workout_exercises where workout_id = w.id;
    if next_position >= 50 then raise exception 'Exercise limit reached' using errcode = '22023'; end if;
    insert into public.workout_exercises (workout_id, owner_id, exercise_id, position)
      values (w.id, auth.uid(), p_target, next_position) returning id into target_id;
  elsif p_operation in ('add_set', 'edit_set', 'delete_set') then
    if p_operation = 'add_set' then
      select id into target_id from public.workout_exercises where id = p_target and workout_id = w.id;
    else
      select s.id into target_id from public.workout_sets s join public.workout_exercises e on e.id = s.workout_exercise_id
        where s.id = p_target and e.workout_id = w.id;
    end if;
    if target_id is null then raise insufficient_privilege; end if;
    if p_operation <> 'delete_set' and (p_weight is null or p_weight < 0 or p_weight > 1500
      or p_weight <> round(p_weight, 3) or p_reps is null or p_reps not between 1 and 1000) then
      raise exception 'Invalid weight or reps' using errcode = '22023';
    end if;
    if p_operation = 'add_set' then
      select coalesce(max(position), -1) + 1 into next_position from public.workout_sets where workout_exercise_id = target_id;
      if next_position >= 100 then raise exception 'Set limit reached' using errcode = '22023'; end if;
      insert into public.workout_sets (workout_exercise_id, owner_id, position, weight_kg, reps)
        values (target_id, auth.uid(), next_position, p_weight, p_reps) returning id into target_id;
    elsif p_operation = 'edit_set' then
      update public.workout_sets set weight_kg = p_weight, reps = p_reps where id = target_id;
    else
      delete from public.workout_sets where id = target_id;
    end if;
  elsif p_operation = 'finish' then
    if not exists (select 1 from public.workout_sets s join public.workout_exercises e on e.id = s.workout_exercise_id where e.workout_id = w.id) then
      raise exception 'Log at least one set before finishing' using errcode = '22023';
    end if;
    update public.workouts set completed_at = now() where id = w.id;
    target_id := w.id;
  else
    raise exception 'Unknown operation' using errcode = '22023';
  end if;
  return target_id;
end;
$$;

revoke all on function public.save_routine(uuid, text, uuid[]) from public, anon;
revoke all on function public.start_workout(uuid) from public, anon;
revoke all on function public.change_workout(uuid, text, uuid, numeric, integer) from public, anon;
grant execute on function public.save_routine(uuid, text, uuid[]) to authenticated;
grant execute on function public.start_workout(uuid) to authenticated;
grant execute on function public.change_workout(uuid, text, uuid, numeric, integer) to authenticated;

-- Serialize set edits with completion, including direct API requests under RLS.
create function private.guard_finished_workout() returns trigger
language plpgsql security invoker set search_path = '' as $$
declare workout_id uuid; finished timestamptz;
begin
  if tg_table_name = 'workout_exercises' then
    if tg_op = 'DELETE' then workout_id := old.workout_id; else workout_id := new.workout_id; end if;
  else
    select e.workout_id into workout_id from public.workout_exercises e
      where e.id = case when tg_op = 'DELETE' then old.workout_exercise_id else new.workout_exercise_id end;
  end if;
  select completed_at into finished from public.workouts where id = workout_id for update;
  if finished is not null then raise exception 'Finished workouts cannot be edited' using errcode = '22023'; end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function private.guard_finished_workout() from public;
create trigger workout_exercises_guard_finished before insert or update or delete on public.workout_exercises
  for each row execute function private.guard_finished_workout();
create trigger workout_sets_guard_finished before insert or update or delete on public.workout_sets
  for each row execute function private.guard_finished_workout();

create function private.guard_completion() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if old.completed_at is not null and (new.completed_at is distinct from old.completed_at or new.started_at is distinct from old.started_at) then
    raise exception 'Completion cannot be changed' using errcode = '22023';
  end if;
  if old.completed_at is null and new.completed_at is not null and not exists (
    select 1 from public.workout_sets s join public.workout_exercises e on e.id = s.workout_exercise_id where e.workout_id = old.id
  ) then raise exception 'Log at least one set before finishing' using errcode = '22023'; end if;
  if old.completed_at is null and new.completed_at is not null then
    new.completed_at := now();
    -- Personal completion must never end another participant's session.
    update public.workout_sessions set status = 'completed', ended_at = new.completed_at
      where id = old.session_id and created_by = auth.uid()
      and (select count(*) from public.session_participants where session_id = old.session_id) = 1;
  end if;
  return new;
end;
$$;
revoke all on function private.guard_completion() from public;
create trigger workouts_guard_completion before update on public.workouts for each row execute function private.guard_completion();

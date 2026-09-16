begin;

insert into auth.users (id, email)
values
  ('30000000-0000-0000-0000-000000000001', 'circle-a@example.test'),
  ('30000000-0000-0000-0000-000000000002', 'circle-b@example.test');

set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '30000000-0000-0000-0000-000000000001',
  true
);

do $$
declare
  created_circle_id uuid;
begin
  created_circle_id := public.create_circle('Morning crew');
  perform set_config('test.circle_id', created_circle_id::text, true);

  if not exists (
    select 1
    from public.gym_circles
    where id = created_circle_id
      and name = 'Morning crew'
      and owner_id = auth.uid()
  ) then
    raise exception 'Creator could not read the Circle they created';
  end if;

  if not exists (
    select 1
    from public.circle_members
    where circle_members.circle_id = created_circle_id
      and user_id = auth.uid()
  ) then
    raise exception 'Circle creator was not added as a member';
  end if;

  begin
    perform public.leave_circle(created_circle_id);
    raise exception 'Circle owner was allowed to leave without deleting';
  exception when invalid_parameter_value then null;
  end;
end;
$$;

do $$
declare
  workout_id uuid;
  workout_exercise_id uuid;
  exercise_id uuid;
begin
  select id into exercise_id
  from public.exercises
  where name = 'Barbell squat' and owner_id is null;

  workout_id := public.start_workout(null);
  workout_exercise_id := public.change_workout(
    workout_id,
    'add_exercise',
    exercise_id
  );
  perform public.change_workout(
    workout_id,
    'add_set',
    workout_exercise_id,
    100,
    5
  );
  perform public.change_workout(workout_id, 'finish');
  perform set_config('test.user_a_workout_id', workout_id::text, true);
end;
$$;

reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '30000000-0000-0000-0000-000000000002',
  true
);

do $$
declare
  target_circle_id uuid := current_setting('test.circle_id')::uuid;
begin
  if exists (select 1 from public.gym_circles where id = target_circle_id) then
    raise exception 'Unrelated user could read a private Circle';
  end if;

  if exists (
    select 1 from public.circle_members
    where circle_members.circle_id = target_circle_id
  ) then
    raise exception 'Unrelated user could read private Circle membership';
  end if;

  begin
    insert into public.circle_members (circle_id, user_id)
    values (target_circle_id, auth.uid());
    raise exception 'Unrelated user added themselves to a Circle directly';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.gym_circles (name, owner_id)
    values ('Spoofed owner', '30000000-0000-0000-0000-000000000001');
    raise exception 'User spoofed a Circle owner through direct insertion';
  exception when insufficient_privilege then null;
  end;

  begin
    perform public.delete_circle(target_circle_id);
    raise exception 'Non-owner deleted a Circle';
  exception when insufficient_privilege then null;
  end;
end;
$$;

-- Invitations are deliberately out of scope. Simulate a future explicitly
-- authorized membership grant as the database owner, then resume RLS tests.
reset role;
insert into public.circle_members (circle_id, user_id)
values (
  current_setting('test.circle_id')::uuid,
  '30000000-0000-0000-0000-000000000002'
);

set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '30000000-0000-0000-0000-000000000002',
  true
);

do $$
declare
  target_circle_id uuid := current_setting('test.circle_id')::uuid;
  changed_rows integer;
begin
  if not exists (
    select 1 from public.gym_circles where id = target_circle_id
  ) then
    raise exception 'Member could not read their Circle';
  end if;

  if (
    select count(*) from public.circle_members
    where circle_members.circle_id = target_circle_id
  ) <> 2 then
    raise exception 'Member could not read all Circle members';
  end if;

  begin
    delete from public.circle_members
    where circle_members.circle_id = target_circle_id
      and user_id = '30000000-0000-0000-0000-000000000001';
    raise exception 'Member removed another Circle member';
  exception when insufficient_privilege then null;
  end;

  select count(*) into changed_rows
  from public.workouts
  where id = current_setting('test.user_a_workout_id')::uuid;
  if changed_rows <> 0 then
    raise exception 'Circle membership exposed another member workout';
  end if;

  if exists (
    select 1 from public.workout_sets
    where owner_id = '30000000-0000-0000-0000-000000000001'
  ) then
    raise exception 'Circle membership exposed another member set';
  end if;

  update public.workouts
  set notes = 'unauthorized Circle change'
  where id = current_setting('test.user_a_workout_id')::uuid;
  get diagnostics changed_rows = row_count;
  if changed_rows <> 0 then
    raise exception 'Circle membership allowed updating another member workout';
  end if;

  update public.workout_sets
  set reps = 99
  where owner_id = '30000000-0000-0000-0000-000000000001';
  get diagnostics changed_rows = row_count;
  if changed_rows <> 0 then
    raise exception 'Circle membership allowed updating another member set';
  end if;
end;
$$;

do $$
declare
  target_circle_id uuid := current_setting('test.circle_id')::uuid;
  workout_id uuid;
  workout_exercise_id uuid;
  exercise_id uuid;
begin
  select id into exercise_id
  from public.exercises
  where name = 'Barbell bench press' and owner_id is null;

  workout_id := public.start_workout(null);
  workout_exercise_id := public.change_workout(
    workout_id,
    'add_exercise',
    exercise_id
  );
  perform public.change_workout(
    workout_id,
    'add_set',
    workout_exercise_id,
    50,
    8
  );
  perform public.change_workout(workout_id, 'finish');
  perform set_config('test.user_b_workout_id', workout_id::text, true);
  perform public.leave_circle(target_circle_id);

  if not exists (select 1 from public.workouts where id = workout_id) then
    raise exception 'Leaving a Circle removed or hid personal workout history';
  end if;

  if exists (
    select 1 from public.gym_circles where id = target_circle_id
  ) then
    raise exception 'Former member retained Circle visibility';
  end if;
end;
$$;

reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '30000000-0000-0000-0000-000000000001',
  true
);

do $$
declare
  target_circle_id uuid := current_setting('test.circle_id')::uuid;
begin
  perform public.delete_circle(target_circle_id);

  if exists (select 1 from public.gym_circles where id = target_circle_id)
    or exists (
      select 1 from public.circle_members
      where circle_members.circle_id = target_circle_id
    ) then
    raise exception 'Owner deletion did not remove Circle membership';
  end if;

  if not exists (
    select 1 from public.workouts
    where id = current_setting('test.user_a_workout_id')::uuid
  ) then
    raise exception 'Deleting a Circle removed owner workout history';
  end if;
end;
$$;

select '1..1';
select 'ok 1 - private Circle membership lifecycle and workout isolation';
rollback;

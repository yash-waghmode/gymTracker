-- Real role/RLS/RPC checks. Separate transactions keep authoritative completion
-- timestamps on the correct side of goal creation.
begin;
insert into auth.users (id, email, raw_user_meta_data) values
  ('80000000-0000-0000-0000-000000000001', 'goal-a@example.test', '{"display_name":"Owner A"}'),
  ('80000000-0000-0000-0000-000000000002', 'goal-b@example.test', '{"display_name":"Member B"}'),
  ('80000000-0000-0000-0000-000000000003', 'goal-c@example.test', '{"display_name":"Late C"}'),
  ('80000000-0000-0000-0000-000000000004', 'goal-d@example.test', '{"display_name":"Outsider D"}');
insert into public.gym_circles (id, name, owner_id) values
  ('80000000-0000-0000-0000-000000000010', 'Goal Circle', '80000000-0000-0000-0000-000000000001');
insert into public.circle_members (circle_id, user_id) values
  ('80000000-0000-0000-0000-000000000010', '80000000-0000-0000-0000-000000000001'),
  ('80000000-0000-0000-0000-000000000010', '80000000-0000-0000-0000-000000000002');
commit;

set role authenticated;
select set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000001', false);
begin;
do $$
declare
  w uuid;
  e uuid;
  squat uuid;
begin
  select id into squat from public.exercises where name = 'Barbell squat' and owner_id is null;
  w := public.start_workout(null);
  e := public.change_workout(w, 'add_exercise', squat);
  perform public.change_workout(w, 'add_set', e, 40, 5);
  perform public.change_workout(w, 'finish');
  perform set_config('test.goal_prior_workout', w::text, false);
end;
$$;
commit;

begin;
do $$
declare
  circle_id uuid := '80000000-0000-0000-0000-000000000010';
  a_id uuid := '80000000-0000-0000-0000-000000000001';
  b_id uuid := '80000000-0000-0000-0000-000000000002';
  d_id uuid := '80000000-0000-0000-0000-000000000004';
  new_goal_id uuid;
  invite_token text;
begin
  perform set_config('request.jwt.claim.sub', b_id::text, false);
  begin
    perform public.create_circle_workout_goal(circle_id, 2);
    raise exception 'Non-owner created goal';
  exception when insufficient_privilege then null; end;

  perform set_config('request.jwt.claim.sub', d_id::text, false);
  begin
    perform public.create_circle_workout_goal(circle_id, 2);
    raise exception 'Outsider created goal';
  exception when insufficient_privilege then null; end;
  begin
    perform public.get_active_circle_workout_goal(circle_id);
    raise exception 'Outsider read goal listing';
  exception when insufficient_privilege then null; end;

  perform set_config('request.jwt.claim.sub', a_id::text, false);
  begin
    perform public.create_circle_workout_goal(circle_id, 0);
    raise exception 'Zero target accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.create_circle_workout_goal(circle_id, 8);
    raise exception 'Excessive target accepted';
  exception when invalid_parameter_value then null; end;
  new_goal_id := public.create_circle_workout_goal(circle_id, 2);
  perform set_config('test.goal_id', new_goal_id::text, false);
  if not exists (
    select 1 from public.get_active_circle_workout_goal(circle_id) as active
    where active.goal_id = new_goal_id and active.target_workouts = 2
      and active.ends_at = active.starts_at + interval '7 days'
  ) then raise exception 'Owner could not read valid seven-day goal'; end if;
  if (select count(*) from public.get_circle_workout_goal_progress(new_goal_id)) <> 2
    or exists (
      select 1 from public.get_circle_workout_goal_progress(new_goal_id)
      where completed_workouts <> 0 or display_name not in ('Owner A', 'Member B')
        or group_complete or goal_status <> 'active'
    ) then raise exception 'Initial cohort or before-window count incorrect'; end if;
  begin
    perform public.create_circle_workout_goal(circle_id, 1);
    raise exception 'Second active goal accepted';
  exception when invalid_parameter_value then null; end;
  begin
    insert into public.circle_workout_goals (
      circle_id, created_by, target_workouts, starts_at, ends_at, created_at
    ) values (circle_id, a_id, 1, now(), now() + interval '7 days', now());
    raise exception 'Direct goal insertion allowed';
  exception when insufficient_privilege then null; end;
  begin
    perform 1 from public.circle_workout_goals;
    raise exception 'Goal storage was directly readable';
  exception when insufficient_privilege then null; end;
  begin
    perform 1 from public.circle_workout_goal_participants;
    raise exception 'Goal cohort was directly readable';
  exception when insufficient_privilege then null; end;
  select token into invite_token from public.create_circle_invite(circle_id);
  perform set_config('test.goal_late_invite', invite_token, false);
end;
$$;
commit;

begin;
do $$
declare
  circle_id uuid := '80000000-0000-0000-0000-000000000010';
  goal_id uuid := current_setting('test.goal_id')::uuid;
  a_id uuid := '80000000-0000-0000-0000-000000000001';
  b_id uuid := '80000000-0000-0000-0000-000000000002';
  c_id uuid := '80000000-0000-0000-0000-000000000003';
  d_id uuid := '80000000-0000-0000-0000-000000000004';
  w uuid;
  e uuid;
  squat uuid;
  shared_id uuid;
  shared_workout uuid;
begin
  perform set_config('request.jwt.claim.sub', d_id::text, false);
  begin
    perform public.get_circle_workout_goal_progress(goal_id);
    raise exception 'Outsider read goal progress';
  exception when insufficient_privilege then null; end;
  begin
    perform public.cancel_circle_workout_goal(goal_id);
    raise exception 'Outsider cancelled goal';
  exception when insufficient_privilege then null; end;

  perform set_config('request.jwt.claim.sub', c_id::text, false);
  if public.accept_circle_invite(current_setting('test.goal_late_invite')) <> circle_id then
    raise exception 'Late member could not join Circle';
  end if;
  if (select count(*) from public.get_circle_workout_goal_progress(goal_id)) <> 2
    or exists (
      select 1 from public.get_circle_workout_goal_progress(goal_id) where user_id = c_id
    ) then raise exception 'Late joiner was added to existing goal'; end if;

  perform set_config('request.jwt.claim.sub', a_id::text, false);
  select id into squat from public.exercises where name = 'Barbell squat' and owner_id is null;
  w := public.start_workout(null);
  e := public.change_workout(w, 'add_exercise', squat);
  perform public.change_workout(w, 'add_set', e, 45, 6);
  perform public.change_workout(w, 'finish');
  perform set_config('test.goal_solo_a', w::text, false);
end;
$$;
commit;

begin;
do $$
declare
  circle_id uuid := '80000000-0000-0000-0000-000000000010';
  goal_id uuid := current_setting('test.goal_id')::uuid;
  a_id uuid := '80000000-0000-0000-0000-000000000001';
  b_id uuid := '80000000-0000-0000-0000-000000000002';
  squat uuid;
  shared_id uuid;
  workout_a uuid;
  workout_b uuid;
  exercise_a uuid;
  exercise_b uuid;
  set_b uuid;
begin
  perform set_config('request.jwt.claim.sub', a_id::text, false);
  select id into squat from public.exercises where name = 'Barbell squat' and owner_id is null;
  select session_id, workout_id into shared_id, workout_a
    from public.start_shared_session(circle_id);
  exercise_a := public.change_workout(workout_a, 'add_exercise', squat);
  perform public.change_workout(workout_a, 'add_set', exercise_a, 50, 5);
  perform public.change_workout(workout_a, 'finish');
  perform set_config('test.goal_shared_a', workout_a::text, false);

  perform set_config('request.jwt.claim.sub', b_id::text, false);
  workout_b := public.join_shared_session(shared_id);
  exercise_b := public.change_workout(workout_b, 'add_exercise', squat);
  set_b := public.change_workout(workout_b, 'add_set', exercise_b, 60, 4);
  perform set_config('test.goal_shared_b', workout_b::text, false);
  if (
    select completed_workouts from public.get_circle_workout_goal_progress(goal_id)
    where user_id = a_id
  ) <> 2 or (
    select completed_workouts from public.get_circle_workout_goal_progress(goal_id)
    where user_id = b_id
  ) <> 0 or exists (
    select 1 from public.get_circle_workout_goal_progress(goal_id) where group_complete
  ) then raise exception 'Solo/shared counts or unfinished exclusion wrong'; end if;
  if exists (select 1 from public.workouts where id = workout_a)
    or exists (select 1 from public.workout_sets where owner_id = a_id)
    or exists (select 1 from public.routines where owner_id = a_id) then
    raise exception 'Progress access exposed A private workout contents';
  end if;
  if not exists (
    select 1 from public.get_circle_workout_goal_progress(goal_id)
    where user_id = a_id and display_name = 'Owner A'
      and completed_workouts = 2 and target_workouts = 2
  ) then raise exception 'B could not see safe aggregate progress'; end if;
  begin
    perform public.cancel_circle_workout_goal(goal_id);
    raise exception 'Non-owner cancelled goal';
  exception when insufficient_privilege then null; end;
  begin
    update public.circle_workout_goal_participants as cohort
    set user_id = b_id where cohort.goal_id = current_setting('test.goal_id')::uuid;
    raise exception 'Member altered goal contribution cohort';
  exception when insufficient_privilege then null; end;
  perform set_config('test.goal_set_b', set_b::text, false);
end;
$$;
commit;

begin;
do $$
declare
  circle_id uuid := '80000000-0000-0000-0000-000000000010';
  goal_id uuid := current_setting('test.goal_id')::uuid;
  a_id uuid := '80000000-0000-0000-0000-000000000001';
  b_id uuid := '80000000-0000-0000-0000-000000000002';
  invite_token text;
begin
  perform set_config('request.jwt.claim.sub', b_id::text, false);
  perform public.leave_circle(circle_id);
  begin
    perform public.get_circle_workout_goal_progress(goal_id);
    raise exception 'Former member read goal progress';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub', a_id::text, false);
  if (select count(*) from public.get_circle_workout_goal_progress(goal_id)) <> 1
    or not (select group_complete from public.get_circle_workout_goal_progress(goal_id) limit 1) then
    raise exception 'Leaver still prevented remaining group success';
  end if;
  select token into invite_token from public.create_circle_invite(circle_id);
  perform set_config('test.goal_rejoin_invite', invite_token, false);
end;
$$;
commit;

begin;
do $$
declare
  circle_id uuid := '80000000-0000-0000-0000-000000000010';
  goal_id uuid := current_setting('test.goal_id')::uuid;
  a_id uuid := '80000000-0000-0000-0000-000000000001';
  b_id uuid := '80000000-0000-0000-0000-000000000002';
  w uuid;
  e uuid;
  squat uuid;
begin
  perform set_config('request.jwt.claim.sub', b_id::text, false);
  perform public.accept_circle_invite(current_setting('test.goal_rejoin_invite'));
  if (select count(*) from public.get_circle_workout_goal_progress(goal_id)) <> 2
    or exists (select 1 from public.get_circle_workout_goal_progress(goal_id) where group_complete) then
    raise exception 'Rejoined starting member did not regain cohort eligibility';
  end if;
  perform public.change_workout(current_setting('test.goal_shared_b')::uuid, 'finish');
  if (
    select completed_workouts from public.get_circle_workout_goal_progress(goal_id)
    where user_id = b_id
  ) <> 1 or exists (
    select 1 from public.get_circle_workout_goal_progress(goal_id) where group_complete
  ) then raise exception 'One completed shared workout caused early success'; end if;
  w := public.start_workout(null);
  select id into squat from public.exercises where name = 'Barbell squat' and owner_id is null;
  e := public.change_workout(w, 'add_exercise', squat);
  perform public.change_workout(w, 'add_set', e, 30, 8);
  if (
    select completed_workouts from public.get_circle_workout_goal_progress(goal_id)
    where user_id = b_id
  ) <> 1 then raise exception 'Unfinished solo workout counted'; end if;
  perform public.change_workout(w, 'finish');
  if exists (
    select 1 from public.get_circle_workout_goal_progress(goal_id)
    where not group_complete or goal_status <> 'succeeded'
  ) or (
    select completed_workouts from public.get_circle_workout_goal_progress(goal_id)
    where user_id = a_id
  ) <> 2 or (
    select completed_workouts from public.get_circle_workout_goal_progress(goal_id)
    where user_id = b_id
  ) <> 2 then raise exception 'All eligible participants did not achieve group goal'; end if;
  perform set_config('request.jwt.claim.sub', a_id::text, false);
  if not exists (
    select 1 from public.get_circle_workout_goal_progress(goal_id)
    where user_id = b_id and display_name = 'Member B' and completed_workouts = 2
  ) or exists (
    select 1 from public.workouts
    where id in (current_setting('test.goal_shared_b')::uuid, w)
  ) or exists (
    select 1 from public.workout_sets
    where id = current_setting('test.goal_set_b')::uuid
  ) then raise exception 'A saw more than B aggregate progress'; end if;
  perform set_config('test.goal_solo_b', w::text, false);
end;
$$;
commit;

begin;
do $$
declare
  circle_id uuid := '80000000-0000-0000-0000-000000000010';
  goal_id uuid := current_setting('test.goal_id')::uuid;
  a_id uuid := '80000000-0000-0000-0000-000000000001';
  b_id uuid := '80000000-0000-0000-0000-000000000002';
  next_goal uuid;
begin
  perform set_config('request.jwt.claim.sub', a_id::text, false);
  perform public.cancel_circle_workout_goal(goal_id);
  if (select count(*) from public.get_active_circle_workout_goal(circle_id)) <> 0
    or not exists (
      select 1 from public.get_circle_workout_goal_progress(goal_id)
      where goal_status = 'cancelled' and cancelled_at is not null
    ) then raise exception 'Cancellation did not stop active goal'; end if;
  if not exists (
    select 1 from public.workouts
    where id = current_setting('test.goal_prior_workout')::uuid and completed_at is not null
  ) or not exists (
    select 1 from public.workouts
    where id = current_setting('test.goal_shared_a')::uuid and completed_at is not null
  ) then raise exception 'Cancellation affected A personal history'; end if;
  perform set_config('request.jwt.claim.sub', b_id::text, false);
  if not exists (
    select 1 from public.workouts
    where id = current_setting('test.goal_shared_b')::uuid and completed_at is not null
  ) or not exists (
    select 1 from public.workout_sets
    where id = current_setting('test.goal_set_b')::uuid
  ) then raise exception 'Cancellation affected B personal history'; end if;
  perform set_config('request.jwt.claim.sub', a_id::text, false);
  next_goal := public.create_circle_workout_goal(circle_id, 1);
  perform set_config('test.goal_expiring_id', next_goal::text, false);
end;
$$;
commit;

reset role;
begin;
update public.circle_workout_goals
set starts_at = now() - interval '8 days',
  ends_at = now() - interval '1 day'
where id = current_setting('test.goal_expiring_id')::uuid;
commit;

set role authenticated;
select set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000001', false);
begin;
do $$
declare
  circle_id uuid := '80000000-0000-0000-0000-000000000010';
  expired_goal uuid := current_setting('test.goal_expiring_id')::uuid;
begin
  if (select count(*) from public.get_active_circle_workout_goal(circle_id)) <> 0
    or exists (
      select 1 from public.get_circle_workout_goal_progress(expired_goal)
      where goal_status <> 'expired' or completed_workouts <> 0 or group_complete
    ) then raise exception 'Expired goal or upper window bound counted incorrectly'; end if;
  if public.create_circle_workout_goal(circle_id, 1) is null then
    raise exception 'Expired goal prevented a new active goal';
  end if;
end;
$$;
commit;

reset role;
select '1..1';
select 'ok 1 - seven-day Circle goal eligibility, aggregate progress, lifecycle and workout privacy';

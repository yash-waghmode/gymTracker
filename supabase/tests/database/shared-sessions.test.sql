begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('70000000-0000-0000-0000-000000000001', 'shared-a@example.test', '{"display_name":"Creator A"}'),
  ('70000000-0000-0000-0000-000000000002', 'shared-b@example.test', '{"display_name":"Member B"}'),
  ('70000000-0000-0000-0000-000000000003', 'shared-c@example.test', '{"display_name":"Outsider C"}'),
  ('70000000-0000-0000-0000-000000000004', 'shared-d@example.test', '{"display_name":"Member D"}');
insert into public.gym_circles (id, name, owner_id) values
  ('70000000-0000-0000-0000-000000000010', 'Private Circle', '70000000-0000-0000-0000-000000000001');
insert into public.circle_members (circle_id, user_id) values
  ('70000000-0000-0000-0000-000000000010', '70000000-0000-0000-0000-000000000001'),
  ('70000000-0000-0000-0000-000000000010', '70000000-0000-0000-0000-000000000002'),
  ('70000000-0000-0000-0000-000000000010', '70000000-0000-0000-0000-000000000004');

set role authenticated;
select set_config('request.jwt.claim.sub', '70000000-0000-0000-0000-000000000001', true);
do $$
declare
  target_circle uuid := '70000000-0000-0000-0000-000000000010';
  a_id uuid := '70000000-0000-0000-0000-000000000001';
  b_id uuid := '70000000-0000-0000-0000-000000000002';
  c_id uuid := '70000000-0000-0000-0000-000000000003';
  d_id uuid := '70000000-0000-0000-0000-000000000004';
  squat_id uuid;
  bench_id uuid;
  routine_a uuid;
  routine_b uuid;
  shared_id uuid;
  workout_a uuid;
  workout_b uuid;
  exercise_a uuid;
  exercise_b uuid;
  set_a uuid;
  set_b uuid;
  single_session uuid;
  single_workout uuid;
  later_session uuid;
  later_workout uuid;
  later_workout_b uuid;
  changed_rows integer;
begin
  select id into squat_id from public.exercises where name = 'Barbell squat' and owner_id is null;
  select id into bench_id from public.exercises where name = 'Barbell bench press' and owner_id is null;
  routine_a := public.save_routine(null, 'A routine', array[squat_id]);
  select session_id, workout_id into shared_id, workout_a
    from public.start_shared_session(target_circle, routine_a);
  if shared_id is null or workout_a is null
    or (select count(*) from public.session_participants where session_id = shared_id and user_id = a_id) <> 1
    or (select count(*) from public.workouts where session_id = shared_id and owner_id = a_id) <> 1
    or (select count(*) from public.workout_exercises where workout_id = workout_a and owner_id = a_id) <> 1
    or not exists (select 1 from public.workout_sessions where id = shared_id and circle_id = target_circle and is_shared and status = 'active')
  then raise exception 'Atomic shared start or ownership failed'; end if;
  if (select count(*) from public.get_active_shared_sessions(target_circle)) <> 1 then
    raise exception 'Creator cannot discover active session';
  end if;
  begin
    perform public.start_shared_session(target_circle);
    raise exception 'Second active workout allowed';
  exception when invalid_parameter_value then null; end;
  begin
    insert into public.session_participants (session_id, user_id) values (shared_id, d_id);
    raise exception 'Creator could add another shared participant';
  exception when insufficient_privilege then null; end;
  update public.session_participants set left_at = now()
    where session_id = shared_id and user_id = a_id;
  get diagnostics changed_rows = row_count;
  if changed_rows <> 0 then raise exception 'Shared participant could leave behind an active workout'; end if;
  begin
    insert into public.workout_sessions (created_by, is_shared, circle_id)
      values (a_id, true, target_circle);
    raise exception 'Direct shared-session insertion allowed';
  exception when insufficient_privilege then null; end;

  perform set_config('request.jwt.claim.sub', c_id::text, true);
  if exists (select 1 from public.workout_sessions where id = shared_id)
    or exists (select 1 from public.session_participants where session_id = shared_id) then
    raise exception 'Outsider discovered session tables';
  end if;
  begin
    perform public.get_active_shared_sessions(target_circle);
    raise exception 'Outsider discovered active session';
  exception when insufficient_privilege then null; end;
  begin
    perform public.get_shared_session_participants(shared_id);
    raise exception 'Outsider discovered participant identities';
  exception when insufficient_privilege then null; end;
  begin
    perform public.join_shared_session(shared_id);
    raise exception 'Outsider joined session';
  exception when insufficient_privilege then null; end;
  begin
    perform public.start_shared_session(target_circle);
    raise exception 'Outsider started session';
  exception when insufficient_privilege then null; end;

  perform set_config('request.jwt.claim.sub', b_id::text, true);
  if not exists (
    select 1 from public.get_active_shared_sessions(target_circle)
    where session_id = shared_id and circle_id = target_circle
      and created_by = a_id and creator_display_name = 'Creator A'
      and status = 'active' and participant_count = 1
  ) then raise exception 'Co-member discovery metadata wrong'; end if;
  if not exists (
    select 1 from public.get_shared_session_participants(shared_id)
    where user_id = a_id and display_name = 'Creator A' and not workout_finished
  ) or (select count(*) from public.get_shared_session_participants(shared_id)) <> 1 then
    raise exception 'Safe pre-join participant identities unavailable';
  end if;
  routine_b := public.save_routine(null, 'B routine', array[bench_id]);
  workout_b := public.join_shared_session(shared_id, routine_b);
  if public.join_shared_session(shared_id) <> workout_b
    or (select count(*) from public.session_participants where session_id = shared_id and user_id = b_id) <> 1
    or (select count(*) from public.workouts where session_id = shared_id and owner_id = b_id) <> 1
    or (select count(*) from public.workout_exercises where workout_id = workout_b and owner_id = b_id) <> 1
    or (select routine_id from public.workouts where id = workout_b) <> routine_b
    or (select participant_count from public.get_active_shared_sessions(target_circle) where session_id = shared_id) <> 2
  then raise exception 'Join, personal routine, or idempotency failed'; end if;
  if (select count(*) from public.get_shared_session_participants(shared_id)) <> 2 then
    raise exception 'Joined member missing from safe presence';
  end if;
  if exists (select 1 from public.workouts where id = workout_a)
    or exists (select 1 from public.workout_exercises where workout_id = workout_a) then
    raise exception 'B can read A private workout';
  end if;
  begin
    perform public.change_workout(workout_a, 'add_exercise', bench_id);
    raise exception 'B changed A workout';
  exception when insufficient_privilege or foreign_key_violation then null; end;
  update public.workouts set notes = 'stolen' where id = workout_a;
  get diagnostics changed_rows = row_count;
  if changed_rows <> 0 then raise exception 'B directly changed A workout'; end if;
  select id into exercise_b from public.workout_exercises where workout_id = workout_b;
  set_b := public.change_workout(workout_b, 'add_set', exercise_b, 40, 8);
  begin
    insert into public.workout_sets (workout_exercise_id, owner_id, position, reps)
      values (exercise_b, a_id, 1, 10);
    raise exception 'B inserted A-owned set';
  exception when insufficient_privilege or foreign_key_violation then null; end;

  perform set_config('request.jwt.claim.sub', a_id::text, true);
  if exists (select 1 from public.workouts where id = workout_b)
    or exists (select 1 from public.workout_sets where id = set_b) then
    raise exception 'Creator can read B private logging';
  end if;
  begin
    perform public.change_workout(workout_b, 'finish');
    raise exception 'Creator finished B workout';
  exception when insufficient_privilege then null; end;
  update public.workouts set notes = 'stolen' where id = workout_b;
  get diagnostics changed_rows = row_count;
  if changed_rows <> 0 then raise exception 'Creator directly changed B workout'; end if;
  update public.workout_sets set reps = 99 where id = set_b;
  get diagnostics changed_rows = row_count;
  if changed_rows <> 0 then raise exception 'Creator edited B set'; end if;
  delete from public.workout_sets where id = set_b;
  get diagnostics changed_rows = row_count;
  if changed_rows <> 0 then raise exception 'Creator deleted B set'; end if;
  begin
    insert into public.workout_sets (workout_exercise_id, owner_id, position, reps)
      values (exercise_b, a_id, 1, 10);
    raise exception 'Creator inserted into B exercise';
  exception when insufficient_privilege or foreign_key_violation then null; end;
  select id into exercise_a from public.workout_exercises where workout_id = workout_a;
  set_a := public.change_workout(workout_a, 'add_set', exercise_a, 80, 5);

  perform set_config('request.jwt.claim.sub', b_id::text, true);
  begin
    perform public.change_workout(workout_a, 'edit_set', set_a, 100, 1);
    raise exception 'B edited A set through RPC';
  exception when insufficient_privilege then null; end;
  update public.workout_sets set reps = 99 where id = set_a;
  get diagnostics changed_rows = row_count;
  if changed_rows <> 0 then raise exception 'B edited A set directly'; end if;
  delete from public.workout_sets where id = set_a;
  get diagnostics changed_rows = row_count;
  if changed_rows <> 0 then raise exception 'B deleted A set directly'; end if;
  begin
    insert into public.workout_sets (workout_exercise_id, owner_id, position, reps)
      values (exercise_a, b_id, 1, 10);
    raise exception 'B inserted into A exercise';
  exception when insufficient_privilege or foreign_key_violation then null; end;
  begin
    perform public.end_shared_session(shared_id);
    raise exception 'B ended A session';
  exception when insufficient_privilege then null; end;

  perform set_config('request.jwt.claim.sub', a_id::text, true);
  perform public.change_workout(workout_a, 'finish');
  if (select status from public.workout_sessions where id = shared_id) <> 'active'
    or (select completed_at from public.workouts where id = workout_a) is null then
    raise exception 'A completion ended shared context';
  end if;
  if not exists (
    select 1 from public.get_shared_session_participants(shared_id)
    where user_id = a_id and workout_finished
  ) or not exists (
    select 1 from public.get_shared_session_participants(shared_id)
    where user_id = b_id and not workout_finished
  ) then raise exception 'Independent workout status not reflected in safe presence'; end if;
  perform public.end_shared_session(shared_id);
  perform public.end_shared_session(shared_id);
  if (select status from public.workout_sessions where id = shared_id) <> 'completed'
    or (select count(*) from public.get_active_shared_sessions(target_circle)) <> 0 then
    raise exception 'Creator closure failed';
  end if;
  perform set_config('request.jwt.claim.sub', d_id::text, true);
  begin
    perform public.join_shared_session(shared_id);
    raise exception 'Joined closed session';
  exception when invalid_parameter_value then null; end;
  perform set_config('request.jwt.claim.sub', b_id::text, true);
  if (select completed_at from public.workouts where id = workout_b) is not null then
    raise exception 'Closure finished B workout';
  end if;
  perform public.change_workout(workout_b, 'finish');
  if (select completed_at from public.workouts where id = workout_b) is null then
    raise exception 'B could not finish independently after closure';
  end if;

  perform set_config('request.jwt.claim.sub', a_id::text, true);
  begin
    perform public.start_shared_session(target_circle, routine_b);
    raise exception 'A started from B routine';
  exception when insufficient_privilege then null; end;
  select session_id, workout_id into single_session, single_workout
    from public.start_shared_session(target_circle);
  exercise_a := public.change_workout(single_workout, 'add_exercise', squat_id);
  perform public.change_workout(single_workout, 'add_set', exercise_a, 50, 5);
  perform public.change_workout(single_workout, 'finish');
  if (select status from public.workout_sessions where id = single_session) <> 'active' then
    raise exception 'One-person shared session auto-closed';
  end if;
  perform public.end_shared_session(single_session);
  select session_id, workout_id into later_session, later_workout
    from public.start_shared_session(target_circle);
  perform set_config('request.jwt.claim.sub', b_id::text, true);
  later_workout_b := public.join_shared_session(later_session);
  perform public.leave_circle(target_circle);
  if exists (select 1 from public.workout_sessions where id = later_session)
    or exists (select 1 from public.session_participants where session_id = later_session) then
    raise exception 'Former member retained shared-session discovery';
  end if;
  begin
    perform public.get_active_shared_sessions(target_circle);
    raise exception 'Former member used discovery function';
  exception when insufficient_privilege then null; end;
  begin
    perform public.get_shared_session_participants(later_session);
    raise exception 'Former member used participant presence function';
  exception when insufficient_privilege then null; end;
  exercise_b := public.change_workout(later_workout_b, 'add_exercise', bench_id);
  perform public.change_workout(later_workout_b, 'add_set', exercise_b, 30, 8);
  perform public.change_workout(later_workout_b, 'finish');
  perform set_config('request.jwt.claim.sub', a_id::text, true);
  perform public.delete_circle(target_circle);
  if not exists (select 1 from public.workouts where id = later_workout and completed_at is null)
    or exists (select 1 from public.gym_circles where id = target_circle) then
    raise exception 'Circle deletion damaged personal workout';
  end if;
  exercise_a := public.change_workout(later_workout, 'add_exercise', squat_id);
  perform public.change_workout(later_workout, 'add_set', exercise_a, 50, 5);
  perform public.change_workout(later_workout, 'finish');
  if (select completed_at from public.workouts where id = later_workout) is null then
    raise exception 'Detached workout could not finish';
  end if;
end;
$$;
reset role;

do $$
begin
  if not exists (
    select 1 from public.workout_sessions
    where is_shared and circle_id is null and status = 'completed'
      and id in (select session_id from public.workouts where owner_id = '70000000-0000-0000-0000-000000000001')
  ) then raise exception 'Circle deletion did not close and detach context'; end if;
  if (select count(*) from public.workouts where owner_id in (
      '70000000-0000-0000-0000-000000000001',
      '70000000-0000-0000-0000-000000000002')) <> 5 then
    raise exception 'Circle deletion lost participant workout history';
  end if;
end;
$$;

select '1..1';
select 'ok 1 - Circle shared-session lifecycle and personal ownership isolation';
rollback;

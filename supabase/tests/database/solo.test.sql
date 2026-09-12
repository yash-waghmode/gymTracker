begin;
insert into auth.users (id, email) values
 ('10000000-0000-0000-0000-000000000001', 'solo-a@example.test'),
 ('10000000-0000-0000-0000-000000000002', 'solo-b@example.test');
set role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
do $$
declare r uuid; w uuid; e uuid; s uuid; exercise_a uuid; exercise_b uuid; finished timestamptz;
begin
  select id into exercise_a from public.exercises where name = 'Barbell squat' and owner_id is null;
  select id into exercise_b from public.exercises where name = 'Barbell bench press' and owner_id is null;
  if exercise_a is null or (select count(*) from public.exercises where owner_id is null) < 25 then raise exception 'Missing starter catalog'; end if;
  r := public.save_routine(null, 'Full body', array[exercise_a, exercise_b]);
  perform public.save_routine(r, 'Full body edited', array[exercise_b, exercise_a]);
  if (select exercise_id from public.routine_exercises where routine_id = r and position = 0) <> exercise_b then raise exception 'Routine reorder failed'; end if;
  begin
    perform public.save_routine(r, 'Invalid overwrite', array['20000000-0000-0000-0000-000000000099'::uuid]);
    raise exception 'Invalid routine accepted';
  exception when foreign_key_violation then null; end;
  if (select name from public.routines where id = r) <> 'Full body edited' then raise exception 'Routine save not atomic'; end if;
  w := public.start_workout(r);
  if public.start_workout(null) <> w then raise exception 'Duplicate start did not resume'; end if;
  if (select count(*) from public.workout_exercises where workout_id = w) <> 2 then raise exception 'Routine was not copied'; end if;
  if (select count(*) from public.session_participants p join public.workouts x on x.session_id = p.session_id where x.id = w) <> 1 then raise exception 'Solo participant missing'; end if;
  begin perform public.change_workout(w, 'finish'); raise exception 'Empty completion accepted'; exception when invalid_parameter_value then null; end;
  select id into e from public.workout_exercises where workout_id = w and position = 0;
  begin perform public.change_workout(w, 'add_set', e, -1, 8); raise exception 'Negative weight accepted'; exception when invalid_parameter_value then null; end;
  begin perform public.change_workout(w, 'add_set', e, 100, 0); raise exception 'Zero reps accepted'; exception when invalid_parameter_value then null; end;
  s := public.change_workout(w, 'add_set', e, 60, 8);
  perform public.change_workout(w, 'edit_set', s, 62.5, 9);
  if (select weight_kg from public.workout_sets where id = s) <> 62.5 then raise exception 'Set update failed'; end if;
  perform public.change_workout(w, 'delete_set', s);
  if exists (select 1 from public.workout_sets where id = s) then raise exception 'Set delete failed'; end if;
  s := public.change_workout(w, 'add_set', e, 65, 8);
  perform public.change_workout(w, 'add_exercise', exercise_a);
  perform public.change_workout(w, 'finish');
  select completed_at into finished from public.workouts where id = w;
  perform public.change_workout(w, 'finish');
  if finished is null or (select completed_at from public.workouts where id = w) <> finished then raise exception 'Completion not idempotent'; end if;
  if not exists (select 1 from public.workouts x join public.workout_sessions s on s.id = x.session_id where x.id = w and s.status = 'completed' and s.ended_at = x.completed_at) then raise exception 'Session completion incoherent'; end if;
  begin perform public.change_workout(w, 'edit_set', s, 70, 8); raise exception 'Finished workout changed'; exception when invalid_parameter_value then null; end;
  begin update public.workout_sets set reps = 99 where id = s; raise exception 'Direct finished set edit accepted'; exception when invalid_parameter_value then null; end;
  begin update public.workouts set completed_at = null where id = w; raise exception 'Workout reopened'; exception when invalid_parameter_value then null; end;
  delete from public.routines where id = r;
  if (select title from public.workouts where id = w) <> 'Full body edited' or (select routine_id from public.workouts where id = w) is not null then raise exception 'Routine deletion damaged history'; end if;
  r := public.save_routine(null, 'Still owned by A', array[exercise_a]);
  perform set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
  begin perform public.change_workout(w, 'finish'); raise exception 'Cross-user RPC allowed'; exception when insufficient_privilege then null; end;
  begin perform public.save_routine(r, 'stolen', array[]::uuid[]); raise exception 'Cross-user routine RPC allowed'; exception when insufficient_privilege then null; end;
  w := public.start_workout(null);
  if (select count(*) from public.workout_exercises where workout_id = w) <> 0 then raise exception 'Free workout not empty'; end if;
  insert into public.session_participants(session_id, user_id)
    select session_id, '10000000-0000-0000-0000-000000000001' from public.workouts where id = w;
  e := public.change_workout(w, 'add_exercise', exercise_a);
  perform public.change_workout(w, 'add_set', e, 20, 10);
  update public.workouts set completed_at = '2999-01-01T00:00:00Z' where id = w;
  if (select completed_at from public.workouts where id = w) > now() then raise exception 'Completion timestamp trusted client input'; end if;
  if (select s.status from public.workout_sessions s join public.workouts x on x.session_id = s.id where x.id = w) <> 'active' then raise exception 'Personal completion ended shared session'; end if;
end;
$$;
reset role;
select '1..1';
select 'ok 1 - solo routines, logging, validation, completion and RPC isolation';
rollback;

-- Restricted RPCs are exercised as authenticated users; fixture changes use
-- the disposable local database superuser only to simulate time and membership.
begin;
insert into auth.users (id, email, raw_user_meta_data) values
  ('90000000-0000-0000-0000-000000000001', 'nudge-a@example.test', '{"display_name":"Sender A"}'),
  ('90000000-0000-0000-0000-000000000002', 'nudge-b@example.test', '{"display_name":"Recipient B"}'),
  ('90000000-0000-0000-0000-000000000003', 'nudge-c@example.test', '{"display_name":"Member C"}'),
  ('90000000-0000-0000-0000-000000000004', 'nudge-late@example.test', '{"display_name":"Late member"}'),
  ('90000000-0000-0000-0000-000000000005', 'nudge-outside@example.test', '{"display_name":"Outsider"}');
insert into public.gym_circles (id, name, owner_id) values
  ('90000000-0000-0000-0000-000000000010', 'Nudge Circle', '90000000-0000-0000-0000-000000000001');
insert into public.circle_members (circle_id, user_id) values
  ('90000000-0000-0000-0000-000000000010', '90000000-0000-0000-0000-000000000001'),
  ('90000000-0000-0000-0000-000000000010', '90000000-0000-0000-0000-000000000002'),
  ('90000000-0000-0000-0000-000000000010', '90000000-0000-0000-0000-000000000003');
commit;

set role authenticated;
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', false);
do $$
declare
  w uuid;
  e uuid;
  squat uuid;
begin
  select id into squat from public.exercises
    where name = 'Barbell squat' and owner_id is null;
  w := public.start_workout(null);
  e := public.change_workout(w, 'add_exercise', squat);
  perform public.change_workout(w, 'add_set', e, 50, 5);
  perform public.change_workout(w, 'finish');
end;
$$;
select set_config('test.nudge_goal', public.create_circle_workout_goal(
  '90000000-0000-0000-0000-000000000010', 1
)::text, false);
reset role;
insert into public.circle_members (circle_id, user_id) values
  ('90000000-0000-0000-0000-000000000010', '90000000-0000-0000-0000-000000000004');

set role authenticated;
do $$
declare
  goal_id uuid := current_setting('test.nudge_goal')::uuid;
  a_id uuid := '90000000-0000-0000-0000-000000000001';
  b_id uuid := '90000000-0000-0000-0000-000000000002';
  c_id uuid := '90000000-0000-0000-0000-000000000003';
  late_id uuid := '90000000-0000-0000-0000-000000000004';
  outside_id uuid := '90000000-0000-0000-0000-000000000005';
  nudge_id uuid;
begin
  perform set_config('request.jwt.claim.sub', a_id::text, false);
  nudge_id := public.send_circle_goal_nudge(goal_id, b_id);
  perform set_config('test.nudge_first', nudge_id::text, false);
  if nudge_id is null then raise exception 'Eligible member could not nudge B'; end if;

  begin
    perform public.send_circle_goal_nudge(goal_id, a_id);
    raise exception 'Self-nudge accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.send_circle_goal_nudge(goal_id, late_id);
    raise exception 'Late joiner was nudgeable';
  exception when insufficient_privilege then null; end;
  begin
    perform public.send_circle_goal_nudge(goal_id, outside_id);
    raise exception 'Outsider was nudgeable';
  exception when insufficient_privilege then null; end;
  begin
    perform public.send_circle_goal_nudge(goal_id, b_id);
    raise exception 'Cooldown allowed repeated A-to-B nudge';
  exception when invalid_parameter_value then null; end;
  begin
    insert into public.circle_goal_nudges (
      goal_id, sender_id, recipient_id, created_at
    ) values (goal_id, c_id, b_id, now());
    raise exception 'Sender forged by direct table insert';
  exception when insufficient_privilege then null; end;
  begin
    perform 1 from public.circle_goal_nudges;
    raise exception 'Private nudge table was directly readable';
  exception when insufficient_privilege then null; end;

  perform set_config('request.jwt.claim.sub', outside_id::text, false);
  begin
    perform public.send_circle_goal_nudge(goal_id, b_id);
    raise exception 'Unrelated user nudged B';
  exception when insufficient_privilege then null; end;
  begin
    perform public.get_my_circle_goal_nudges(goal_id);
    raise exception 'Unrelated user read nudge history';
  exception when insufficient_privilege then null; end;

  perform set_config('request.jwt.claim.sub', c_id::text, false);
  if public.send_circle_goal_nudge(goal_id, b_id) is null then
    raise exception 'Another eligible member could not independently nudge B';
  end if;
  if (select count(*) from public.get_my_circle_goal_nudges(goal_id)) <> 0 then
    raise exception 'Sender enumerated B private nudges';
  end if;

  perform set_config('request.jwt.claim.sub', b_id::text, false);
  if (select count(*) from public.get_my_circle_goal_nudges(goal_id)) <> 2
    or not exists (
      select 1 from public.get_my_circle_goal_nudges(goal_id)
      where sender_display_name = 'Sender A' and circle_name = 'Nudge Circle'
    ) or not exists (
      select 1 from public.get_my_circle_goal_nudges(goal_id)
      where sender_display_name = 'Member C'
    ) then raise exception 'Recipient did not receive safe nudge context'; end if;
  if exists (select 1 from public.workouts where owner_id = a_id)
    or exists (select 1 from public.workout_sets where owner_id = a_id)
    or exists (select 1 from public.routines where owner_id = a_id) then
    raise exception 'Nudge relationship exposed private training data';
  end if;
end;
$$;
reset role;

do $$
begin
  if not exists (
    select 1 from public.circle_goal_nudges
    where id = current_setting('test.nudge_first')::uuid
      and sender_id = '90000000-0000-0000-0000-000000000001'
      and recipient_id = '90000000-0000-0000-0000-000000000002'
  ) then raise exception 'Sender identity was not derived from auth'; end if;
end;
$$;
update public.circle_goal_nudges set created_at = clock_timestamp() - interval '25 hours'
where id = current_setting('test.nudge_first')::uuid;

set role authenticated;
do $$
declare
  goal_id uuid := current_setting('test.nudge_goal')::uuid;
  a_id uuid := '90000000-0000-0000-0000-000000000001';
  b_id uuid := '90000000-0000-0000-0000-000000000002';
  c_id uuid := '90000000-0000-0000-0000-000000000003';
  w uuid;
  e uuid;
  squat uuid;
begin
  perform set_config('request.jwt.claim.sub', a_id::text, false);
  if public.send_circle_goal_nudge(goal_id, b_id) is null then
    raise exception 'Nudge after cooldown failed';
  end if;
  perform set_config('request.jwt.claim.sub', b_id::text, false);
  select id into squat from public.exercises
    where name = 'Barbell squat' and owner_id is null;
  w := public.start_workout(null);
  e := public.change_workout(w, 'add_exercise', squat);
  perform public.change_workout(w, 'add_set', e, 40, 5);
  perform public.change_workout(w, 'finish');
  perform set_config('request.jwt.claim.sub', a_id::text, false);
  begin
    perform public.send_circle_goal_nudge(goal_id, b_id);
    raise exception 'Completed participant was nudgeable';
  exception when invalid_parameter_value then null; end;
  perform public.cancel_circle_workout_goal(goal_id);
  begin
    perform public.send_circle_goal_nudge(goal_id, c_id);
    raise exception 'Cancelled goal allowed new nudge';
  exception when invalid_parameter_value then null; end;

  perform set_config('request.jwt.claim.sub', c_id::text, false);
  perform public.leave_circle('90000000-0000-0000-0000-000000000010');
  perform set_config('request.jwt.claim.sub', b_id::text, false);
  if not exists (
    select 1 from public.get_my_circle_goal_nudges(goal_id)
    where sender_display_name is null and circle_name = 'Nudge Circle'
  ) then raise exception 'Former sender identity was still exposed'; end if;
  if (select count(*) from public.get_my_circle_goal_nudges(goal_id)) <> 3 then
    raise exception 'Historical recipient nudges disappeared after completion/cancellation';
  end if;
  perform public.leave_circle('90000000-0000-0000-0000-000000000010');
  begin
    perform public.get_my_circle_goal_nudges(goal_id);
    raise exception 'Former recipient retained nudge access';
  exception when insufficient_privilege then null; end;
end;
$$;

select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', false);
select set_config('test.nudge_expired_goal', public.create_circle_workout_goal(
  '90000000-0000-0000-0000-000000000010', 1
)::text, false);
reset role;
update public.circle_workout_goals
set starts_at = expiry.expired_at,
  ends_at = expiry.expired_at + interval '7 days'
from (select clock_timestamp() - interval '8 days' as expired_at) as expiry
where id = current_setting('test.nudge_expired_goal')::uuid;
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', false);
  begin
    perform public.send_circle_goal_nudge(
      current_setting('test.nudge_expired_goal')::uuid,
      '90000000-0000-0000-0000-000000000004'
    );
    raise exception 'Expired goal allowed nudge';
  exception when invalid_parameter_value then null; end;
end;
$$;
select public.delete_circle('90000000-0000-0000-0000-000000000010');
reset role;
do $$
begin
  if exists (
    select 1 from public.circle_goal_nudges
    where goal_id in (
      current_setting('test.nudge_goal')::uuid,
      current_setting('test.nudge_expired_goal')::uuid
    )
  ) then raise exception 'Circle deletion retained orphan nudges'; end if;
  if not exists (
    select 1 from public.workouts
    where owner_id = '90000000-0000-0000-0000-000000000002'
      and completed_at is not null
  ) then raise exception 'Circle deletion altered personal workout history'; end if;
end;
$$;
select 'ok 1 - contextual nudges, cooldown, recipient visibility and privacy' as result;

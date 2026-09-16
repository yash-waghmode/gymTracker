-- A seven-day cooperative goal snapshots its starting cohort; workout rows stay private.
create table public.circle_workout_goals (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.gym_circles (id) on delete cascade,
  created_by uuid not null references public.profiles (id) on delete restrict,
  target_workouts smallint not null check (target_workouts between 1 and 7),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  created_at timestamptz not null,
  cancelled_at timestamptz,
  constraint circle_workout_goals_window_check
    check (ends_at = starts_at + interval '7 days')
);

create index circle_workout_goals_circle_window_idx
  on public.circle_workout_goals (circle_id, ends_at desc)
  where cancelled_at is null;

create table public.circle_workout_goal_participants (
  goal_id uuid not null references public.circle_workout_goals (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete restrict,
  primary key (goal_id, user_id)
);

create index workouts_owner_completed_for_goals_idx
  on public.workouts (owner_id, completed_at)
  where completed_at is not null;

comment on table public.circle_workout_goal_participants is
  'Creation-time eligible cohort. Progress also requires current Circle membership; a former member who rejoins becomes eligible again.';

alter table public.circle_workout_goals enable row level security;
alter table public.circle_workout_goal_participants enable row level security;
revoke all on table public.circle_workout_goals from anon, authenticated;
revoke all on table public.circle_workout_goal_participants from anon, authenticated;
grant all on table public.circle_workout_goals to service_role;
grant all on table public.circle_workout_goal_participants to service_role;

create function public.create_circle_workout_goal(
  p_circle_id uuid, p_target_workouts integer
)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  caller_id uuid := (select auth.uid());
  goal_id uuid;
  start_time timestamptz;
begin
  if caller_id is null then raise insufficient_privilege; end if;
  if p_target_workouts is null or p_target_workouts not between 1 and 7 then
    raise invalid_parameter_value using message = 'Target must be 1 to 7 workouts.';
  end if;

  -- The Circle row serializes goal creation and membership changes using its FK.
  perform 1 from public.gym_circles
    where id = p_circle_id and owner_id = caller_id for update;
  if not found then raise insufficient_privilege using message = 'Circle not found.'; end if;

  start_time := clock_timestamp();
  if exists (
    select 1 from public.circle_workout_goals
    where circle_id = p_circle_id and cancelled_at is null and ends_at > start_time
  ) then
    raise invalid_parameter_value using message = 'Circle already has an active goal.';
  end if;

  insert into public.circle_workout_goals (
    circle_id, created_by, target_workouts, starts_at, ends_at, created_at
  ) values (
    p_circle_id, caller_id, p_target_workouts,
    start_time, start_time + interval '7 days', start_time
  ) returning id into goal_id;

  insert into public.circle_workout_goal_participants (goal_id, user_id)
    select goal_id, user_id from public.circle_members
    where circle_id = p_circle_id;

  return goal_id;
end;
$$;

create function public.get_active_circle_workout_goal(p_circle_id uuid)
returns table (
  goal_id uuid, circle_id uuid, created_by uuid, target_workouts smallint,
  starts_at timestamptz, ends_at timestamptz, created_at timestamptz
)
language plpgsql security definer set search_path = '' stable as $$
begin
  if (select auth.uid()) is null or not private.is_circle_member(p_circle_id) then
    raise insufficient_privilege;
  end if;
  return query
    select goals.id, goals.circle_id, goals.created_by, goals.target_workouts,
      goals.starts_at, goals.ends_at, goals.created_at
    from public.circle_workout_goals as goals
    where goals.circle_id = p_circle_id and goals.cancelled_at is null
      and goals.ends_at > now()
    order by goals.starts_at desc limit 1;
end;
$$;

create function public.get_circle_workout_goal_progress(p_goal_id uuid)
returns table (
  goal_id uuid, circle_id uuid, target_workouts smallint,
  starts_at timestamptz, ends_at timestamptz, cancelled_at timestamptz,
  goal_status text, group_complete boolean,
  user_id uuid, display_name text, completed_workouts bigint
)
language plpgsql security definer set search_path = '' stable as $$
begin
  if (select auth.uid()) is null or not exists (
    select 1 from public.circle_workout_goals as goals
    where goals.id = p_goal_id and private.is_circle_member(goals.circle_id)
  ) then
    raise insufficient_privilege;
  end if;

  return query
    with progress as (
      select goals.id as goal_id, goals.circle_id, goals.target_workouts,
        goals.starts_at, goals.ends_at, goals.cancelled_at,
        participants.user_id, profiles.display_name,
        count(workouts.id) as completed_workouts
      from public.circle_workout_goals as goals
      join public.circle_workout_goal_participants as participants
        on participants.goal_id = goals.id
      join public.circle_members as members
        on members.circle_id = goals.circle_id
        and members.user_id = participants.user_id
      join public.profiles as profiles on profiles.id = participants.user_id
      left join public.workouts as workouts
        on workouts.owner_id = participants.user_id
        and workouts.completed_at >= goals.starts_at
        and workouts.completed_at < goals.ends_at
      where goals.id = p_goal_id
      group by goals.id, participants.user_id, profiles.display_name
    )
    select progress.goal_id, progress.circle_id, progress.target_workouts,
      progress.starts_at, progress.ends_at, progress.cancelled_at,
      case
        when progress.cancelled_at is not null then 'cancelled'
        when bool_and(progress.completed_workouts >= progress.target_workouts) over ()
          then 'succeeded'
        when progress.ends_at <= now() then 'expired'
        else 'active'
      end,
      bool_and(progress.completed_workouts >= progress.target_workouts) over (),
      progress.user_id, progress.display_name, progress.completed_workouts
    from progress
    order by progress.user_id;
end;
$$;

create function public.cancel_circle_workout_goal(p_goal_id uuid)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  caller_id uuid := (select auth.uid());
  matched_goal public.circle_workout_goals%rowtype;
begin
  if caller_id is null then raise insufficient_privilege; end if;
  select goals.* into matched_goal
    from public.circle_workout_goals as goals
    join public.gym_circles as circles on circles.id = goals.circle_id
    where goals.id = p_goal_id and circles.owner_id = caller_id
    for update of goals;
  if not found then raise insufficient_privilege; end if;
  if matched_goal.cancelled_at is null and matched_goal.ends_at > clock_timestamp() then
    update public.circle_workout_goals set cancelled_at = clock_timestamp()
      where id = p_goal_id;
  end if;
end;
$$;

revoke all on function public.create_circle_workout_goal(uuid, integer) from public, anon;
revoke all on function public.get_active_circle_workout_goal(uuid) from public, anon;
revoke all on function public.get_circle_workout_goal_progress(uuid) from public, anon;
revoke all on function public.cancel_circle_workout_goal(uuid) from public, anon;
grant execute on function public.create_circle_workout_goal(uuid, integer) to authenticated;
grant execute on function public.get_active_circle_workout_goal(uuid) to authenticated;
grant execute on function public.get_circle_workout_goal_progress(uuid) to authenticated;
grant execute on function public.cancel_circle_workout_goal(uuid) to authenticated;

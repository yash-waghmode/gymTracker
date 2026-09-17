-- Contextual encouragement only: no message body or workout detail is stored.
create table public.circle_goal_nudges (
  id uuid primary key default gen_random_uuid(),
  goal_id uuid not null references public.circle_workout_goals (id) on delete cascade,
  sender_id uuid not null,
  recipient_id uuid not null,
  created_at timestamptz not null,
  constraint circle_goal_nudges_distinct_people_check check (sender_id <> recipient_id),
  constraint circle_goal_nudges_sender_goal_fk
    foreign key (goal_id, sender_id)
    references public.circle_workout_goal_participants (goal_id, user_id),
  constraint circle_goal_nudges_recipient_goal_fk
    foreign key (goal_id, recipient_id)
    references public.circle_workout_goal_participants (goal_id, user_id)
);

create index circle_goal_nudges_cooldown_idx
  on public.circle_goal_nudges (goal_id, sender_id, recipient_id, created_at desc);
create index circle_goal_nudges_recipient_idx
  on public.circle_goal_nudges (goal_id, recipient_id, created_at desc);

alter table public.circle_goal_nudges enable row level security;
revoke all on table public.circle_goal_nudges from anon, authenticated;
grant all on table public.circle_goal_nudges to service_role;

create function public.send_circle_goal_nudge(p_goal_id uuid, p_recipient_id uuid)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  caller_id uuid := (select auth.uid());
  selected_goal public.circle_workout_goals%rowtype;
  sent_at timestamptz;
  nudge_id uuid;
begin
  if caller_id is null then raise insufficient_privilege; end if;
  if p_recipient_id is null or p_recipient_id = caller_id then
    raise invalid_parameter_value using message = 'Choose another eligible member.';
  end if;

  -- Share-locking the goal serializes against owner cancellation. Holding current
  -- membership rows also prevents a concurrent leave until this send commits.
  select * into selected_goal from public.circle_workout_goals
    where id = p_goal_id for share;
  if not found then raise insufficient_privilege; end if;

  perform 1 from public.circle_members
    where circle_id = selected_goal.circle_id
      and user_id in (caller_id, p_recipient_id)
    order by user_id
    for share;
  if (select count(*) from public.circle_members
      where circle_id = selected_goal.circle_id
        and user_id in (caller_id, p_recipient_id)) <> 2
    or not exists (
      select 1 from public.circle_workout_goal_participants
      where goal_id = p_goal_id and user_id = caller_id
    )
    or not exists (
      select 1 from public.circle_workout_goal_participants
      where goal_id = p_goal_id and user_id = p_recipient_id
  ) then
    raise insufficient_privilege using message = 'Goal participant not available.';
  end if;
  if selected_goal.cancelled_at is not null
    or selected_goal.starts_at > clock_timestamp()
    or selected_goal.ends_at <= clock_timestamp() then
    raise invalid_parameter_value using message = 'No active Circle goal.';
  end if;

  -- Same-pair calls serialize before checking the rolling window. Hash collisions
  -- only add contention; they cannot permit duplicate sends.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    p_goal_id::text || ':' || caller_id::text || ':' || p_recipient_id::text, 0
  ));
  sent_at := clock_timestamp();
  if selected_goal.ends_at <= sent_at then
    raise invalid_parameter_value using message = 'No active Circle goal.';
  end if;
  if (
    select count(*) from public.workouts
    where owner_id = p_recipient_id
      and completed_at >= selected_goal.starts_at
      and completed_at < selected_goal.ends_at
  ) >= selected_goal.target_workouts then
    raise invalid_parameter_value using message = 'Member already reached the goal.';
  end if;
  if exists (
    select 1 from public.circle_goal_nudges
    where goal_id = p_goal_id and sender_id = caller_id
      and recipient_id = p_recipient_id
      and created_at > sent_at - interval '24 hours'
  ) then
    raise invalid_parameter_value using message = 'You recently nudged this member.';
  end if;

  insert into public.circle_goal_nudges (
    goal_id, sender_id, recipient_id, created_at
  ) values (p_goal_id, caller_id, p_recipient_id, sent_at)
  returning id into nudge_id;
  return nudge_id;
end;
$$;

create function public.get_my_circle_goal_nudges(p_goal_id uuid)
returns table (
  nudge_id uuid, sender_display_name text, circle_name text,
  created_at timestamptz
)
language plpgsql security definer set search_path = '' stable as $$
declare
  caller_id uuid := (select auth.uid());
begin
  if caller_id is null or not exists (
    select 1 from public.circle_workout_goals as goal
    join public.circle_members as member
      on member.circle_id = goal.circle_id and member.user_id = caller_id
    where goal.id = p_goal_id
  ) then raise insufficient_privilege; end if;

  return query
    select nudge.id,
      case when sender_member.user_id is not null then sender.display_name
        else null end,
      circle.name, nudge.created_at
    from public.circle_goal_nudges as nudge
    join public.circle_workout_goals as goal on goal.id = nudge.goal_id
    join public.gym_circles as circle on circle.id = goal.circle_id
    join public.profiles as sender on sender.id = nudge.sender_id
    left join public.circle_members as sender_member
      on sender_member.circle_id = goal.circle_id
      and sender_member.user_id = nudge.sender_id
    where nudge.goal_id = p_goal_id and nudge.recipient_id = caller_id
    order by nudge.created_at desc, nudge.id desc;
end;
$$;

revoke all on function public.send_circle_goal_nudge(uuid, uuid) from public, anon;
revoke all on function public.get_my_circle_goal_nudges(uuid) from public, anon;
grant execute on function public.send_circle_goal_nudge(uuid, uuid) to authenticated;
grant execute on function public.get_my_circle_goal_nudges(uuid) to authenticated;

-- Current Circle members may see session presence, never personal workout contents.
create function public.get_shared_session_participants(p_session_id uuid)
returns table (
  user_id uuid,
  display_name text,
  workout_finished boolean
)
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
  target_circle_id uuid;
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'Authentication required.';
  end if;

  select sessions.circle_id into target_circle_id
  from public.workout_sessions as sessions
  where sessions.id = p_session_id and sessions.is_shared;

  if not found or target_circle_id is null
    or not private.is_circle_member(target_circle_id) then
    raise insufficient_privilege using message = 'Session not found.';
  end if;

  return query
    select participants.user_id, profiles.display_name,
      workouts.completed_at is not null
    from public.session_participants as participants
    join public.circle_members as members
      on members.circle_id = target_circle_id
      and members.user_id = participants.user_id
    join public.profiles as profiles on profiles.id = participants.user_id
    join public.workouts as workouts
      on workouts.session_id = participants.session_id
      and workouts.owner_id = participants.user_id
    where participants.session_id = p_session_id
      and participants.left_at is null
    order by participants.joined_at, participants.user_id;
end;
$$;

comment on function public.get_shared_session_participants(uuid) is
  'Current Circle members see only participant identities and whether each personal workout is finished.';

revoke all on function public.get_shared_session_participants(uuid)
  from public, anon;
grant execute on function public.get_shared_session_participants(uuid)
  to authenticated;

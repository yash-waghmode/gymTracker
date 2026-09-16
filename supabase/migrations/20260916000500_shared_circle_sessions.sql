-- Shared sessions carry social context only; every participant still owns one workout.
alter table public.workout_sessions
  add column is_shared boolean not null default false,
  add column circle_id uuid references public.gym_circles (id) on delete set null,
  add constraint shared_sessions_circle_check check (is_shared or circle_id is null);

create index workout_sessions_active_circle_idx
  on public.workout_sessions (circle_id, started_at desc)
  where is_shared and status = 'active';

comment on column public.workout_sessions.circle_id is
  'Nullable social association. Circle deletion detaches the session without deleting personal workouts.';
comment on column public.workout_sessions.is_shared is
  'Retained after Circle deletion so an orphaned shared session never becomes a solo session.';

-- A participant can read session presence only while currently in its Circle.
-- Historical personal workouts remain separately readable through owner RLS.
create function private.can_read_session_context(target_session_id uuid)
returns boolean language sql security definer set search_path = '' stable as $$
  select exists (
    select 1 from public.workout_sessions as sessions
    where sessions.id = target_session_id
      and (not sessions.is_shared or private.is_circle_member(sessions.circle_id))
  );
$$;
create function private.is_solo_session(target_session_id uuid)
returns boolean language sql security definer set search_path = '' stable as $$
  select exists (
    select 1 from public.workout_sessions as sessions
    where sessions.id = target_session_id and not sessions.is_shared
  );
$$;
revoke all on function private.can_read_session_context(uuid) from public;
revoke all on function private.is_solo_session(uuid) from public;
grant execute on function private.can_read_session_context(uuid) to authenticated;
grant execute on function private.is_solo_session(uuid) to authenticated;

drop policy "participants read sessions" on public.workout_sessions;
create policy "participants read sessions" on public.workout_sessions
  for select to authenticated using (
    (not is_shared or private.is_circle_member(circle_id))
    and ((select auth.uid()) = created_by or private.is_session_participant(id))
  );
drop policy "users create sessions" on public.workout_sessions;
create policy "users create sessions" on public.workout_sessions
  for insert to authenticated with check (
    (select auth.uid()) = created_by and not is_shared and circle_id is null
  );
drop policy "creators update sessions" on public.workout_sessions;
create policy "creators update sessions" on public.workout_sessions
  for update to authenticated using ((select auth.uid()) = created_by and not is_shared)
  with check ((select auth.uid()) = created_by and not is_shared and circle_id is null);
drop policy "creators delete empty sessions" on public.workout_sessions;
create policy "creators delete empty sessions" on public.workout_sessions
  for delete to authenticated using ((select auth.uid()) = created_by and not is_shared);

drop policy "participants read session membership" on public.session_participants;
create policy "participants read session membership" on public.session_participants
  for select to authenticated using (
    private.can_read_session_context(session_id)
    and (private.is_session_participant(session_id) or private.is_session_creator(session_id))
  );
drop policy "session creators add participants" on public.session_participants;
create policy "session creators add participants" on public.session_participants
  for insert to authenticated with check (
    private.is_solo_session(session_id) and private.is_session_creator(session_id)
  );
drop policy "participants leave sessions" on public.session_participants;
create policy "participants leave sessions" on public.session_participants
  for update to authenticated
  using ((select auth.uid()) = user_id and private.is_solo_session(session_id))
  with check ((select auth.uid()) = user_id and left_at is not null
    and private.is_solo_session(session_id));

-- Solo completion remains automatic. A shared session is only closed explicitly.
create or replace function private.guard_completion() returns trigger
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
    update public.workout_sessions set status = 'completed', ended_at = new.completed_at
      where id = old.session_id and created_by = auth.uid() and not is_shared
      and (select count(*) from public.session_participants where session_id = old.session_id) = 1;
  end if;
  return new;
end;
$$;

-- Circle deletion closes its active context before the FK detaches it. Workout
-- rows and still-active personal workouts are deliberately untouched.
create function private.close_circle_sessions_on_delete() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.workout_sessions
    set status = 'completed', ended_at = now()
    where circle_id = old.id and is_shared and status = 'active';
  return old;
end;
$$;
revoke all on function private.close_circle_sessions_on_delete() from public;
create trigger gym_circle_close_sessions
  before delete on public.gym_circles
  for each row execute function private.close_circle_sessions_on_delete();

create function public.start_shared_session(p_circle_id uuid, p_routine uuid default null)
returns table (session_id uuid, workout_id uuid)
language plpgsql security definer set search_path = '' as $$
declare
  caller_id uuid := (select auth.uid());
  workout_title text := 'Free workout';
begin
  if caller_id is null then raise insufficient_privilege; end if;
  perform pg_advisory_xact_lock(hashtextextended(caller_id::text, 0));
  if exists (select 1 from public.workouts where owner_id = caller_id and completed_at is null) then
    raise invalid_parameter_value using message = 'Finish the active workout before starting another.';
  end if;
  perform 1 from public.gym_circles where id = p_circle_id for share;
  if not found then raise insufficient_privilege; end if;
  perform 1 from public.circle_members
    where circle_id = p_circle_id and user_id = caller_id for share;
  if not found then raise insufficient_privilege; end if;
  if p_routine is not null then
    select name into workout_title from public.routines
      where id = p_routine and owner_id = caller_id for update;
    if workout_title is null then raise insufficient_privilege; end if;
  end if;
  insert into public.workout_sessions (created_by, title, started_at, is_shared, circle_id)
    values (caller_id, 'Shared workout', now(), true, p_circle_id)
    returning id into session_id;
  insert into public.workouts (session_id, owner_id, routine_id, title)
    values (session_id, caller_id, p_routine, workout_title)
    returning id into workout_id;
  insert into public.workout_exercises (workout_id, owner_id, exercise_id, position)
    select workout_id, caller_id, exercise_id, position
    from public.routine_exercises where routine_id = p_routine order by position;
  return next;
end;
$$;

create function public.join_shared_session(p_session_id uuid, p_routine uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  caller_id uuid := (select auth.uid());
  target_session public.workout_sessions;
  result_id uuid;
  workout_title text := 'Free workout';
begin
  if caller_id is null then raise insufficient_privilege; end if;
  perform pg_advisory_xact_lock(hashtextextended(caller_id::text, 0));
  select * into target_session from public.workout_sessions
    where id = p_session_id and is_shared for update;
  if target_session.id is null or target_session.circle_id is null then
    raise insufficient_privilege;
  end if;
  perform 1 from public.circle_members
    where circle_id = target_session.circle_id and user_id = caller_id for share;
  if not found then raise insufficient_privilege; end if;
  select id into result_id from public.workouts
    where session_id = p_session_id and owner_id = caller_id;
  if result_id is not null then return result_id; end if;
  if target_session.status <> 'active' then
    raise invalid_parameter_value using message = 'Shared session has ended.';
  end if;
  if exists (select 1 from public.workouts where owner_id = caller_id and completed_at is null) then
    raise invalid_parameter_value using message = 'Finish the active workout before joining.';
  end if;
  if p_routine is not null then
    select name into workout_title from public.routines
      where id = p_routine and owner_id = caller_id for update;
    if workout_title is null then raise insufficient_privilege; end if;
  end if;
  insert into public.session_participants (session_id, user_id)
    values (p_session_id, caller_id);
  insert into public.workouts (session_id, owner_id, routine_id, title)
    values (p_session_id, caller_id, p_routine, workout_title)
    returning id into result_id;
  insert into public.workout_exercises (workout_id, owner_id, exercise_id, position)
    select result_id, caller_id, exercise_id, position
    from public.routine_exercises where routine_id = p_routine order by position;
  return result_id;
end;
$$;

create function public.end_shared_session(p_session_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare target_session public.workout_sessions;
begin
  if (select auth.uid()) is null then raise insufficient_privilege; end if;
  select * into target_session from public.workout_sessions
    where id = p_session_id and is_shared for update;
  if target_session.id is null or target_session.created_by <> (select auth.uid())
    or target_session.circle_id is null
    or not private.is_circle_member(target_session.circle_id) then raise insufficient_privilege; end if;
  if target_session.status = 'active' then
    update public.workout_sessions set status = 'completed', ended_at = now()
      where id = p_session_id;
  end if;
end;
$$;

create function public.get_active_shared_sessions(p_circle_id uuid)
returns table (
  session_id uuid, circle_id uuid, started_at timestamptz,
  created_by uuid, creator_display_name text, status text, participant_count bigint
)
language plpgsql security definer set search_path = '' stable as $$
begin
  if (select auth.uid()) is null or not private.is_circle_member(p_circle_id) then
    raise insufficient_privilege;
  end if;
  return query
    select sessions.id, sessions.circle_id, sessions.started_at,
      sessions.created_by, profiles.display_name, sessions.status,
      (select count(*) from public.session_participants as participants
       join public.circle_members as members
         on members.circle_id = sessions.circle_id and members.user_id = participants.user_id
       where participants.session_id = sessions.id and participants.left_at is null)
    from public.workout_sessions as sessions
    join public.profiles as profiles on profiles.id = sessions.created_by
    where sessions.circle_id = p_circle_id and sessions.is_shared and sessions.status = 'active'
    order by sessions.started_at desc, sessions.id;
end;
$$;

revoke all on function public.start_shared_session(uuid, uuid) from public, anon;
revoke all on function public.join_shared_session(uuid, uuid) from public, anon;
revoke all on function public.end_shared_session(uuid) from public, anon;
revoke all on function public.get_active_shared_sessions(uuid) from public, anon;
grant execute on function public.start_shared_session(uuid, uuid) to authenticated;
grant execute on function public.join_shared_session(uuid, uuid) to authenticated;
grant execute on function public.end_shared_session(uuid) to authenticated;
grant execute on function public.get_active_shared_sessions(uuid) to authenticated;

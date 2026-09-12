create schema if not exists private;
revoke all on schema private from public;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text check (
    display_name is null
    or char_length(btrim(display_name)) between 1 and 80
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.exercises (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles (id) on delete restrict,
  name text not null check (char_length(btrim(name)) between 1 and 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on column public.exercises.owner_id is
  'Null for the shared built-in catalog; otherwise the owning user.';

create unique index exercises_builtin_name_key
  on public.exercises (lower(name))
  where owner_id is null;
create unique index exercises_owner_name_key
  on public.exercises (owner_id, lower(name))
  where owner_id is not null;
create index exercises_owner_id_idx on public.exercises (owner_id);

create table public.routines (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete restrict,
  name text not null check (char_length(btrim(name)) between 1 and 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint routines_id_owner_key unique (id, owner_id)
);

create index routines_owner_id_idx on public.routines (owner_id);

create table public.routine_exercises (
  id uuid primary key default gen_random_uuid(),
  routine_id uuid not null,
  owner_id uuid not null,
  exercise_id uuid not null references public.exercises (id) on delete restrict,
  position smallint not null check (position >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint routine_exercises_routine_owner_fk
    foreign key (routine_id, owner_id)
    references public.routines (id, owner_id)
    on delete cascade,
  constraint routine_exercises_routine_position_key unique (routine_id, position)
);

create index routine_exercises_owner_id_idx
  on public.routine_exercises (owner_id);
create index routine_exercises_exercise_id_idx
  on public.routine_exercises (exercise_id);

create table public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles (id) on delete restrict,
  title text check (title is null or char_length(btrim(title)) between 1 and 120),
  status text not null default 'active'
    check (status in ('planned', 'active', 'completed', 'cancelled')),
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workout_sessions_time_order_check check (
    ended_at is null or started_at is null or ended_at >= started_at
  )
);

create index workout_sessions_created_by_idx
  on public.workout_sessions (created_by);

create table public.session_participants (
  session_id uuid not null references public.workout_sessions (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete restrict,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (session_id, user_id),
  constraint session_participants_time_order_check check (
    left_at is null or left_at >= joined_at
  )
);

create index session_participants_user_id_idx
  on public.session_participants (user_id);

create table public.workouts (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null,
  owner_id uuid not null,
  routine_id uuid references public.routines (id) on delete set null,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  notes text check (notes is null or char_length(notes) <= 4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workouts_session_owner_fk
    foreign key (session_id, owner_id)
    references public.session_participants (session_id, user_id)
    on delete restrict,
  constraint workouts_session_owner_key unique (session_id, owner_id),
  constraint workouts_id_owner_key unique (id, owner_id),
  constraint workouts_time_order_check check (
    completed_at is null or completed_at >= started_at
  )
);

comment on table public.workouts is
  'One individually owned workout record per participant in a shared or solo session.';

create index workouts_owner_id_idx on public.workouts (owner_id);
create index workouts_session_id_idx on public.workouts (session_id);
create index workouts_routine_id_idx on public.workouts (routine_id);
create index workouts_owner_started_at_idx
  on public.workouts (owner_id, started_at desc);

create table public.workout_exercises (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid not null,
  owner_id uuid not null,
  exercise_id uuid not null references public.exercises (id) on delete restrict,
  position smallint not null check (position >= 0),
  notes text check (notes is null or char_length(notes) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workout_exercises_workout_owner_fk
    foreign key (workout_id, owner_id)
    references public.workouts (id, owner_id)
    on delete cascade,
  constraint workout_exercises_workout_position_key unique (workout_id, position),
  constraint workout_exercises_id_owner_key unique (id, owner_id)
);

create index workout_exercises_owner_id_idx
  on public.workout_exercises (owner_id);
create index workout_exercises_exercise_id_idx
  on public.workout_exercises (exercise_id);

create table public.workout_sets (
  id uuid primary key default gen_random_uuid(),
  workout_exercise_id uuid not null,
  owner_id uuid not null,
  position smallint not null check (position >= 0),
  reps smallint not null check (reps >= 0),
  weight_kg numeric(8, 3) check (weight_kg is null or weight_kg >= 0),
  performed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workout_sets_exercise_owner_fk
    foreign key (workout_exercise_id, owner_id)
    references public.workout_exercises (id, owner_id)
    on delete cascade,
  constraint workout_sets_exercise_position_key
    unique (workout_exercise_id, position)
);

comment on column public.workout_sets.weight_kg is
  'Canonical stored load in kilograms; presentation units are a user preference.';

create index workout_sets_owner_id_idx on public.workout_sets (owner_id);
create index workout_sets_performed_at_idx on public.workout_sets (performed_at desc);

create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    left(nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''), 80)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create function private.add_session_creator_as_participant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.session_participants (session_id, user_id)
  values (new.id, new.created_by);
  return new;
end;
$$;

create function private.validate_exercise_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  exercise_owner uuid;
begin
  select owner_id
  into exercise_owner
  from public.exercises
  where id = new.exercise_id;

  if not found then
    raise foreign_key_violation using message = 'Exercise does not exist.';
  end if;

  if exercise_owner is not null and exercise_owner <> new.owner_id then
    raise insufficient_privilege using
      message = 'Exercise must be built-in or owned by the same user.';
  end if;

  return new;
end;
$$;

create function private.validate_workout_routine_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  routine_owner uuid;
begin
  if new.routine_id is null then
    return new;
  end if;

  select owner_id
  into routine_owner
  from public.routines
  where id = new.routine_id;

  if not found then
    raise foreign_key_violation using message = 'Routine does not exist.';
  end if;

  if routine_owner <> new.owner_id then
    raise insufficient_privilege using
      message = 'Workout routine must belong to the workout owner.';
  end if;

  return new;
end;
$$;

create function private.prevent_participant_identity_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.session_id <> old.session_id or new.user_id <> old.user_id then
    raise insufficient_privilege using
      message = 'Session participant identity cannot be changed.';
  end if;
  return new;
end;
$$;

create function private.is_session_participant(target_session_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.session_participants
    where session_id = target_session_id
      and user_id = (select auth.uid())
      and left_at is null
  );
$$;

create function private.is_session_creator(target_session_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.workout_sessions
    where id = target_session_id
      and created_by = (select auth.uid())
  );
$$;

revoke all on function private.set_updated_at() from public;
revoke all on function private.handle_new_user() from public;
revoke all on function private.add_session_creator_as_participant() from public;
revoke all on function private.validate_exercise_owner() from public;
revoke all on function private.validate_workout_routine_owner() from public;
revoke all on function private.prevent_participant_identity_change() from public;
revoke all on function private.is_session_participant(uuid) from public;
revoke all on function private.is_session_creator(uuid) from public;
grant usage on schema private to authenticated;
grant execute on function private.is_session_participant(uuid) to authenticated;
grant execute on function private.is_session_creator(uuid) to authenticated;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();
create trigger exercises_set_updated_at
before update on public.exercises
for each row execute function private.set_updated_at();
create trigger routines_set_updated_at
before update on public.routines
for each row execute function private.set_updated_at();
create trigger routine_exercises_set_updated_at
before update on public.routine_exercises
for each row execute function private.set_updated_at();
create trigger workout_sessions_set_updated_at
before update on public.workout_sessions
for each row execute function private.set_updated_at();
create trigger session_participants_set_updated_at
before update on public.session_participants
for each row execute function private.set_updated_at();
create trigger workouts_set_updated_at
before update on public.workouts
for each row execute function private.set_updated_at();
create trigger workout_exercises_set_updated_at
before update on public.workout_exercises
for each row execute function private.set_updated_at();
create trigger workout_sets_set_updated_at
before update on public.workout_sets
for each row execute function private.set_updated_at();

create trigger auth_user_created
after insert on auth.users
for each row execute function private.handle_new_user();
create trigger workout_session_created
after insert on public.workout_sessions
for each row execute function private.add_session_creator_as_participant();
create trigger routine_exercise_validate_owner
before insert or update on public.routine_exercises
for each row execute function private.validate_exercise_owner();
create trigger workout_exercise_validate_owner
before insert or update on public.workout_exercises
for each row execute function private.validate_exercise_owner();
create trigger workout_validate_routine_owner
before insert or update on public.workouts
for each row execute function private.validate_workout_routine_owner();
create trigger session_participant_prevent_identity_change
before update on public.session_participants
for each row execute function private.prevent_participant_identity_change();

alter table public.profiles enable row level security;
alter table public.exercises enable row level security;
alter table public.routines enable row level security;
alter table public.routine_exercises enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.session_participants enable row level security;
alter table public.workouts enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.workout_sets enable row level security;

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.exercises from anon, authenticated;
revoke all on table public.routines from anon, authenticated;
revoke all on table public.routine_exercises from anon, authenticated;
revoke all on table public.workout_sessions from anon, authenticated;
revoke all on table public.session_participants from anon, authenticated;
revoke all on table public.workouts from anon, authenticated;
revoke all on table public.workout_exercises from anon, authenticated;
revoke all on table public.workout_sets from anon, authenticated;

grant all on table public.profiles to service_role;
grant all on table public.exercises to service_role;
grant all on table public.routines to service_role;
grant all on table public.routine_exercises to service_role;
grant all on table public.workout_sessions to service_role;
grant all on table public.session_participants to service_role;
grant all on table public.workouts to service_role;
grant all on table public.workout_exercises to service_role;
grant all on table public.workout_sets to service_role;

grant select on table public.profiles to authenticated;
grant update (display_name) on table public.profiles to authenticated;
grant select, insert, delete on table public.exercises to authenticated;
grant update (name) on table public.exercises to authenticated;
grant select, insert, delete on table public.routines to authenticated;
grant update (name) on table public.routines to authenticated;
grant select, insert, delete on table public.routine_exercises to authenticated;
grant update (exercise_id, position) on table public.routine_exercises to authenticated;
grant select, insert, delete on table public.workout_sessions to authenticated;
grant update (title, status, started_at, ended_at)
  on table public.workout_sessions to authenticated;
grant select, insert on table public.session_participants to authenticated;
grant update (left_at) on table public.session_participants to authenticated;
grant select, insert, delete on table public.workouts to authenticated;
grant update (routine_id, started_at, completed_at, notes)
  on table public.workouts to authenticated;
grant select, insert, delete on table public.workout_exercises to authenticated;
grant update (exercise_id, position, notes)
  on table public.workout_exercises to authenticated;
grant select, insert, delete on table public.workout_sets to authenticated;
grant update (position, reps, weight_kg, performed_at)
  on table public.workout_sets to authenticated;

create policy "users read own profile"
on public.profiles for select to authenticated
using ((select auth.uid()) = id);
create policy "users update own profile"
on public.profiles for update to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "users read built-in or own exercises"
on public.exercises for select to authenticated
using (owner_id is null or (select auth.uid()) = owner_id);
create policy "users create own exercises"
on public.exercises for insert to authenticated
with check ((select auth.uid()) = owner_id);
create policy "users update own exercises"
on public.exercises for update to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);
create policy "users delete own exercises"
on public.exercises for delete to authenticated
using ((select auth.uid()) = owner_id);

create policy "users read own routines"
on public.routines for select to authenticated
using ((select auth.uid()) = owner_id);
create policy "users create own routines"
on public.routines for insert to authenticated
with check ((select auth.uid()) = owner_id);
create policy "users update own routines"
on public.routines for update to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);
create policy "users delete own routines"
on public.routines for delete to authenticated
using ((select auth.uid()) = owner_id);

create policy "users read own routine exercises"
on public.routine_exercises for select to authenticated
using ((select auth.uid()) = owner_id);
create policy "users create own routine exercises"
on public.routine_exercises for insert to authenticated
with check ((select auth.uid()) = owner_id);
create policy "users update own routine exercises"
on public.routine_exercises for update to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);
create policy "users delete own routine exercises"
on public.routine_exercises for delete to authenticated
using ((select auth.uid()) = owner_id);

create policy "participants read sessions"
on public.workout_sessions for select to authenticated
using (
  (select auth.uid()) = created_by
  or private.is_session_participant(id)
);
create policy "users create sessions"
on public.workout_sessions for insert to authenticated
with check ((select auth.uid()) = created_by);
create policy "creators update sessions"
on public.workout_sessions for update to authenticated
using ((select auth.uid()) = created_by)
with check ((select auth.uid()) = created_by);
create policy "creators delete empty sessions"
on public.workout_sessions for delete to authenticated
using ((select auth.uid()) = created_by);

create policy "participants read session membership"
on public.session_participants for select to authenticated
using (
  private.is_session_participant(session_id)
  or private.is_session_creator(session_id)
);
create policy "session creators add participants"
on public.session_participants for insert to authenticated
with check (private.is_session_creator(session_id));
create policy "participants leave sessions"
on public.session_participants for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id and left_at is not null);

create policy "users read own workouts"
on public.workouts for select to authenticated
using ((select auth.uid()) = owner_id);
create policy "users create own workouts"
on public.workouts for insert to authenticated
with check (
  (select auth.uid()) = owner_id
  and private.is_session_participant(session_id)
);
create policy "users update own workouts"
on public.workouts for update to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);
create policy "users delete own workouts"
on public.workouts for delete to authenticated
using ((select auth.uid()) = owner_id);

create policy "users read own workout exercises"
on public.workout_exercises for select to authenticated
using ((select auth.uid()) = owner_id);
create policy "users create own workout exercises"
on public.workout_exercises for insert to authenticated
with check ((select auth.uid()) = owner_id);
create policy "users update own workout exercises"
on public.workout_exercises for update to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);
create policy "users delete own workout exercises"
on public.workout_exercises for delete to authenticated
using ((select auth.uid()) = owner_id);

create policy "users read own workout sets"
on public.workout_sets for select to authenticated
using ((select auth.uid()) = owner_id);
create policy "users create own workout sets"
on public.workout_sets for insert to authenticated
with check ((select auth.uid()) = owner_id);
create policy "users update own workout sets"
on public.workout_sets for update to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);
create policy "users delete own workout sets"
on public.workout_sets for delete to authenticated
using ((select auth.uid()) = owner_id);

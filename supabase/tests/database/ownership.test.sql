begin;

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '00000000-0000-0000-0000-00000000000a',
    'user-a@example.test',
    '{"display_name":"User A"}'::jsonb
  ),
  (
    '00000000-0000-0000-0000-00000000000b',
    'user-b@example.test',
    '{"display_name":"User B"}'::jsonb
  );

do $$
declare
  protected_table_count integer;
begin
  select count(*)
  into protected_table_count
  from pg_class
  where oid in (
    'public.profiles'::regclass,
    'public.exercises'::regclass,
    'public.routines'::regclass,
    'public.routine_exercises'::regclass,
    'public.workout_sessions'::regclass,
    'public.session_participants'::regclass,
    'public.workouts'::regclass,
    'public.workout_exercises'::regclass,
    'public.workout_sets'::regclass
  )
  and relrowsecurity;

  if protected_table_count <> 9 then
    raise exception 'Expected RLS on all 9 public tables, found %', protected_table_count;
  end if;
end;
$$;

set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-00000000000a',
  false
);

insert into public.exercises (id, owner_id, name)
values (
  '00000000-0000-0000-0000-000000000200',
  '00000000-0000-0000-0000-00000000000a',
  'User A press'
);
insert into public.routines (id, owner_id, name)
values (
  '00000000-0000-0000-0000-000000000300',
  '00000000-0000-0000-0000-00000000000a',
  'User A routine'
);
insert into public.routine_exercises (
  id,
  routine_id,
  owner_id,
  exercise_id,
  position
)
values (
  '00000000-0000-0000-0000-000000000310',
  '00000000-0000-0000-0000-000000000300',
  '00000000-0000-0000-0000-00000000000a',
  '00000000-0000-0000-0000-000000000200',
  0
);
insert into public.workout_sessions (id, created_by, title)
values (
  '00000000-0000-0000-0000-000000000100',
  '00000000-0000-0000-0000-00000000000a',
  'Shared session'
);
insert into public.session_participants (session_id, user_id)
values (
  '00000000-0000-0000-0000-000000000100',
  '00000000-0000-0000-0000-00000000000b'
);
insert into public.workout_sessions (id, created_by, title)
values (
  '00000000-0000-0000-0000-000000000102',
  '00000000-0000-0000-0000-00000000000a',
  'Leave before logging'
);
insert into public.session_participants (session_id, user_id)
values (
  '00000000-0000-0000-0000-000000000102',
  '00000000-0000-0000-0000-00000000000b'
);
insert into public.workouts (id, session_id, owner_id, routine_id)
values (
  '00000000-0000-0000-0000-000000000400',
  '00000000-0000-0000-0000-000000000100',
  '00000000-0000-0000-0000-00000000000a',
  '00000000-0000-0000-0000-000000000300'
);
insert into public.workout_exercises (
  id,
  workout_id,
  owner_id,
  exercise_id,
  position
)
values (
  '00000000-0000-0000-0000-000000000500',
  '00000000-0000-0000-0000-000000000400',
  '00000000-0000-0000-0000-00000000000a',
  '00000000-0000-0000-0000-000000000200',
  0
);
insert into public.workout_sets (
  id,
  workout_exercise_id,
  owner_id,
  position,
  reps,
  weight_kg
)
values (
  '00000000-0000-0000-0000-000000000600',
  '00000000-0000-0000-0000-000000000500',
  '00000000-0000-0000-0000-00000000000a',
  0,
  5,
  100
);

do $$
declare
  changed_rows integer;
begin
  update public.workout_sets
  set weight_kg = 102.5
  where id = '00000000-0000-0000-0000-000000000600';
  get diagnostics changed_rows = row_count;
  if changed_rows <> 1 then
    raise exception 'User A could not update their own set';
  end if;
end;
$$;

reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-00000000000b',
  false
);

do $$
begin
  if exists (
    select 1
    from public.workouts
    where id = '00000000-0000-0000-0000-000000000400'
  ) then
    raise exception 'User B can read User A workout';
  end if;
end;
$$;

insert into public.exercises (id, owner_id, name)
values (
  '00000000-0000-0000-0000-000000000201',
  '00000000-0000-0000-0000-00000000000b',
  'User B row'
);
insert into public.workouts (id, session_id, owner_id)
values (
  '00000000-0000-0000-0000-000000000401',
  '00000000-0000-0000-0000-000000000100',
  '00000000-0000-0000-0000-00000000000b'
);
insert into public.workout_exercises (
  id,
  workout_id,
  owner_id,
  exercise_id,
  position
)
values (
  '00000000-0000-0000-0000-000000000501',
  '00000000-0000-0000-0000-000000000401',
  '00000000-0000-0000-0000-00000000000b',
  '00000000-0000-0000-0000-000000000201',
  0
);
insert into public.workout_sets (
  id,
  workout_exercise_id,
  owner_id,
  position,
  reps,
  weight_kg
)
values (
  '00000000-0000-0000-0000-000000000601',
  '00000000-0000-0000-0000-000000000501',
  '00000000-0000-0000-0000-00000000000b',
  0,
  8,
  40
);

update public.session_participants
set left_at = now()
where session_id in (
    '00000000-0000-0000-0000-000000000100',
    '00000000-0000-0000-0000-000000000102'
  )
  and user_id = '00000000-0000-0000-0000-00000000000b';

do $$
begin
  if not exists (
    select 1
    from public.workouts
    where id = '00000000-0000-0000-0000-000000000401'
  ) then
    raise exception 'Leaving a shared session hid User B workout history';
  end if;

  if exists (
    select 1
    from public.workout_sessions
    where id = '00000000-0000-0000-0000-000000000100'
  ) then
    raise exception 'Former participant retained shared session visibility';
  end if;
end;
$$;

do $$
declare
  changed_rows integer;
begin
  update public.workouts
  set notes = 'unauthorized change'
  where id = '00000000-0000-0000-0000-000000000400';
  get diagnostics changed_rows = row_count;
  if changed_rows <> 0 then
    raise exception 'Shared-session member updated another owner workout';
  end if;

  delete from public.workout_sets
  where id = '00000000-0000-0000-0000-000000000600';
  get diagnostics changed_rows = row_count;
  if changed_rows <> 0 then
    raise exception 'Shared-session member deleted another owner set';
  end if;
end;
$$;

do $$
begin
  begin
    insert into public.workout_exercises (
      id,
      workout_id,
      owner_id,
      exercise_id,
      position
    )
    values (
      '00000000-0000-0000-0000-000000000502',
      '00000000-0000-0000-0000-000000000401',
      '00000000-0000-0000-0000-00000000000b',
      '00000000-0000-0000-0000-000000000200',
      1
    );
    raise exception 'Cross-user exercise relationship unexpectedly succeeded';
  exception
    when insufficient_privilege then null;
  end;

  begin
    insert into public.workout_sets (
      id,
      workout_exercise_id,
      owner_id,
      position,
      reps
    )
    values (
      '00000000-0000-0000-0000-000000000602',
      '00000000-0000-0000-0000-000000000500',
      '00000000-0000-0000-0000-00000000000b',
      1,
      5
    );
    raise exception 'Cross-user set relationship unexpectedly succeeded';
  exception
    when foreign_key_violation then null;
  end;

  begin
    insert into public.workouts (id, session_id, owner_id)
    values (
      '00000000-0000-0000-0000-000000000402',
      '00000000-0000-0000-0000-000000000100',
      '00000000-0000-0000-0000-00000000000a'
    );
    raise exception 'User B created a workout owned by User A';
  exception
    when insufficient_privilege then null;
  end;

  begin
    insert into public.workouts (id, session_id, owner_id)
    values (
      '00000000-0000-0000-0000-000000000404',
      '00000000-0000-0000-0000-000000000102',
      '00000000-0000-0000-0000-00000000000b'
    );
    raise exception 'Former participant created a new workout after leaving';
  exception
    when insufficient_privilege then null;
  end;
end;
$$;

insert into public.workout_sessions (id, created_by, title)
values (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-00000000000b',
  'Solo session'
);

do $$
begin
  if (
    select count(*)
    from public.session_participants
    where session_id = '00000000-0000-0000-0000-000000000101'
  ) <> 1 then
    raise exception 'New solo session did not contain exactly its creator';
  end if;

  begin
    insert into public.workouts (id, session_id, owner_id, routine_id)
    values (
      '00000000-0000-0000-0000-000000000403',
      '00000000-0000-0000-0000-000000000101',
      '00000000-0000-0000-0000-00000000000b',
      '00000000-0000-0000-0000-000000000300'
    );
    raise exception 'Cross-user routine relationship unexpectedly succeeded';
  exception
    when insufficient_privilege then null;
  end;
end;
$$;

reset role;

do $$
begin
  if (
    select count(distinct owner_id)
    from public.workouts
    where session_id = '00000000-0000-0000-0000-000000000100'
  ) <> 2 then
    raise exception 'Shared session did not preserve two distinct workout owners';
  end if;

  if (
    select weight_kg
    from public.workout_sets
    where id = '00000000-0000-0000-0000-000000000600'
  ) <> 102.5 then
    raise exception 'User A set was changed by another user';
  end if;
end;
$$;

select '1..1';
select 'ok 1 - workout ownership and shared-session isolation';

rollback;

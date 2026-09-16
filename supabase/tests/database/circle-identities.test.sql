begin;

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '40000000-0000-0000-0000-000000000001',
    'identity-a@example.test',
    '{"display_name":"Asha Owner"}'::jsonb
  ),
  (
    '40000000-0000-0000-0000-000000000002',
    'identity-b@example.test',
    '{"display_name":"Ben Member"}'::jsonb
  ),
  (
    '40000000-0000-0000-0000-000000000003',
    'identity-c@example.test',
    '{"display_name":"Casey Unrelated"}'::jsonb
  );

set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '40000000-0000-0000-0000-000000000002',
  true
);

do $$
declare
  routine_id uuid;
  created_workout_id uuid;
  workout_exercise_id uuid;
  exercise_id uuid;
begin
  update public.profiles
  set display_name = 'Ben Strong'
  where id = auth.uid();

  if (
    select display_name from public.profiles where id = auth.uid()
  ) <> 'Ben Strong' then
    raise exception 'User could not read and update their own display name';
  end if;

  select id into exercise_id
  from public.exercises
  where name = 'Barbell squat' and owner_id is null;

  routine_id := public.save_routine(
    null,
    'Ben private routine',
    array[exercise_id]
  );
  created_workout_id := public.start_workout(routine_id);
  select id into workout_exercise_id
  from public.workout_exercises
  where workout_exercises.workout_id = created_workout_id;
  perform public.change_workout(
    created_workout_id,
    'add_set',
    workout_exercise_id,
    90,
    5
  );
  perform public.change_workout(created_workout_id, 'finish');

  perform set_config('test.identity_routine_id', routine_id::text, true);
  perform set_config(
    'test.identity_workout_id',
    created_workout_id::text,
    true
  );
end;
$$;

reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '40000000-0000-0000-0000-000000000001',
  true
);

select set_config(
  'test.identity_circle_id',
  public.create_circle('Identity test Circle')::text,
  true
);

do $$
begin
  perform set_config(
    'test.identity_invite_token',
    (select token from public.create_circle_invite(
      current_setting('test.identity_circle_id')::uuid
    )),
    true
  );
end;
$$;

reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '40000000-0000-0000-0000-000000000002',
  true
);
select public.accept_circle_invite(
  current_setting('test.identity_invite_token')
);

reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '40000000-0000-0000-0000-000000000001',
  true
);

do $$
declare
  target_circle_id uuid := current_setting('test.identity_circle_id')::uuid;
begin
  if (
    select display_name
    from public.get_circle_member_identities(target_circle_id)
    where user_id = '40000000-0000-0000-0000-000000000002'
  ) <> 'Ben Strong' then
    raise exception 'Circle member could not read co-member display identity';
  end if;

  if exists (
    select 1 from public.profiles
    where id = '40000000-0000-0000-0000-000000000002'
  ) then
    raise exception 'Circle membership exposed the co-member profile row';
  end if;

  if exists (
    select 1 from public.routines
    where id = current_setting('test.identity_routine_id')::uuid
  ) or exists (
    select 1 from public.workouts
    where id = current_setting('test.identity_workout_id')::uuid
  ) or exists (
    select 1 from public.workout_sets
    where owner_id = '40000000-0000-0000-0000-000000000002'
  ) then
    raise exception 'Circle identity access exposed private training data';
  end if;
end;
$$;

reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '40000000-0000-0000-0000-000000000003',
  true
);

do $$
declare
  target_circle_id uuid := current_setting('test.identity_circle_id')::uuid;
begin
  begin
    perform 1 from public.get_circle_member_identities(target_circle_id);
    raise exception 'Unrelated user obtained Circle member identities';
  exception when insufficient_privilege then null;
  end;

  if exists (
    select 1 from public.profiles
    where id = '40000000-0000-0000-0000-000000000002'
  ) then
    raise exception 'Unrelated user read a protected profile directly';
  end if;
end;
$$;

reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '40000000-0000-0000-0000-000000000002',
  true
);

do $$
declare
  target_circle_id uuid := current_setting('test.identity_circle_id')::uuid;
begin
  if (
    select display_name
    from public.get_circle_member_identities(target_circle_id)
    where user_id = '40000000-0000-0000-0000-000000000001'
  ) <> 'Asha Owner' then
    raise exception 'Co-member identity visibility was not reciprocal';
  end if;

  perform public.leave_circle(target_circle_id);

  begin
    perform 1 from public.get_circle_member_identities(target_circle_id);
    raise exception 'Former member retained Circle identity access';
  exception when insufficient_privilege then null;
  end;

  update public.profiles
  set display_name = 'Ben Updated'
  where id = auth.uid();

  if (
    select display_name from public.profiles where id = auth.uid()
  ) <> 'Ben Updated' then
    raise exception 'Former member lost access to their own permitted profile fields';
  end if;
end;
$$;

reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '40000000-0000-0000-0000-000000000001',
  true
);

do $$
declare
  target_circle_id uuid := current_setting('test.identity_circle_id')::uuid;
begin
  if exists (
    select 1
    from public.get_circle_member_identities(target_circle_id)
    where user_id = '40000000-0000-0000-0000-000000000002'
  ) then
    raise exception 'Departed member identity remained visible in the Circle';
  end if;
end;
$$;

select '1..1';
select 'ok 1 - Circle display identities remain scoped to current co-members';
rollback;

begin;

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '50000000-0000-0000-0000-000000000001',
    'invite-owner@example.test',
    '{"display_name":"Invite Owner"}'::jsonb
  ),
  (
    '50000000-0000-0000-0000-000000000002',
    'invite-member@example.test',
    '{"display_name":"Invite Member"}'::jsonb
  ),
  (
    '50000000-0000-0000-0000-000000000003',
    'invite-unrelated@example.test',
    '{"display_name":"Invite Unrelated"}'::jsonb
  ),
  (
    '50000000-0000-0000-0000-000000000004',
    'invite-revoked@example.test',
    '{"display_name":"Revoked Recipient"}'::jsonb
  ),
  (
    '50000000-0000-0000-0000-000000000005',
    'invite-expired@example.test',
    '{"display_name":"Expired Recipient"}'::jsonb
  );

set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '50000000-0000-0000-0000-000000000001',
  true
);

do $$
declare
  target_circle_id uuid := public.create_circle('Invitation test Circle');
  active_invite_id uuid;
  active_token text;
  active_expiration timestamptz;
  extra_invite_id uuid;
  extra_token text;
  revoked_invite_id uuid;
  revoked_token text;
  expired_invite_id uuid;
  expired_token text;
  routine_id uuid;
  owner_workout_id uuid;
  workout_exercise_id uuid;
  exercise_id uuid;
begin
  select created.invite_id, created.token, created.expires_at
  into active_invite_id, active_token, active_expiration
  from public.create_circle_invite(target_circle_id) as created;

  select created.invite_id, created.token
  into revoked_invite_id, revoked_token
  from public.create_circle_invite(target_circle_id) as created;

  select created.invite_id, created.token
  into extra_invite_id, extra_token
  from public.create_circle_invite(target_circle_id) as created;

  select created.invite_id, created.token
  into expired_invite_id, expired_token
  from public.create_circle_invite(target_circle_id) as created;

  if active_token !~ '^[0-9a-f]{64}$'
    or active_expiration <= now() then
    raise exception 'Owner did not receive a valid expiring bearer credential';
  end if;

  select id into exercise_id
  from public.exercises
  where name = 'Barbell squat' and owner_id is null;

  routine_id := public.save_routine(
    null,
    'Owner private routine',
    array[exercise_id]
  );
  owner_workout_id := public.start_workout(routine_id);
  select id into workout_exercise_id
  from public.workout_exercises
  where workout_exercises.workout_id = owner_workout_id;
  perform public.change_workout(
    owner_workout_id,
    'add_set',
    workout_exercise_id,
    100,
    5
  );
  perform public.change_workout(owner_workout_id, 'finish');

  perform set_config('test.invite_circle_id', target_circle_id::text, true);
  perform set_config('test.active_invite_id', active_invite_id::text, true);
  perform set_config('test.active_invite_token', active_token, true);
  perform set_config('test.revoked_invite_id', revoked_invite_id::text, true);
  perform set_config('test.revoked_invite_token', revoked_token, true);
  perform set_config('test.extra_invite_id', extra_invite_id::text, true);
  perform set_config('test.extra_invite_token', extra_token, true);
  perform set_config('test.expired_invite_id', expired_invite_id::text, true);
  perform set_config('test.expired_invite_token', expired_token, true);
  perform set_config('test.invite_routine_id', routine_id::text, true);
  perform set_config('test.invite_workout_id', owner_workout_id::text, true);
end;
$$;

reset role;

do $$
declare
  stored_invite public.circle_invites%rowtype;
begin
  select * into stored_invite
  from public.circle_invites
  where id = current_setting('test.active_invite_id')::uuid;

  if stored_invite.created_by <> '50000000-0000-0000-0000-000000000001'
    or stored_invite.circle_id <> current_setting('test.invite_circle_id')::uuid
    or stored_invite.token_hash <> sha256(
      convert_to(current_setting('test.active_invite_token'), 'UTF8')
    )
    or encode(stored_invite.token_hash, 'hex')
      = current_setting('test.active_invite_token') then
    raise exception 'Invite metadata or hashed-token storage is invalid';
  end if;
end;
$$;

set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '50000000-0000-0000-0000-000000000003',
  true
);

do $$
declare
  target_circle_id uuid := current_setting('test.invite_circle_id')::uuid;
begin
  begin
    perform 1 from public.circle_invites;
    raise exception 'Unrelated user enumerated private Circle invitations';
  exception when insufficient_privilege then null;
  end;

  begin
    perform 1 from public.create_circle_invite(target_circle_id);
    raise exception 'Non-owner created a Circle invitation';
  exception when insufficient_privilege then null;
  end;

  begin
    perform public.revoke_circle_invite(
      current_setting('test.revoked_invite_id')::uuid
    );
    raise exception 'Non-owner revoked a Circle invitation';
  exception when insufficient_privilege then null;
  end;

  begin
    perform public.accept_circle_invite(repeat('0', 64));
    raise exception 'Invalid invitation was accepted';
  exception when invalid_parameter_value then null;
  end;

  begin
    perform public.accept_circle_invite(
      current_setting('test.active_invite_id')
    );
    raise exception 'Invite record UUID was accepted as a bearer credential';
  exception when invalid_parameter_value then null;
  end;

  begin
    insert into public.circle_members (circle_id, user_id)
    values (target_circle_id, auth.uid());
    raise exception 'Circle UUID alone allowed an unrelated user to join';
  exception when insufficient_privilege then null;
  end;
end;
$$;

reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '50000000-0000-0000-0000-000000000002',
  true
);

do $$
declare
  target_circle_id uuid := current_setting('test.invite_circle_id')::uuid;
  accepted_circle_id uuid;
begin
  accepted_circle_id := public.accept_circle_invite(
    current_setting('test.active_invite_token')
  );

  if accepted_circle_id <> target_circle_id
    or not exists (
      select 1
      from public.circle_members
      where circle_id = target_circle_id and user_id = auth.uid()
    )
    or exists (
      select 1
      from public.circle_members
      where circle_id = target_circle_id
        and user_id = '50000000-0000-0000-0000-000000000003'
    ) then
    raise exception 'Acceptance did not add only the authenticated caller';
  end if;

  begin
    perform public.accept_circle_invite(
      current_setting('test.active_invite_token')
    );
    raise exception 'Consumed invitation was accepted again';
  exception when invalid_parameter_value then null;
  end;

  if (
    select count(*)
    from public.circle_members
    where circle_id = target_circle_id and user_id = auth.uid()
  ) <> 1 then
    raise exception 'Repeated acceptance created duplicate membership';
  end if;

  if public.accept_circle_invite(
    current_setting('test.extra_invite_token')
  ) <> target_circle_id or (
    select count(*)
    from public.circle_members
    where circle_id = target_circle_id and user_id = auth.uid()
  ) <> 1 then
    raise exception 'Already-member acceptance did not remain idempotent';
  end if;

  begin
    perform 1 from public.create_circle_invite(target_circle_id);
    raise exception 'Non-owner Circle member created an invitation';
  exception when insufficient_privilege then null;
  end;

  begin
    perform public.revoke_circle_invite(
      current_setting('test.revoked_invite_id')::uuid
    );
    raise exception 'Non-owner Circle member revoked an invitation';
  exception when insufficient_privilege then null;
  end;

  if (
    select display_name
    from public.get_circle_member_identities(target_circle_id)
    where user_id = '50000000-0000-0000-0000-000000000001'
  ) <> 'Invite Owner' then
    raise exception 'Joined member could not read permitted Circle identity';
  end if;

  if exists (
    select 1 from public.routines
    where id = current_setting('test.invite_routine_id')::uuid
  ) or exists (
    select 1 from public.workouts
    where id = current_setting('test.invite_workout_id')::uuid
  ) or exists (
    select 1 from public.workout_sets
    where owner_id = '50000000-0000-0000-0000-000000000001'
  ) then
    raise exception 'Invite acceptance exposed another member training data';
  end if;

  if exists (
    select 1 from public.profiles
    where id = '50000000-0000-0000-0000-000000000001'
  ) then
    raise exception 'Invite acceptance exposed another member profile row';
  end if;

  begin
    perform email from auth.users
    where id = '50000000-0000-0000-0000-000000000001';
    raise exception 'Invite acceptance exposed another member email';
  exception when insufficient_privilege then null;
  end;
end;
$$;

reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '50000000-0000-0000-0000-000000000001',
  true
);

do $$
declare
  target_circle_id uuid := current_setting('test.invite_circle_id')::uuid;
begin
  if (
    select display_name
    from public.get_circle_member_identities(target_circle_id)
    where user_id = '50000000-0000-0000-0000-000000000002'
  ) <> 'Invite Member' then
    raise exception 'Owner could not read the accepted member identity';
  end if;

  perform public.revoke_circle_invite(
    current_setting('test.revoked_invite_id')::uuid
  );
  perform public.revoke_circle_invite(
    current_setting('test.revoked_invite_id')::uuid
  );

  begin
    perform public.revoke_circle_invite(
      current_setting('test.active_invite_id')::uuid
    );
    raise exception 'Owner revoked a consumed invitation';
  exception when invalid_parameter_value then null;
  end;

  if not exists (
    select 1 from public.circle_members
    where circle_id = target_circle_id
      and user_id = '50000000-0000-0000-0000-000000000002'
  ) then
    raise exception 'Revocation attempt removed an accepted member';
  end if;
end;
$$;

reset role;
update public.circle_invites
set expires_at = now() - interval '1 minute'
where id = current_setting('test.expired_invite_id')::uuid;

set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '50000000-0000-0000-0000-000000000004',
  true
);

do $$
begin
  begin
    perform public.accept_circle_invite(
      current_setting('test.revoked_invite_token')
    );
    raise exception 'Revoked invitation was accepted';
  exception when invalid_parameter_value then null;
  end;

  if exists (
    select 1 from public.circle_members
    where user_id = auth.uid()
  ) then
    raise exception 'Revoked invitation created a membership';
  end if;
end;
$$;

reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '50000000-0000-0000-0000-000000000005',
  true
);

do $$
begin
  begin
    perform public.accept_circle_invite(
      current_setting('test.expired_invite_token')
    );
    raise exception 'Expired invitation was accepted';
  exception when invalid_parameter_value then null;
  end;

  if exists (
    select 1 from public.circle_members
    where user_id = auth.uid()
  ) then
    raise exception 'Expired invitation created a membership';
  end if;
end;
$$;

reset role;

do $$
begin
  if not exists (
    select 1 from public.circle_invites
    where id = current_setting('test.active_invite_id')::uuid
      and accepted_by = '50000000-0000-0000-0000-000000000002'
      and accepted_at is not null
      and revoked_at is null
  ) then
    raise exception 'Consumed invite did not record the authenticated accepter';
  end if;

  if not exists (
    select 1 from public.circle_invites
    where id = current_setting('test.revoked_invite_id')::uuid
      and revoked_at is not null
      and accepted_at is null
  ) then
    raise exception 'Owner revocation did not preserve unused state';
  end if;

  if not exists (
    select 1 from public.circle_invites
    where id = current_setting('test.extra_invite_id')::uuid
      and accepted_by = '50000000-0000-0000-0000-000000000002'
      and accepted_at is not null
  ) then
    raise exception 'Already-member acceptance did not consume its invitation';
  end if;
end;
$$;

select '1..1';
select 'ok 1 - private Circle invitation lifecycle and isolation';
rollback;

begin;

insert into auth.users (id, email)
values
  ('60000000-0000-0000-0000-000000000001', 'view-owner@example.test'),
  ('60000000-0000-0000-0000-000000000002', 'view-member@example.test'),
  ('60000000-0000-0000-0000-000000000003', 'view-other@example.test');

set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '60000000-0000-0000-0000-000000000001',
  true
);

do $$
declare
  target_circle_id uuid := public.create_circle('Preview-safe Circle');
  active_invite record;
  revoked_invite record;
  expired_invite record;
begin
  select * into active_invite
  from public.create_circle_invite(target_circle_id);
  select * into revoked_invite
  from public.create_circle_invite(target_circle_id);
  select * into expired_invite
  from public.create_circle_invite(target_circle_id);

  perform set_config('test.view_circle_id', target_circle_id::text, true);
  perform set_config('test.view_active_id', active_invite.invite_id::text, true);
  perform set_config('test.view_active_token', active_invite.token, true);
  perform set_config('test.view_revoked_token', revoked_invite.token, true);
  perform set_config('test.view_expired_id', expired_invite.invite_id::text, true);
  perform set_config('test.view_expired_token', expired_invite.token, true);

  perform public.revoke_circle_invite(revoked_invite.invite_id);

  if (
    select count(*) from public.get_circle_active_invites(target_circle_id)
  ) <> 2 or not exists (
    select 1 from public.get_circle_active_invites(target_circle_id)
    where invite_id = active_invite.invite_id
  ) then
    raise exception 'Owner could not list only unused active invite IDs';
  end if;
end;
$$;

reset role;
update public.circle_invites
set expires_at = clock_timestamp() - interval '1 minute'
where id = current_setting('test.view_expired_id')::uuid;

set role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$
begin
  if not exists (
    select 1 from public.get_circle_invite_preview(
      current_setting('test.view_active_token')
    )
    where status = 'active'
      and circle_name = 'Preview-safe Circle'
      and circle_id = current_setting('test.view_circle_id')::uuid
      and already_member = false
  ) then
    raise exception 'Valid bearer holder could not preview Circle name';
  end if;

  if not exists (
    select 1 from public.get_circle_invite_preview(repeat('0', 64))
    where status = 'invalid' and circle_name is null and circle_id is null
  ) or not exists (
    select 1 from public.get_circle_invite_preview('bad-token')
    where status = 'invalid' and circle_name is null and circle_id is null
  ) then
    raise exception 'Invalid bearer preview disclosed Circle context';
  end if;

  if not exists (
    select 1 from public.get_circle_invite_preview(
      current_setting('test.view_revoked_token')
    )
    where status = 'revoked' and circle_name is null and circle_id is null
  ) or not exists (
    select 1 from public.get_circle_invite_preview(
      current_setting('test.view_expired_token')
    )
    where status = 'expired' and circle_name is null and circle_id is null
  ) then
    raise exception 'Inactive bearer preview disclosed Circle context';
  end if;

  begin
    perform 1 from public.get_circle_active_invites(
      current_setting('test.view_circle_id')::uuid
    );
    raise exception 'Anonymous caller listed owner invitations';
  exception when insufficient_privilege then null;
  end;
end;
$$;

reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '60000000-0000-0000-0000-000000000003',
  true
);

do $$
begin
  begin
    perform 1 from public.get_circle_active_invites(
      current_setting('test.view_circle_id')::uuid
    );
    raise exception 'Unrelated user listed owner invitations';
  exception when insufficient_privilege then null;
  end;
end;
$$;

reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '60000000-0000-0000-0000-000000000002',
  true
);

do $$
begin
  begin
    perform 1 from public.get_circle_active_invites(
      current_setting('test.view_circle_id')::uuid
    );
    raise exception 'Non-owner member listed invitations';
  exception when insufficient_privilege then null;
  end;

  if public.accept_circle_invite(
    current_setting('test.view_active_token')
  ) <> current_setting('test.view_circle_id')::uuid then
    raise exception 'Active preview did not lead to correct Circle';
  end if;

  if not exists (
    select 1 from public.get_circle_invite_preview(
      current_setting('test.view_active_token')
    )
    where status = 'consumed'
      and already_member = true
      and circle_name = 'Preview-safe Circle'
      and circle_id = current_setting('test.view_circle_id')::uuid
  ) then
    raise exception 'Joined member could not recover their Circle destination';
  end if;
end;
$$;

reset role;
set role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$
begin
  if not exists (
    select 1 from public.get_circle_invite_preview(
      current_setting('test.view_active_token')
    )
    where status = 'consumed'
      and already_member = false
      and circle_name is null
      and circle_id is null
  ) then
    raise exception 'Consumed bearer exposed Circle context to non-member';
  end if;
end;
$$;

reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '60000000-0000-0000-0000-000000000001',
  true
);

do $$
begin
  if exists (
    select 1 from public.get_circle_active_invites(
      current_setting('test.view_circle_id')::uuid
    )
  ) then
    raise exception 'Consumed, revoked, or expired invite stayed active';
  end if;
end;
$$;

select '1..1';
select 'ok 1 - invite previews and owner listing reveal only permitted context';
rollback;

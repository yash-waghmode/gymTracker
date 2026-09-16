-- One-time, hashed bearer invitations for private Gym Circles.
create table public.circle_invites (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.gym_circles (id) on delete cascade,
  created_by uuid not null references public.profiles (id) on delete restrict,
  token_hash bytea not null unique check (octet_length(token_hash) = 32),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  accepted_by uuid references public.profiles (id) on delete restrict,
  revoked_at timestamptz,
  constraint circle_invites_acceptance_state_check check (
    (accepted_at is null) = (accepted_by is null)
  ),
  constraint circle_invites_single_terminal_state_check check (
    accepted_at is null or revoked_at is null
  )
);

create index circle_invites_circle_id_idx
  on public.circle_invites (circle_id);

comment on table public.circle_invites is
  'One-time Circle invitations. Only a SHA-256 bearer-token digest is stored.';

alter table public.circle_invites enable row level security;

revoke all on table public.circle_invites from anon, authenticated;
grant all on table public.circle_invites to service_role;

create function public.create_circle_invite(p_circle_id uuid)
returns table (
  invite_id uuid,
  token text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  new_invite_id uuid := gen_random_uuid();
  bearer_token text := replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '');
  invite_expiration timestamptz := now() + interval '7 days';
begin
  if caller_id is null then
    raise insufficient_privilege using message = 'Authentication required.';
  end if;

  if not exists (
    select 1
    from public.gym_circles
    where id = p_circle_id and owner_id = caller_id
  ) then
    raise insufficient_privilege using message = 'Circle not found.';
  end if;

  insert into public.circle_invites (
    id,
    circle_id,
    created_by,
    token_hash,
    expires_at
  )
  values (
    new_invite_id,
    p_circle_id,
    caller_id,
    sha256(convert_to(bearer_token, 'UTF8')),
    invite_expiration
  );

  return query
  select new_invite_id, bearer_token, invite_expiration;
end;
$$;

create function public.accept_circle_invite(p_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  matched_invite public.circle_invites%rowtype;
begin
  if caller_id is null then
    raise insufficient_privilege using message = 'Authentication required.';
  end if;

  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then
    raise invalid_parameter_value using
      message = 'Invitation is invalid or no longer active.';
  end if;

  select invites.*
  into matched_invite
  from public.circle_invites as invites
  where invites.token_hash = sha256(convert_to(p_token, 'UTF8'))
  for update;

  if not found
    or matched_invite.revoked_at is not null
    or matched_invite.accepted_at is not null
    or matched_invite.expires_at <= clock_timestamp() then
    raise invalid_parameter_value using
      message = 'Invitation is invalid or no longer active.';
  end if;

  insert into public.circle_members (circle_id, user_id)
  values (matched_invite.circle_id, caller_id)
  on conflict (circle_id, user_id) do nothing;

  update public.circle_invites
  set accepted_at = now(), accepted_by = caller_id
  where id = matched_invite.id;

  return matched_invite.circle_id;
end;
$$;

create function public.revoke_circle_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  matched_invite public.circle_invites%rowtype;
begin
  if caller_id is null then
    raise insufficient_privilege using message = 'Authentication required.';
  end if;

  select invites.*
  into matched_invite
  from public.circle_invites as invites
  join public.gym_circles as circles on circles.id = invites.circle_id
  where invites.id = p_invite_id and circles.owner_id = caller_id
  for update of invites;

  if not found then
    raise insufficient_privilege using message = 'Invitation not found.';
  end if;

  if matched_invite.accepted_at is not null then
    raise invalid_parameter_value using
      message = 'Accepted invitations cannot be revoked.';
  end if;

  if matched_invite.revoked_at is null then
    update public.circle_invites
    set revoked_at = now()
    where id = matched_invite.id;
  end if;
end;
$$;

revoke all on function public.create_circle_invite(uuid) from public, anon;
revoke all on function public.accept_circle_invite(text) from public, anon;
revoke all on function public.revoke_circle_invite(uuid) from public, anon;
grant execute on function public.create_circle_invite(uuid) to authenticated;
grant execute on function public.accept_circle_invite(text) to authenticated;
grant execute on function public.revoke_circle_invite(uuid) to authenticated;

-- Minimal invite views for the owner and the holder of a bearer credential.
create function public.get_circle_active_invites(p_circle_id uuid)
returns table (
  invite_id uuid,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'Authentication required.';
  end if;

  if not exists (
    select 1
    from public.gym_circles
    where id = p_circle_id and owner_id = (select auth.uid())
  ) then
    raise insufficient_privilege using message = 'Circle not found.';
  end if;

  return query
  select invites.id, invites.expires_at
  from public.circle_invites as invites
  where invites.circle_id = p_circle_id
    and invites.accepted_at is null
    and invites.revoked_at is null
    and invites.expires_at > clock_timestamp()
  order by invites.created_at desc, invites.id;
end;
$$;

create function public.get_circle_invite_preview(p_token text)
returns table (
  status text,
  circle_id uuid,
  circle_name text,
  already_member boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  found_circle_id uuid;
  found_circle_name text;
  invite_revoked_at timestamptz;
  invite_accepted_at timestamptz;
  invite_expires_at timestamptz;
  member_now boolean := false;
  invite_status text;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then
    return query select 'invalid'::text, null::uuid, null::text, false;
    return;
  end if;

  select
    invites.circle_id,
    circles.name,
    invites.revoked_at,
    invites.accepted_at,
    invites.expires_at
  into
    found_circle_id,
    found_circle_name,
    invite_revoked_at,
    invite_accepted_at,
    invite_expires_at
  from public.circle_invites as invites
  join public.gym_circles as circles on circles.id = invites.circle_id
  where invites.token_hash = sha256(convert_to(p_token, 'UTF8'));

  if not found then
    return query select 'invalid'::text, null::uuid, null::text, false;
    return;
  end if;

  if (select auth.uid()) is not null then
    select exists (
      select 1
      from public.circle_members as members
      where members.circle_id = found_circle_id
        and members.user_id = (select auth.uid())
    ) into member_now;
  end if;

  invite_status := case
    when invite_revoked_at is not null then 'revoked'
    when invite_accepted_at is not null then 'consumed'
    when invite_expires_at <= clock_timestamp() then 'expired'
    else 'active'
  end;

  return query
  select
    invite_status,
    case when invite_status = 'active' or member_now
      then found_circle_id else null::uuid end,
    case when invite_status = 'active' or member_now
      then found_circle_name else null::text end,
    member_now;
end;
$$;

comment on function public.get_circle_active_invites(uuid) is
  'Returns only active invite IDs and expiration times to the Circle owner.';
comment on function public.get_circle_invite_preview(text) is
  'Returns safe Circle context only to a valid token holder or current member.';

revoke all on function public.get_circle_active_invites(uuid)
  from public, anon;
revoke all on function public.get_circle_invite_preview(text)
  from public;
grant execute on function public.get_circle_active_invites(uuid)
  to authenticated;
grant execute on function public.get_circle_invite_preview(text)
  to anon, authenticated;

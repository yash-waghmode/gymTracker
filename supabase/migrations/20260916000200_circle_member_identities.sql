-- Expose only the safe identity surface needed by current co-members.
create function public.get_circle_member_identities(p_circle_id uuid)
returns table (
  user_id uuid,
  display_name text
)
language plpgsql
security definer
set search_path = ''
stable
as $$
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'Authentication required.';
  end if;

  if not private.is_circle_member(p_circle_id) then
    raise insufficient_privilege using message = 'Circle not found.';
  end if;

  return query
  select members.user_id, profiles.display_name
  from public.circle_members as members
  join public.profiles as profiles on profiles.id = members.user_id
  where members.circle_id = p_circle_id
  order by members.joined_at, members.user_id;
end;
$$;

comment on function public.get_circle_member_identities(uuid) is
  'Returns only user IDs and display names to authenticated current co-members.';

revoke all on function public.get_circle_member_identities(uuid)
  from public, anon;
grant execute on function public.get_circle_member_identities(uuid)
  to authenticated;

-- Private Circle membership. Circle lifecycle functions derive identity from auth.uid().
create table public.gym_circles (
  id uuid primary key default gen_random_uuid(),
  name text not null check (
    name = btrim(name)
    and char_length(name) between 1 and 120
  ),
  owner_id uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now()
);

create index gym_circles_owner_id_idx on public.gym_circles (owner_id);

create table public.circle_members (
  circle_id uuid not null references public.gym_circles (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete restrict,
  joined_at timestamptz not null default now(),
  primary key (circle_id, user_id)
);

create index circle_members_user_id_idx on public.circle_members (user_id);

comment on table public.gym_circles is
  'Private training groups. The owner must delete the Circle rather than leave it.';
comment on table public.circle_members is
  'Circle context only; membership does not grant access to personal workout data.';

create function private.is_circle_member(target_circle_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.circle_members
    where circle_id = target_circle_id
      and user_id = (select auth.uid())
  );
$$;

revoke all on function private.is_circle_member(uuid) from public;
grant execute on function private.is_circle_member(uuid) to authenticated;

alter table public.gym_circles enable row level security;
alter table public.circle_members enable row level security;

revoke all on table public.gym_circles from anon, authenticated;
revoke all on table public.circle_members from anon, authenticated;
grant all on table public.gym_circles to service_role;
grant all on table public.circle_members to service_role;
grant select on table public.gym_circles to authenticated;
grant select on table public.circle_members to authenticated;

create policy "members read their circles"
on public.gym_circles for select to authenticated
using (private.is_circle_member(id));

create policy "members read circle membership"
on public.circle_members for select to authenticated
using (private.is_circle_member(circle_id));

create function public.create_circle(p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  circle_id uuid;
  normalized_name text := btrim(p_name);
begin
  if caller_id is null then
    raise insufficient_privilege using message = 'Authentication required.';
  end if;

  if normalized_name is null
    or char_length(normalized_name) not between 1 and 120 then
    raise invalid_parameter_value using
      message = 'Circle name must be between 1 and 120 characters.';
  end if;

  insert into public.gym_circles (name, owner_id)
  values (normalized_name, caller_id)
  returning id into circle_id;

  insert into public.circle_members (circle_id, user_id)
  values (circle_id, caller_id);

  return circle_id;
end;
$$;

create function public.leave_circle(p_circle_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  circle_owner_id uuid;
  deleted_rows integer;
begin
  if caller_id is null then
    raise insufficient_privilege using message = 'Authentication required.';
  end if;

  select owner_id
  into circle_owner_id
  from public.gym_circles
  where id = p_circle_id
  for update;

  if not found then
    raise insufficient_privilege using message = 'Circle not found.';
  end if;

  if circle_owner_id = caller_id then
    raise invalid_parameter_value using
      message = 'Circle owners must delete their Circle.';
  end if;

  delete from public.circle_members
  where circle_id = p_circle_id and user_id = caller_id;
  get diagnostics deleted_rows = row_count;

  if deleted_rows <> 1 then
    raise insufficient_privilege using message = 'Circle not found.';
  end if;
end;
$$;

create function public.delete_circle(p_circle_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  deleted_rows integer;
begin
  if caller_id is null then
    raise insufficient_privilege using message = 'Authentication required.';
  end if;

  delete from public.gym_circles
  where id = p_circle_id and owner_id = caller_id;
  get diagnostics deleted_rows = row_count;

  if deleted_rows <> 1 then
    raise insufficient_privilege using message = 'Circle not found.';
  end if;
end;
$$;

revoke all on function public.create_circle(text) from public, anon;
revoke all on function public.leave_circle(uuid) from public, anon;
revoke all on function public.delete_circle(uuid) from public, anon;
grant execute on function public.create_circle(text) to authenticated;
grant execute on function public.leave_circle(uuid) to authenticated;
grant execute on function public.delete_circle(uuid) to authenticated;

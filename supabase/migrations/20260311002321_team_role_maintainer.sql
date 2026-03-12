-- Rename cleaner role to maintainer and keep manager invites allowed.

update public.property_members
set role = 'maintainer'
where role = 'cleaner';

create or replace function public.can_invite_property_member(
  p_property_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
  v_owner_tier text := 'free';
  v_caller_role text;
  v_member_count int := 0;
begin
  select owner_id
    into v_owner_id
  from public.properties
  where id = p_property_id;

  if v_owner_id is null then
    return false;
  end if;

  select role
    into v_caller_role
  from public.property_members
  where property_id = p_property_id
    and user_id = p_user_id
  limit 1;

  if p_user_id <> v_owner_id and coalesce(v_caller_role, '') not in ('owner', 'manager') then
    return false;
  end if;

  select coalesce(subscription_tier, 'free')
    into v_owner_tier
  from public.profiles
  where id = v_owner_id;

  select count(*)
    into v_member_count
  from public.property_members
  where property_id = p_property_id
    and role <> 'owner';

  if v_owner_tier in ('enterprise', 'lifetime') then
    return true;
  end if;

  if v_owner_tier = 'pro' then
    return v_member_count < 5;
  end if;

  return false;
end;
$$;

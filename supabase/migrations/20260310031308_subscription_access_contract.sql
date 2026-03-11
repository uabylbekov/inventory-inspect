-- Subscription/access contract and server-side limit checks.
-- Deploy to Supabase `test` branch first, then promote to `main`.

create or replace function public.get_accessible_properties_with_owner_tier(
  p_user_id uuid default auth.uid()
)
returns table (
  property_id uuid,
  owner_id uuid,
  owner_tier text,
  owner_full_name text,
  owner_email text,
  owner_company_logo_url text,
  membership_role text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id as property_id,
    p.owner_id,
    coalesce(pr.subscription_tier, 'free') as owner_tier,
    pr.full_name as owner_full_name,
    pr.email as owner_email,
    pr.company_logo_url as owner_company_logo_url,
    pm.role as membership_role
  from public.properties p
  join public.property_members pm
    on pm.property_id = p.id
   and pm.user_id = p_user_id
  left join public.profiles pr
    on pr.id = p.owner_id;
$$;

create or replace function public.can_user_create_property(
  p_user_id uuid default auth.uid()
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tier text := 'free';
  v_owned_count int := 0;
begin
  select coalesce(subscription_tier, 'free')
    into v_tier
  from public.profiles
  where id = p_user_id;

  select count(*)
    into v_owned_count
  from public.properties
  where owner_id = p_user_id;

  if v_tier in ('enterprise', 'lifetime') then
    return true;
  end if;

  if v_tier = 'pro' then
    return v_owned_count < 10;
  end if;

  return v_owned_count < 1;
end;
$$;

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

  -- Owners and managers can invite.
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

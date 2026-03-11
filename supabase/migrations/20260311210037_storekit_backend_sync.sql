-- Align StoreKit-backed access with backend enforcement and harden billing fields.

alter table public.profiles
add column if not exists app_store_original_transaction_id text,
add column if not exists app_store_product_id text,
add column if not exists app_store_subscription_active boolean not null default false,
add column if not exists app_store_subscription_expires_at timestamptz,
add column if not exists app_store_environment text,
add column if not exists app_store_last_synced_at timestamptz;

create or replace function public.get_effective_subscription_tier(
  p_user_id uuid default auth.uid()
)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_subscription_tier text := 'free';
  v_app_store_subscription_active boolean := false;
  v_app_store_subscription_expires_at timestamptz;
begin
  select
    coalesce(subscription_tier, 'free'),
    coalesce(app_store_subscription_active, false),
    app_store_subscription_expires_at
    into v_subscription_tier, v_app_store_subscription_active, v_app_store_subscription_expires_at
  from public.profiles
  where id = p_user_id;

  if v_subscription_tier in ('business', 'lifetime') then
    return v_subscription_tier;
  end if;

  if v_subscription_tier = 'pro' then
    return 'pro';
  end if;

  if v_app_store_subscription_active
     and (
       v_app_store_subscription_expires_at is null
       or v_app_store_subscription_expires_at > now()
     ) then
    return 'pro';
  end if;

  return 'free';
end;
$$;

create or replace function public.get_effective_photo_limit(
  p_owner_id uuid
)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_effective_tier text := 'free';
  v_photo_limit_override integer;
begin
  select
    public.get_effective_subscription_tier(p_owner_id),
    photo_limit_override
    into v_effective_tier, v_photo_limit_override
  from public.profiles
  where id = p_owner_id;

  if v_effective_tier in ('business', 'lifetime') then
    return coalesce(v_photo_limit_override, 50000);
  end if;

  if v_effective_tier = 'pro' then
    return coalesce(v_photo_limit_override, 10000);
  end if;

  return coalesce(v_photo_limit_override, 150);
end;
$$;

drop function if exists public.get_accessible_properties_with_owner_tier(uuid);

create function public.get_accessible_properties_with_owner_tier(
  p_user_id uuid default auth.uid()
)
returns table (
  property_id uuid,
  owner_id uuid,
  owner_tier text,
  owner_full_name text,
  owner_email text,
  owner_company_logo_url text,
  owner_property_limit_override integer,
  owner_team_limit_override integer,
  owner_photo_limit_override integer,
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
    public.get_effective_subscription_tier(p.owner_id) as owner_tier,
    pr.full_name as owner_full_name,
    pr.email as owner_email,
    pr.company_logo_url as owner_company_logo_url,
    pr.property_limit_override as owner_property_limit_override,
    pr.team_limit_override as owner_team_limit_override,
    pr.photo_limit_override as owner_photo_limit_override,
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
  v_property_limit_override int;
begin
  select
    public.get_effective_subscription_tier(p_user_id),
    property_limit_override
    into v_tier, v_property_limit_override
  from public.profiles
  where id = p_user_id;

  select count(*)
    into v_owned_count
  from public.properties
  where owner_id = p_user_id;

  if v_tier in ('business', 'lifetime') then
    return v_owned_count < coalesce(v_property_limit_override, 50);
  end if;

  if v_tier = 'pro' then
    return v_owned_count < coalesce(v_property_limit_override, 10);
  end if;

  return v_owned_count < coalesce(v_property_limit_override, 1);
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
  v_team_limit_override int;
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

  select
    public.get_effective_subscription_tier(v_owner_id),
    team_limit_override
    into v_owner_tier, v_team_limit_override
  from public.profiles
  where id = v_owner_id;

  select count(*)
    into v_member_count
  from public.property_members
  where property_id = p_property_id
    and role <> 'owner';

  if v_owner_tier in ('business', 'lifetime') then
    return v_member_count < coalesce(v_team_limit_override, 20);
  end if;

  if v_owner_tier = 'pro' then
    return v_member_count < coalesce(v_team_limit_override, 3);
  end if;

  return false;
end;
$$;

create or replace function public.enforce_inspection_item_photo_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
  v_limit integer;
  v_usage integer;
  v_old_had_photo boolean := tg_op = 'UPDATE'
    and old.image_url is not null
    and old.image_url <> '';
  v_new_has_photo boolean := new.image_url is not null
    and new.image_url <> '';
begin
  if not v_new_has_photo or v_old_had_photo then
    return new;
  end if;

  select p.owner_id
    into v_owner_id
  from public.inspections i
  join public.properties p
    on p.id = i.property_id
  where i.id = new.inspection_id;

  if v_owner_id is null then
    return new;
  end if;

  v_limit := public.get_effective_photo_limit(v_owner_id);

  select count(*)::integer
    into v_usage
  from public.inspection_items ii
  join public.inspections i
    on i.id = ii.inspection_id
  join public.properties p
    on p.id = i.property_id
  where p.owner_id = v_owner_id
    and ii.image_url is not null
    and ii.image_url <> ''
    and (tg_op <> 'UPDATE' or ii.id <> old.id);

  if v_usage >= v_limit then
    raise exception using
      errcode = 'P0001',
      message = format(
        'Photo limit reached (%s/%s). Upgrade your plan to save more evidence.',
        v_usage,
        v_limit
      );
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_inspection_item_photo_limit on public.inspection_items;

create trigger enforce_inspection_item_photo_limit
before insert or update of image_url
on public.inspection_items
for each row
execute function public.enforce_inspection_item_photo_limit();

drop policy if exists "Users can insert their own properties" on public.properties;

create policy "Users can insert their own properties"
on public.properties
for insert
to authenticated
with check (
  owner_id = (select auth.uid())
  and public.can_user_create_property((select auth.uid()))
);

revoke update on public.profiles from authenticated;
grant update (company_logo_url, business_details) on public.profiles to authenticated;

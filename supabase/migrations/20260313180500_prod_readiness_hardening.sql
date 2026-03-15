-- Production-readiness hardening for team limits and active inspections.

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
  v_pending_count int := 0;
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

  select count(*)
    into v_pending_count
  from public.pending_invitations
  where property_id = p_property_id
    and coalesce(status, 'pending') = 'pending';

  if v_owner_tier in ('business', 'lifetime') then
    return (v_member_count + v_pending_count) < coalesce(v_team_limit_override, 20);
  end if;

  if v_owner_tier = 'pro' then
    return (v_member_count + v_pending_count) < coalesce(v_team_limit_override, 3);
  end if;

  return false;
end;
$$;

create or replace function public.invite_user_to_property(
  p_email text,
  p_property_id uuid,
  p_role text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid;
    v_member_id uuid;
    v_owner_id uuid;
    v_caller_role text;
    v_role text := lower(trim(p_role));
    v_existing_pending_id uuid;
begin
    p_email := lower(trim(p_email));

    if v_role = 'cleaner' then
      v_role := 'maintainer';
    end if;

    if v_role not in ('manager', 'maintainer') then
      raise exception 'Invalid role';
    end if;

    select owner_id into v_owner_id
    from public.properties
    where id = p_property_id;

    if v_owner_id is null then
      raise exception 'Property not found';
    end if;

    select role into v_caller_role
    from public.property_members
    where property_id = p_property_id and user_id = auth.uid()
    limit 1;

    if auth.uid() <> v_owner_id and coalesce(v_caller_role, '') not in ('owner', 'manager') then
      raise exception 'Not allowed to invite members to this property';
    end if;

    select id into v_existing_pending_id
    from public.pending_invitations
    where property_id = p_property_id
      and email = p_email
      and coalesce(status, 'pending') = 'pending'
    limit 1;

    if not public.can_invite_property_member(p_property_id, auth.uid()) and v_existing_pending_id is null then
      raise exception 'Team member limit reached for this property''s plan';
    end if;

    select id into v_user_id
    from auth.users
    where email = p_email;

    if v_user_id is not null then
        if exists (
            select 1 from public.property_members
            where property_id = p_property_id and user_id = v_user_id
        ) then
            raise exception 'User is already a member of this property';
        end if;

        insert into public.property_members (property_id, user_id, role)
        values (p_property_id, v_user_id, v_role)
        returning id into v_member_id;

        delete from public.pending_invitations
        where property_id = p_property_id
          and email = p_email;

        return jsonb_build_object('success', true, 'status', 'joined', 'member_id', v_member_id);
    else
        insert into public.pending_invitations (property_id, email, role, invited_by, status)
        values (p_property_id, p_email, v_role, auth.uid(), 'pending')
        on conflict (property_id, email) do update
        set role = excluded.role,
            invited_by = excluded.invited_by,
            status = 'pending',
            created_at = now();

        return jsonb_build_object('success', true, 'status', 'pending_created');
    end if;
end;
$$;

create or replace function public.on_auth_user_created_accept_invites()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  pending_invite record;
  v_owner_id uuid;
  v_owner_tier text := 'free';
  v_member_count int := 0;
  v_team_limit_override int;
  v_limit int := 0;
begin
  for pending_invite in
    select id, property_id, role
    from public.pending_invitations
    where email = lower(new.email)
      and coalesce(status, 'pending') = 'pending'
    order by created_at asc, id asc
  loop
    select owner_id
      into v_owner_id
    from public.properties
    where id = pending_invite.property_id;

    if v_owner_id is null then
      update public.pending_invitations
      set status = 'property_missing'
      where id = pending_invite.id;
      continue;
    end if;

    select
      public.get_effective_subscription_tier(v_owner_id),
      team_limit_override
      into v_owner_tier, v_team_limit_override
    from public.profiles
    where id = v_owner_id;

    if v_owner_tier in ('business', 'lifetime') then
      v_limit := coalesce(v_team_limit_override, 20);
    elsif v_owner_tier = 'pro' then
      v_limit := coalesce(v_team_limit_override, 3);
    else
      v_limit := 0;
    end if;

    select count(*)
      into v_member_count
    from public.property_members
    where property_id = pending_invite.property_id
      and role <> 'owner';

    if v_member_count >= v_limit then
      update public.pending_invitations
      set status = 'blocked_limit'
      where id = pending_invite.id;
      continue;
    end if;

    insert into public.property_members (property_id, user_id, role)
    values (pending_invite.property_id, new.id, pending_invite.role)
    on conflict (property_id, user_id) do nothing;

    delete from public.pending_invitations
    where id = pending_invite.id;
  end loop;

  return new;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'inspections'
      and indexname in (
        'inspections_one_in_progress_per_property_idx',
        'unq_active_inspection_per_property'
      )
  ) then
    execute '
      create unique index inspections_one_in_progress_per_property_idx
      on public.inspections (property_id)
      where status = ''in_progress''
    ';
  end if;
end
$$;

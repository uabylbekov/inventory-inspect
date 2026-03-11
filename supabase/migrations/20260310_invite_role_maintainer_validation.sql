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

    if not public.can_invite_property_member(p_property_id, auth.uid()) then
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

        return jsonb_build_object('success', true, 'status', 'joined', 'member_id', v_member_id);
    else
        insert into public.pending_invitations (property_id, email, role, invited_by)
        values (p_property_id, p_email, v_role, auth.uid())
        on conflict (property_id, email) do update
        set role = excluded.role, created_at = now();

        return jsonb_build_object('success', true, 'status', 'pending_created');
    end if;
end;
$$;

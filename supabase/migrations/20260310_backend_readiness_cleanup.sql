create index if not exists inspection_items_inventory_item_id_idx
on public.inspection_items (inventory_item_id);

create index if not exists inspection_items_room_id_idx
on public.inspection_items (room_id);

create index if not exists inspections_inspector_id_idx
on public.inspections (inspector_id);

create index if not exists notifications_user_id_idx
on public.notifications (user_id);

create index if not exists pending_invitations_invited_by_idx
on public.pending_invitations (invited_by);

create index if not exists property_members_user_id_idx
on public.property_members (user_id);

do $$
begin
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'add_property_owner_member'
      and pg_get_function_identity_arguments(p.oid) = ''
  ) then
    execute 'alter function public.add_property_owner_member() set search_path = public';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'extract_storage_path'
      and pg_get_function_identity_arguments(p.oid) = 'url text'
  ) then
    execute 'alter function public.extract_storage_path(text) set search_path = public';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'get_property_team_members'
      and pg_get_function_identity_arguments(p.oid) = 'p_property_id uuid'
  ) then
    execute 'alter function public.get_property_team_members(uuid) set search_path = public';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'get_user_inherited_tiers'
      and pg_get_function_identity_arguments(p.oid) = 'p_user_id uuid'
  ) then
    execute 'alter function public.get_user_inherited_tiers(uuid) set search_path = public';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'get_user_role'
      and pg_get_function_identity_arguments(p.oid) = 'pid uuid'
  ) then
    execute 'alter function public.get_user_role(uuid) set search_path = public';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'handle_new_user'
      and pg_get_function_identity_arguments(p.oid) = ''
  ) then
    execute 'alter function public.handle_new_user() set search_path = public';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'mark_all_notifications_read'
      and pg_get_function_identity_arguments(p.oid) = ''
  ) then
    execute 'alter function public.mark_all_notifications_read() set search_path = public';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'on_auth_user_created_accept_invites'
      and pg_get_function_identity_arguments(p.oid) = ''
  ) then
    execute 'alter function public.on_auth_user_created_accept_invites() set search_path = public';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'on_inspection_complete_notify'
      and pg_get_function_identity_arguments(p.oid) = ''
  ) then
    execute 'alter function public.on_inspection_complete_notify() set search_path = public';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'on_inspection_item_delete_cleanup_storage'
      and pg_get_function_identity_arguments(p.oid) = ''
  ) then
    execute 'alter function public.on_inspection_item_delete_cleanup_storage() set search_path = public';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'on_inspection_item_update_cleanup_storage'
      and pg_get_function_identity_arguments(p.oid) = ''
  ) then
    execute 'alter function public.on_inspection_item_update_cleanup_storage() set search_path = public';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'on_property_member_invite_notify'
      and pg_get_function_identity_arguments(p.oid) = ''
  ) then
    execute 'alter function public.on_property_member_invite_notify() set search_path = public';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'storage_delete_object'
      and pg_get_function_identity_arguments(p.oid) = 'bucket_id text, object_path text'
  ) then
    execute 'alter function public.storage_delete_object(text, text) set search_path = public';
  end if;
end
$$;

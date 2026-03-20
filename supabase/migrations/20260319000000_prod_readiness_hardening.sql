-- Production readiness hardening: constraints, indexes, and data integrity.

-- 1. notifications.user_id must never be null — a notification without an owner
--    would bypass RLS policies and leak data. Clean up any orphaned rows first.
delete from public.notifications where user_id is null;
alter table public.notifications alter column user_id set not null;

-- 2. Constrain pending_invitations.status to known values.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'pending_invitations_status_check'
      and conrelid = 'public.pending_invitations'::regclass
  ) then
    alter table public.pending_invitations
      add constraint pending_invitations_status_check
      check (status = any(array['pending', 'property_missing', 'blocked_limit', 'joined']));
  end if;
end
$$;

-- 3. Composite index on property_members(property_id, user_id).
--    RLS policies do (property_id, user_id) lookups on every request — a single-column
--    index on user_id exists but a composite index covers these checks directly.
create index if not exists property_members_property_user_idx
  on public.property_members (property_id, user_id);

-- 4. Composite index on notifications(user_id, is_read).
--    Used for unread badge count queries — avoids a full table scan per push notification.
create index if not exists notifications_user_read_idx
  on public.notifications (user_id, is_read);

-- 5. Composite index on inspections(property_id, status).
--    Supports the one-in-progress-per-property unique constraint check and RLS joins.
create index if not exists inspections_property_status_idx
  on public.inspections (property_id, status);

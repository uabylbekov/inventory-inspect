drop policy if exists "System can insert notifications" on public.notifications;
drop policy if exists "Users can view their own notifications" on public.notifications;
drop policy if exists "Users can update their own notifications" on public.notifications;
drop policy if exists "Users can delete their own notifications" on public.notifications;

create policy "Users can view their own notifications"
on public.notifications
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can update their own notifications"
on public.notifications
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users can delete their own notifications"
on public.notifications
for delete
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Owners can manage their properties" on public.properties;
drop policy if exists "Users can insert their own properties" on public.properties;
drop policy if exists "Users can view properties" on public.properties;
drop policy if exists "Managers and Owners can update properties" on public.properties;
drop policy if exists "Only owners can delete properties" on public.properties;

create policy "Users can view properties"
on public.properties
for select
to authenticated
using (get_user_role(id) is not null);

create policy "Users can insert their own properties"
on public.properties
for insert
to authenticated
with check (owner_id = (select auth.uid()));

create policy "Managers and owners can update properties"
on public.properties
for update
to authenticated
using (get_user_role(id) = any (array['owner'::text, 'manager'::text]))
with check (get_user_role(id) = any (array['owner'::text, 'manager'::text]));

create policy "Only owners can delete properties"
on public.properties
for delete
to authenticated
using (get_user_role(id) = 'owner'::text);

drop policy if exists "Owners can add members" on public.property_members;
drop policy if exists "Owners can update members" on public.property_members;
drop policy if exists "Owners can remove members" on public.property_members;
drop policy if exists "Users can remove themselves" on public.property_members;
drop policy if exists "Users can view team members" on public.property_members;

create policy "Users can view team members"
on public.property_members
for select
to authenticated
using (get_user_role(property_id) is not null);

create policy "Owners can add members"
on public.property_members
for insert
to authenticated
with check (get_user_role(property_id) = 'owner'::text);

create policy "Owners can update members"
on public.property_members
for update
to authenticated
using (get_user_role(property_id) = 'owner'::text)
with check (get_user_role(property_id) = 'owner'::text);

create policy "Owners can remove members or users can leave"
on public.property_members
for delete
to authenticated
using (
  get_user_role(property_id) = 'owner'::text
  or user_id = (select auth.uid())
);

drop policy if exists "Invitors can view their own invitations" on public.pending_invitations;
drop policy if exists "Property owners/managers can view invitations" on public.pending_invitations;

create policy "Invitors and property leads can view invitations"
on public.pending_invitations
for select
to authenticated
using (
  invited_by = (select auth.uid())
  or exists (
    select 1
    from public.property_members pm
    where pm.property_id = pending_invitations.property_id
      and pm.user_id = (select auth.uid())
      and pm.role = any (array['owner'::text, 'manager'::text])
  )
);

drop policy if exists "Users can view own profile" on public.profiles;
drop policy if exists "Users can view their own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Users can update their own profile" on public.profiles;

create policy "Users can view their own profile"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

create policy "Users can update their own profile"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

drop policy if exists "Users can manage their own tokens" on public.user_push_tokens;
drop policy if exists "Users can only manage their own tokens" on public.user_push_tokens;

create policy "Users can manage their own tokens"
on public.user_push_tokens
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Team members can view inspections" on public.inspections;
drop policy if exists "Team members can start inspections" on public.inspections;
drop policy if exists "Inspectors, Managers, and Owners can update" on public.inspections;
drop policy if exists "Only owners can delete inspections" on public.inspections;

create policy "Team members can view inspections"
on public.inspections
for select
to authenticated
using (get_user_role(property_id) is not null);

create policy "Team members can start inspections"
on public.inspections
for insert
to authenticated
with check (get_user_role(property_id) is not null);

create policy "Inspectors, managers, and owners can update inspections"
on public.inspections
for update
to authenticated
using (
  inspector_id = (select auth.uid())
  or get_user_role(property_id) = any (array['owner'::text, 'manager'::text])
)
with check (
  inspector_id = (select auth.uid())
  or get_user_role(property_id) = any (array['owner'::text, 'manager'::text])
);

create policy "Only owners can delete inspections"
on public.inspections
for delete
to authenticated
using (get_user_role(property_id) = 'owner'::text);

drop policy if exists "Team members can view inspection items" on public.inspection_items;
drop policy if exists "Team members can insert inspection items" on public.inspection_items;
drop policy if exists "Inspectors, Managers, and Owners can update items" on public.inspection_items;
drop policy if exists "Only owners can delete inspection items" on public.inspection_items;

create policy "Team members can view inspection items"
on public.inspection_items
for select
to authenticated
using (
  exists (
    select 1
    from public.inspections i
    where i.id = inspection_items.inspection_id
      and get_user_role(i.property_id) is not null
  )
);

create policy "Team members can insert inspection items"
on public.inspection_items
for insert
to authenticated
with check (
  exists (
    select 1
    from public.inspections i
    where i.id = inspection_items.inspection_id
      and get_user_role(i.property_id) is not null
  )
);

create policy "Inspectors, managers, and owners can update inspection items"
on public.inspection_items
for update
to authenticated
using (
  exists (
    select 1
    from public.inspections i
    where i.id = inspection_items.inspection_id
      and (
        i.inspector_id = (select auth.uid())
        or get_user_role(i.property_id) = any (array['owner'::text, 'manager'::text])
      )
  )
)
with check (
  exists (
    select 1
    from public.inspections i
    where i.id = inspection_items.inspection_id
      and (
        i.inspector_id = (select auth.uid())
        or get_user_role(i.property_id) = any (array['owner'::text, 'manager'::text])
      )
  )
);

create policy "Only owners can delete inspection items"
on public.inspection_items
for delete
to authenticated
using (
  exists (
    select 1
    from public.inspections i
    where i.id = inspection_items.inspection_id
      and get_user_role(i.property_id) = 'owner'::text
  )
);

drop policy if exists "Managers and Owners can manage photos" on public.property_photos;
drop policy if exists "Team members can view photos" on public.property_photos;

create policy "Team members can view photos"
on public.property_photos
for select
to authenticated
using (get_user_role(property_id) is not null);

create policy "Managers and owners can insert photos"
on public.property_photos
for insert
to authenticated
with check (get_user_role(property_id) = any (array['owner'::text, 'manager'::text]));

create policy "Managers and owners can update photos"
on public.property_photos
for update
to authenticated
using (get_user_role(property_id) = any (array['owner'::text, 'manager'::text]))
with check (get_user_role(property_id) = any (array['owner'::text, 'manager'::text]));

create policy "Managers and owners can delete photos"
on public.property_photos
for delete
to authenticated
using (get_user_role(property_id) = any (array['owner'::text, 'manager'::text]));

drop policy if exists "Managers and Owners can manage rooms" on public.property_rooms;
drop policy if exists "Team members can view rooms" on public.property_rooms;

create policy "Team members can view rooms"
on public.property_rooms
for select
to authenticated
using (get_user_role(property_id) is not null);

create policy "Managers and owners can insert rooms"
on public.property_rooms
for insert
to authenticated
with check (get_user_role(property_id) = any (array['owner'::text, 'manager'::text]));

create policy "Managers and owners can update rooms"
on public.property_rooms
for update
to authenticated
using (get_user_role(property_id) = any (array['owner'::text, 'manager'::text]))
with check (get_user_role(property_id) = any (array['owner'::text, 'manager'::text]));

create policy "Managers and owners can delete rooms"
on public.property_rooms
for delete
to authenticated
using (get_user_role(property_id) = any (array['owner'::text, 'manager'::text]));

drop policy if exists "Managers and Owners can manage inventory items" on public.room_inventory_items;
drop policy if exists "Team members can view inventory items" on public.room_inventory_items;

create policy "Team members can view inventory items"
on public.room_inventory_items
for select
to authenticated
using (
  exists (
    select 1
    from public.property_rooms r
    where r.id = room_inventory_items.room_id
      and get_user_role(r.property_id) is not null
  )
);

create policy "Managers and owners can insert inventory items"
on public.room_inventory_items
for insert
to authenticated
with check (
  exists (
    select 1
    from public.property_rooms r
    where r.id = room_inventory_items.room_id
      and get_user_role(r.property_id) = any (array['owner'::text, 'manager'::text])
  )
);

create policy "Managers and owners can update inventory items"
on public.room_inventory_items
for update
to authenticated
using (
  exists (
    select 1
    from public.property_rooms r
    where r.id = room_inventory_items.room_id
      and get_user_role(r.property_id) = any (array['owner'::text, 'manager'::text])
  )
)
with check (
  exists (
    select 1
    from public.property_rooms r
    where r.id = room_inventory_items.room_id
      and get_user_role(r.property_id) = any (array['owner'::text, 'manager'::text])
  )
);

create policy "Managers and owners can delete inventory items"
on public.room_inventory_items
for delete
to authenticated
using (
  exists (
    select 1
    from public.property_rooms r
    where r.id = room_inventory_items.room_id
      and get_user_role(r.property_id) = any (array['owner'::text, 'manager'::text])
  )
);

drop policy if exists "Authorized users can view properties" on public.properties;

create policy "Authorized users can view properties"
on public.properties
for select
to authenticated
using (
  owner_id = (select auth.uid())
  or public.get_user_role(id) is not null
);

drop policy if exists "Authorized users can view inspections" on public.inspections;
drop policy if exists "Authorized users can update inspections" on public.inspections;

create policy "Authorized users can view inspections"
on public.inspections
for select
to authenticated
using (
  inspector_id = (select auth.uid())
  or exists (
    select 1
    from public.properties p
    where p.id = inspections.property_id
      and p.owner_id = (select auth.uid())
  )
  or public.get_user_role(property_id) is not null
);

create policy "Authorized users can update inspections"
on public.inspections
for update
to authenticated
using (
  inspector_id = (select auth.uid())
  or exists (
    select 1
    from public.properties p
    where p.id = inspections.property_id
      and p.owner_id = (select auth.uid())
  )
  or public.get_user_role(property_id) = any (array['owner', 'manager', 'maintainer'])
)
with check (
  inspector_id = (select auth.uid())
  or exists (
    select 1
    from public.properties p
    where p.id = inspections.property_id
      and p.owner_id = (select auth.uid())
  )
  or public.get_user_role(property_id) = any (array['owner', 'manager', 'maintainer'])
);

drop policy if exists "Authorized users can view inspection items" on public.inspection_items;
drop policy if exists "Authorized users can insert inspection items" on public.inspection_items;
drop policy if exists "Authorized users can update inspection items" on public.inspection_items;
drop policy if exists "Only authorized owners can delete inspection items" on public.inspection_items;

create policy "Authorized users can view inspection items"
on public.inspection_items
for select
to authenticated
using (
  exists (
    select 1
    from public.inspections i
    join public.properties p on p.id = i.property_id
    where i.id = inspection_items.inspection_id
      and (
        i.inspector_id = (select auth.uid())
        or p.owner_id = (select auth.uid())
        or public.get_user_role(i.property_id) is not null
      )
  )
);

create policy "Authorized users can insert inspection items"
on public.inspection_items
for insert
to authenticated
with check (
  exists (
    select 1
    from public.inspections i
    join public.properties p on p.id = i.property_id
    where i.id = inspection_items.inspection_id
      and (
        i.inspector_id = (select auth.uid())
        or p.owner_id = (select auth.uid())
        or public.get_user_role(i.property_id) is not null
      )
  )
);

create policy "Authorized users can update inspection items"
on public.inspection_items
for update
to authenticated
using (
  exists (
    select 1
    from public.inspections i
    join public.properties p on p.id = i.property_id
    where i.id = inspection_items.inspection_id
      and (
        i.inspector_id = (select auth.uid())
        or p.owner_id = (select auth.uid())
        or public.get_user_role(i.property_id) = any (array['owner', 'manager', 'maintainer'])
      )
  )
)
with check (
  exists (
    select 1
    from public.inspections i
    join public.properties p on p.id = i.property_id
    where i.id = inspection_items.inspection_id
      and (
        i.inspector_id = (select auth.uid())
        or p.owner_id = (select auth.uid())
        or public.get_user_role(i.property_id) = any (array['owner', 'manager', 'maintainer'])
      )
  )
);

create policy "Only authorized owners can delete inspection items"
on public.inspection_items
for delete
to authenticated
using (
  exists (
    select 1
    from public.inspections i
    join public.properties p on p.id = i.property_id
    where i.id = inspection_items.inspection_id
      and (
        p.owner_id = (select auth.uid())
        or public.get_user_role(i.property_id) = 'owner'
      )
  )
);

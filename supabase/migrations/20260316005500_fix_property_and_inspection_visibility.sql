drop policy if exists "Users can view properties" on public.properties;

create policy "Authorized users can view properties"
on public.properties
for select
to authenticated
using (
  owner_id = auth.uid()
  or public.get_user_role(id) is not null
);

drop policy if exists "Team members can view inspections" on public.inspections;

create policy "Authorized users can view inspections"
on public.inspections
for select
to authenticated
using (
  inspector_id = auth.uid()
  or exists (
    select 1
    from public.properties p
    where p.id = inspections.property_id
      and p.owner_id = auth.uid()
  )
  or public.get_user_role(property_id) is not null
);

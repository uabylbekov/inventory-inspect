drop policy if exists "Inspectors, Managers, and Owners can update items" on public.inspection_items;
drop policy if exists "Inspectors, managers, and owners can update inspection items" on public.inspection_items;

create policy "Inspectors, managers, owners, and maintainers can update inspection items"
on public.inspection_items
for update
to authenticated
using (
  exists (
    select 1
    from public.inspections i
    where i.id = inspection_items.inspection_id
      and (
        i.inspector_id = auth.uid()
        or public.get_user_role(i.property_id) = any (array['owner', 'manager', 'maintainer'])
      )
  )
)
with check (
  exists (
    select 1
    from public.inspections i
    where i.id = inspection_items.inspection_id
      and (
        i.inspector_id = auth.uid()
        or public.get_user_role(i.property_id) = any (array['owner', 'manager', 'maintainer'])
      )
  )
);

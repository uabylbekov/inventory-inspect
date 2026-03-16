drop policy if exists "Inspectors, managers, and owners can update inspections" on public.inspections;
drop policy if exists "Inspectors, Managers, and Owners can update" on public.inspections;

create policy "Authorized users can update inspections"
on public.inspections
for update
to authenticated
using (
  inspector_id = auth.uid()
  or exists (
    select 1
    from public.properties p
    where p.id = inspections.property_id
      and p.owner_id = auth.uid()
  )
  or public.get_user_role(property_id) = any (array['owner', 'manager', 'maintainer'])
)
with check (
  inspector_id = auth.uid()
  or exists (
    select 1
    from public.properties p
    where p.id = inspections.property_id
      and p.owner_id = auth.uid()
  )
  or public.get_user_role(property_id) = any (array['owner', 'manager', 'maintainer'])
);

create or replace function public.storage_delete_object(bucket_id text, object_path text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  return;
end;
$$;

drop policy if exists "Authenticated users can upload images" on storage.objects;
drop policy if exists "Authenticated users can update images" on storage.objects;
drop policy if exists "Authenticated users can delete images" on storage.objects;
drop policy if exists "Authorized users can read inspection images" on storage.objects;

create policy "Authorized users can upload inspection images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'inspection-images'
  and coalesce(array_length(storage.foldername(name), 1), 0) >= 1
  and exists (
    select 1
    from public.inspections i
    join public.properties p on p.id = i.property_id
    where i.id::text = (storage.foldername(storage.objects.name))[1]
      and (
        i.inspector_id = auth.uid()
        or p.owner_id = auth.uid()
        or public.get_user_role(i.property_id) is not null
      )
  )
);

create policy "Authorized users can read inspection images"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'inspection-images'
  and coalesce(array_length(storage.foldername(name), 1), 0) >= 1
  and exists (
    select 1
    from public.inspections i
    join public.properties p on p.id = i.property_id
    where i.id::text = (storage.foldername(storage.objects.name))[1]
      and (
        i.inspector_id = auth.uid()
        or p.owner_id = auth.uid()
        or public.get_user_role(i.property_id) is not null
      )
  )
);

create policy "Authorized users can update inspection images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'inspection-images'
  and coalesce(array_length(storage.foldername(name), 1), 0) >= 1
  and exists (
    select 1
    from public.inspections i
    join public.properties p on p.id = i.property_id
    where i.id::text = (storage.foldername(storage.objects.name))[1]
      and (
        i.inspector_id = auth.uid()
        or p.owner_id = auth.uid()
        or public.get_user_role(i.property_id) is not null
      )
  )
)
with check (
  bucket_id = 'inspection-images'
  and coalesce(array_length(storage.foldername(name), 1), 0) >= 1
  and exists (
    select 1
    from public.inspections i
    join public.properties p on p.id = i.property_id
    where i.id::text = (storage.foldername(storage.objects.name))[1]
      and (
        i.inspector_id = auth.uid()
        or p.owner_id = auth.uid()
        or public.get_user_role(i.property_id) is not null
      )
  )
);

create policy "Authorized users can delete inspection images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'inspection-images'
  and coalesce(array_length(storage.foldername(name), 1), 0) >= 1
  and exists (
    select 1
    from public.inspections i
    join public.properties p on p.id = i.property_id
    where i.id::text = (storage.foldername(storage.objects.name))[1]
      and (
        i.inspector_id = auth.uid()
        or p.owner_id = auth.uid()
        or public.get_user_role(i.property_id) is not null
      )
  )
);

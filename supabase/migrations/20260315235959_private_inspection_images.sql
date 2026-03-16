update storage.buckets
set public = false
where id = 'inspection-images';

create or replace function public.extract_storage_path(url text)
returns text
language plpgsql
as $$
declare
  bucket_part text := 'inspection-images/';
  pos int;
begin
  if url is null or btrim(url) = '' then
    return null;
  end if;

  pos := strpos(url, bucket_part);
  if pos > 0 then
    return substring(url from pos + length(bucket_part));
  end if;

  return url;
end;
$$;

drop policy if exists "Public Access to Inspection Images" on storage.objects;
drop policy if exists "Authenticated users can read inspection images" on storage.objects;
drop policy if exists "Team members can read inspection images" on storage.objects;

create policy "Authorized users can read inspection images"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'inspection-images'
  and exists (
    select 1
    from public.inspection_items ii
    join public.inspections i on i.id = ii.inspection_id
    join public.properties p on p.id = i.property_id
    where ii.image_url = storage.objects.name
      and (
        i.inspector_id = auth.uid()
        or p.owner_id = auth.uid()
        or public.get_user_role(i.property_id) is not null
      )
  )
);

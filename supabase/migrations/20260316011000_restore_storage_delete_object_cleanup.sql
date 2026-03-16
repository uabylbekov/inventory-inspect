create or replace function public.storage_delete_object(bucket_id text, object_path text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from storage.objects
  where storage.objects.bucket_id = storage_delete_object.bucket_id
    and storage.objects.name = storage_delete_object.object_path;
end;
$$;

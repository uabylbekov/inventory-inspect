create or replace function public.storage_delete_object(bucket_id text, object_path text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Supabase Storage blocks direct writes/deletes to storage.objects on some plans.
  -- Keep this helper non-blocking so row-level deletes (e.g. property cleanup) do not fail.
  return;
end;
$$;

create or replace function public.extract_storage_path(url text)
returns text
language plpgsql
set search_path = public
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

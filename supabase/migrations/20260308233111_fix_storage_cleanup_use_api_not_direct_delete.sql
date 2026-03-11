-- Helper: delete one file from a bucket.
-- The historical production function used a project-specific service-role token,
-- which is intentionally not stored in git. This placeholder keeps fresh branch
-- creation working without leaking credentials into the repo.
CREATE OR REPLACE FUNCTION public.storage_delete_object(bucket_id text, object_path text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN;
END;
$$;

CREATE OR REPLACE FUNCTION public.on_inspection_item_delete_cleanup_storage()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  file_path text;
BEGIN
  IF OLD.image_url IS NOT NULL THEN
    file_path := public.extract_storage_path(OLD.image_url);
    IF file_path IS NOT NULL THEN
      PERFORM public.storage_delete_object('inspection-images', file_path);
    END IF;
  END IF;
  RETURN OLD;
END;
$$;

CREATE OR REPLACE FUNCTION public.on_inspection_item_update_cleanup_storage()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  old_file_path text;
  new_file_path text;
BEGIN
  IF OLD.image_url IS NOT NULL AND (NEW.image_url IS NULL OR NEW.image_url != OLD.image_url) THEN
    old_file_path := public.extract_storage_path(OLD.image_url);
    new_file_path := public.extract_storage_path(NEW.image_url);
    IF old_file_path IS NOT NULL AND (new_file_path IS NULL OR new_file_path != old_file_path) THEN
      PERFORM public.storage_delete_object('inspection-images', old_file_path);
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- Clean up duplicate active-inspection indexes and harden notification log access.

alter table public.app_store_server_notifications enable row level security;

do $$
begin
  if exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'inspections'
      and indexname = 'unq_active_inspection_per_property'
  ) and exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'inspections'
      and indexname = 'inspections_one_in_progress_per_property_idx'
  ) then
    execute 'drop index public.inspections_one_in_progress_per_property_idx';
  end if;
end
$$;

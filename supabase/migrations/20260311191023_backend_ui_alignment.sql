-- Align database constraints with the current UI/domain model.

update public.property_members
set role = 'maintainer'
where role = 'cleaner';

alter table public.property_members
drop constraint if exists property_members_role_check;

alter table public.property_members
add constraint property_members_role_check
check (role = any (array['owner'::text, 'manager'::text, 'maintainer'::text]));

alter table public.inspections
drop constraint if exists inspections_status_check;

alter table public.inspections
add constraint inspections_status_check
check (status = any (array['in_progress'::text, 'completed'::text, 'cancelled'::text]));

alter table public.inspection_items
alter column status set default 'present';

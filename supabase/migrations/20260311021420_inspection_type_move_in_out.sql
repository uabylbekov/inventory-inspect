update public.inspections
set inspection_type = 'move-in'
where inspection_type = 'check-in';

update public.inspections
set inspection_type = 'move-out'
where inspection_type = 'check-out';

alter table public.inspections
drop constraint if exists inspections_inspection_type_check;

alter table public.inspections
add constraint inspections_inspection_type_check
check (inspection_type = any (array['move-in'::text, 'move-out'::text, 'routine'::text]));

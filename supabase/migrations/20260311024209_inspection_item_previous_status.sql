alter table public.inspection_items
add column if not exists previous_status text;

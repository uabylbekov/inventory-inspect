-- notifications.is_read has DEFAULT false but was never constrained to NOT NULL.
-- A NULL is_read breaks unread badge counts (the push-notifications function
-- counts rows where is_read = false, which silently excludes NULLs).

update public.notifications set is_read = false where is_read is null;
alter table public.notifications alter column is_read set not null;

create policy "No direct client access to app store notifications"
on public.app_store_server_notifications
as restrictive
for all
to authenticated
using (false)
with check (false);

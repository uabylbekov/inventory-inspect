-- Tag each device token with its APNs environment so the push-notifications
-- function only dispatches to tokens matching the current APNs endpoint.
-- This prevents BadDeviceToken errors when sandbox tokens reach the production
-- APNs endpoint (e.g. a local debug registration leaking into the main project).
--
-- Default is 'production' so all existing tokens continue to work with the
-- production edge function without requiring a client-side change. The iOS app
-- should pass apns_environment ('production' | 'sandbox') when registering a
-- token going forward.

alter table public.user_push_tokens
  add column if not exists apns_environment text not null default 'production';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'user_push_tokens_apns_environment_check'
      and conrelid = 'public.user_push_tokens'::regclass
  ) then
    alter table public.user_push_tokens
      add constraint user_push_tokens_apns_environment_check
      check (apns_environment in ('production', 'sandbox'));
  end if;
end
$$;

-- Composite index for the filtered token lookup in push-notifications
create index if not exists user_push_tokens_user_env_idx
  on public.user_push_tokens (user_id, apns_environment);

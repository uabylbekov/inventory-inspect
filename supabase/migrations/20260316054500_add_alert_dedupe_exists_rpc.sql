create or replace function public.supabase_alert_dedupe_exists(p_event_key text)
returns boolean
language sql
security definer
set search_path = public, ops, pg_temp
as $$
  select exists (
    select 1
    from ops.supabase_alert_dedupe d
    where d.event_key = p_event_key
  );
$$;

grant execute on function public.supabase_alert_dedupe_exists(text) to service_role;

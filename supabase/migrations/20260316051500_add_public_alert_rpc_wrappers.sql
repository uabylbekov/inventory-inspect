create or replace function public.get_supabase_alert_cursor()
returns table (
  source text,
  last_checked_at timestamptz
)
language sql
security definer
set search_path = public, ops, pg_temp
as $$
  select c.source, c.last_checked_at
  from ops.supabase_alert_cursor c;
$$;

grant execute on function public.get_supabase_alert_cursor() to service_role;

create or replace function public.insert_supabase_alert_dedupe(
  p_event_key text,
  p_source text,
  p_event_timestamp timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = public, ops, pg_temp
as $$
begin
  insert into ops.supabase_alert_dedupe (
    event_key,
    source,
    event_timestamp
  ) values (
    p_event_key,
    p_source,
    p_event_timestamp
  );

  return true;
exception
  when unique_violation then
    return false;
end;
$$;

grant execute on function public.insert_supabase_alert_dedupe(text, text, timestamptz) to service_role;

create or replace function public.upsert_supabase_alert_cursor(p_rows jsonb)
returns void
language plpgsql
security definer
set search_path = public, ops, pg_temp
as $$
begin
  insert into ops.supabase_alert_cursor (
    source,
    last_checked_at
  )
  select
    row.source,
    row.last_checked_at
  from jsonb_to_recordset(p_rows) as row(
    source text,
    last_checked_at timestamptz
  )
  on conflict (source) do update
    set last_checked_at = excluded.last_checked_at;
end;
$$;

grant execute on function public.upsert_supabase_alert_cursor(jsonb) to service_role;

create or replace function public.cleanup_supabase_alert_dedupe(p_cutoff timestamptz)
returns bigint
language plpgsql
security definer
set search_path = public, ops, pg_temp
as $$
declare
  deleted_count bigint;
begin
  delete from ops.supabase_alert_dedupe
  where first_sent_at < p_cutoff;

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

grant execute on function public.cleanup_supabase_alert_dedupe(timestamptz) to service_role;

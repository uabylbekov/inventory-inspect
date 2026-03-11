create extension if not exists pg_net;
create extension if not exists pg_cron;

create schema if not exists ops;

create table if not exists ops.supabase_alert_cursor (
    source text primary key,
    last_checked_at timestamptz not null default timezone('utc', now())
);

create table if not exists ops.supabase_alert_dedupe (
    event_key text primary key,
    source text not null,
    event_timestamp timestamptz not null,
    first_sent_at timestamptz not null default timezone('utc', now())
);

create index if not exists supabase_alert_dedupe_first_sent_at_idx
    on ops.supabase_alert_dedupe (first_sent_at desc);

create or replace function ops.schedule_supabase_error_alerts(
    function_url text,
    cron_token text,
    schedule text default '*/5 * * * *'
)
returns bigint
language plpgsql
security definer
set search_path = public, extensions, net, cron, pg_temp
as $$
declare
    existing_job_id bigint;
    command text;
    job_id bigint;
begin
    select jobid
    into existing_job_id
    from cron.job
    where jobname = 'supabase_error_alerts'
    limit 1;

    if existing_job_id is not null then
        perform cron.unschedule(existing_job_id);
    end if;

    command := format(
        $fmt$
        select net.http_post(
            url := %L,
            headers := %L::jsonb,
            body := '{}'::jsonb
        ) as request_id;
        $fmt$,
        function_url,
        json_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || cron_token
        )::text
    );

    select cron.schedule('supabase_error_alerts', schedule, command)
    into job_id;

    return job_id;
end;
$$;

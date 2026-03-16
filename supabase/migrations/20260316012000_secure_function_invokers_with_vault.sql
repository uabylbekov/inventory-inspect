create or replace function ops.upsert_vault_secret(
  secret_name text,
  secret_value text,
  secret_description text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public, ops, vault, pg_temp
as $$
declare
  existing_secret_id uuid;
begin
  select id
    into existing_secret_id
  from vault.decrypted_secrets
  where name = secret_name
  limit 1;

  if existing_secret_id is null then
    return vault.create_secret(secret_value, secret_name, secret_description);
  end if;

  perform vault.update_secret(existing_secret_id, secret_value, secret_name, secret_description);
  return existing_secret_id;
end;
$$;

create or replace function public.invoke_push_notifications()
returns trigger
language plpgsql
security definer
set search_path = public, vault, net, extensions, pg_temp
as $$
declare
  function_url text;
  webhook_token text;
begin
  select decrypted_secret
    into function_url
  from vault.decrypted_secrets
  where name = 'push_notifications_function_url'
  limit 1;

  select decrypted_secret
    into webhook_token
  from vault.decrypted_secrets
  where name = 'push_notifications_webhook_token'
  limit 1;

  if function_url is null or webhook_token is null then
    raise exception 'Push notification vault secrets are not configured.';
  end if;

  perform net.http_post(
    url := function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || webhook_token
    ),
    body := jsonb_build_object('record', row_to_json(new))
  );

  return new;
end;
$$;

drop trigger if exists "run-push-notifications" on public.notifications;

create trigger "run-push-notifications"
after insert on public.notifications
for each row
execute function public.invoke_push_notifications();

create or replace function public.configure_push_notifications_invoker(
  function_url text,
  bearer_token text
)
returns void
language plpgsql
security definer
set search_path = public, ops, pg_temp
as $$
begin
  if function_url is null or btrim(function_url) = '' then
    raise exception 'function_url is required';
  end if;

  if bearer_token is null or btrim(bearer_token) = '' then
    raise exception 'bearer_token is required';
  end if;

  perform ops.upsert_vault_secret(
    'push_notifications_function_url',
    function_url,
    'Edge function URL for push notification delivery'
  );

  perform ops.upsert_vault_secret(
    'push_notifications_webhook_token',
    bearer_token,
    'Bearer token for invoking push notification delivery'
  );
end;
$$;

create or replace function ops.invoke_forward_supabase_error_alerts()
returns void
language plpgsql
security definer
set search_path = public, ops, vault, net, extensions, pg_temp
as $$
declare
  function_url text;
  cron_token text;
begin
  select decrypted_secret
    into function_url
  from vault.decrypted_secrets
  where name = 'forward_supabase_errors_function_url'
  limit 1;

  select decrypted_secret
    into cron_token
  from vault.decrypted_secrets
  where name = 'forward_supabase_errors_cron_token'
  limit 1;

  if function_url is null or cron_token is null then
    raise exception 'Forward Supabase errors vault secrets are not configured.';
  end if;

  perform net.http_post(
    url := function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || cron_token
    ),
    body := '{}'::jsonb
  );
end;
$$;

create or replace function ops.schedule_supabase_error_alerts(
    function_url text,
    cron_token text,
    schedule text default '*/5 * * * *'
)
returns bigint
language plpgsql
security definer
set search_path = public, ops, extensions, net, cron, pg_temp
as $$
declare
    existing_job_id bigint;
    job_id bigint;
begin
    if function_url is null or btrim(function_url) = '' then
        raise exception 'function_url is required';
    end if;

    if cron_token is null or btrim(cron_token) = '' then
        raise exception 'cron_token is required';
    end if;

    perform ops.upsert_vault_secret(
      'forward_supabase_errors_function_url',
      function_url,
      'Edge function URL for the Supabase error forwarder'
    );

    perform ops.upsert_vault_secret(
      'forward_supabase_errors_cron_token',
      cron_token,
      'Bearer token for invoking the Supabase error forwarder'
    );

    select jobid
    into existing_job_id
    from cron.job
    where jobname = 'supabase_error_alerts'
    limit 1;

    if existing_job_id is not null then
        perform cron.unschedule(existing_job_id);
    end if;

    select cron.schedule(
      'supabase_error_alerts',
      schedule,
      'select ops.invoke_forward_supabase_error_alerts();'
    )
    into job_id;

    return job_id;
end;
$$;

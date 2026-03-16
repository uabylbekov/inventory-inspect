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
    body := '{}'::jsonb,
    timeout_milliseconds := 15000
  );
end;
$$;

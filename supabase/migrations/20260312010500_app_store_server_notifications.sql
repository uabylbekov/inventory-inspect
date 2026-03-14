create table if not exists public.app_store_server_notifications (
  id bigint generated always as identity primary key,
  notification_uuid text not null unique,
  notification_type text not null,
  subtype text,
  app_store_original_transaction_id text,
  app_store_transaction_id text,
  app_store_product_id text,
  environment text,
  signed_payload text not null,
  synced_profile_count integer not null default 0,
  processed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.app_store_server_notifications enable row level security;

create index if not exists app_store_server_notifications_original_tx_idx
on public.app_store_server_notifications (app_store_original_transaction_id);

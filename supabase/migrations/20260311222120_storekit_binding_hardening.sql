-- Enforce one-to-one App Store subscription binding and protect against replay across accounts.

create unique index if not exists profiles_app_store_original_transaction_id_key
on public.profiles (app_store_original_transaction_id)
where app_store_original_transaction_id is not null;

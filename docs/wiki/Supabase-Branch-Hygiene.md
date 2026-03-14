# Supabase Branch Hygiene

## Why this page exists

This page explains one easy-to-miss problem:

- Git branches and Supabase branches are related
- but they are not magic
- if you let Git `test` build its own migration history, Supabase `test` can become unhealthy even when the app still seems to work

## The simple mental model

- Git `main` is the source of truth for shared database history
- Supabase `main` should follow that shared history
- Supabase `test` should be a clean preview of that history plus safe app testing

Bad pattern:

- create or keep branch-only migration files on Git `test`
- reset Supabase `test`
- Supabase rebuilds using a forked migration chain
- branch looks healthy for a moment
- branch later falls back to `MIGRATIONS_FAILED`

## What happened in this project

The Git `test` branch had migration files that Git `main` did not have.

Examples:

- `20260310_backend_readiness_cleanup.sql`
- `20260310_inspection_item_previous_status.sql`
- `20260310_inspection_type_move_in_out.sql`
- `20260310_invite_role_maintainer_validation.sql`
- `20260310_policy_cleanup.sql`
- `20260310_subscription_access_contract.sql`
- `20260310_supabase_error_alerts.sql`
- `20260310_team_role_maintainer.sql`
- `20260311_backend_ui_alignment.sql`
- `20260311_business_tier_rename.sql`
- `20260311_realtime_publication_alignment.sql`
- `20260311_storekit_backend_sync.sql`
- `20260311223000_storekit_binding_hardening.sql`

Those are real files in Git `test`. They are a warning sign because they create a branch-specific schema story.

## Junior-safe rules

1. If a database change matters to everyone, make it on Git `main`.
2. Do not create a special migration just to make Supabase `test` happy.
3. If Supabase `test` is unhealthy, compare its migration list to Supabase `main`.
4. If the same feature exists under different migration versions, that is drift.
5. The safest recovery is usually to reset or rebuild Supabase `test` from `main`.

## Non-negotiable timestamp rule

- After a migration version has been applied on any shared remote branch, do not rename that file just to change its timestamp.
- If ordering is wrong, create a new later migration that fixes the problem instead of rewriting shared history.
- A rename like `20260314022216_feature.sql` to `20260313180500_feature.sql` makes the file look local-only to Supabase even when the old version was already applied remotely.
- That exact pattern is how preview branches end up with `Remote migration versions not found in local migrations directory`.

## How to keep `test` and `main` compatible

1. Create shared migrations on Git `main`.
2. Merge or rebase Git `test` on top of Git `main` before trusting QA results.
3. Treat migration filenames as immutable once a remote branch has seen them.
4. When Supabase `test` drifts, reset or rebuild the branch instead of inventing replacement timestamps.
5. Verify that Supabase `main` and Supabase `test` report the same migration versions before app QA signoff.

## What to do before opening a QA bug

Check these first:

1. Which app config did you launch with?
   - `Prod.xcconfig` -> Supabase `main`
   - `Test.xcconfig` -> Supabase `test`
2. Is Supabase `test` healthy?
3. Does Git `test` contain migration files that Git `main` does not?
4. Does Supabase `test` show different migration versions for the same feature names?

If the answer to 3 or 4 is yes, the problem may be branch drift, not app code.

## Safe working process

1. Make the schema change as a normal migration from Git `main`.
2. Commit it.
3. Let Supabase `main` become the clean source of truth.
4. Rebuild or reset Supabase `test` from that clean state when needed.
5. Test app behavior after the branch is healthy again.

## What not to do

- Do not hand-edit random SQL directly in Supabase `test` and leave no repo migration.
- Do not keep duplicate migrations for the same logical feature under different version numbers.
- Do not trust QA results from a branch marked `MIGRATIONS_FAILED`.

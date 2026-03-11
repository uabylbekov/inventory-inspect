# Feedback, Alerts, and Operations

## Why this feature exists

This area covers the internal support loop for the app itself. It includes user-submitted feedback, backend alert forwarding, and operational observability around the Supabase deployment. New contributors often ignore this layer, but it is important for maintaining release quality once the app is in testers’ hands.

## Main files

- [`Snapshots/Views/Components/FeedbackSheet.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Components/FeedbackSheet.swift)
- [`Snapshots/ViewModels/FeedbackViewModel.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/ViewModels/FeedbackViewModel.swift)
- [`supabase/functions/send-feedback/index.ts`](/Users/uabylbekov/Projects/snapshots/supabase/functions/send-feedback/index.ts)
- [`supabase/functions/forward-supabase-errors/index.ts`](/Users/uabylbekov/Projects/snapshots/supabase/functions/forward-supabase-errors/index.ts)
- [`supabase/migrations/20260310_supabase_error_alerts.sql`](/Users/uabylbekov/Projects/snapshots/supabase/migrations/20260310_supabase_error_alerts.sql)

## In-app feedback flow

Users can open the feedback sheet from settings and submit categorized feedback.

Client payload includes:

- category
- category label
- message
- user name
- personal tier
- app version
- build number
- iOS version
- locale identifier

The client requires a minimum message length before submission is enabled.

## Feedback Edge Function behavior

`send-feedback`:

- requires a bearer token
- validates the current user via Supabase auth claims
- optionally enriches the sender with profile data from `profiles`
- formats a Discord webhook payload with metadata fields
- sends the feedback to a configured Discord webhook

This means failures can come from:

- missing authorization
- missing webhook secret
- invalid bearer token
- Discord webhook errors

## Operational error forwarding

`forward-supabase-errors` is a backend-facing operational function. It scans multiple Supabase log sources for notable errors and sends concise summaries to Discord.

It currently inspects:

- Edge Function logs
- Auth logs
- Postgres logs

It also maintains:

- per-source cursor state
- dedupe keys
- retention cleanup for dedupe rows

This is intended to reduce duplicate noise while still surfacing new production issues quickly.

## Why this matters to onboarding

This operational layer teaches new developers where production signals come from:

- tester reports arrive through the in-app feedback feature
- backend health issues arrive through Discord alerts

If an issue appears in one channel but not the other, that difference itself is diagnostic.

## Tester checklist

- Submit a valid feedback item and confirm the success state appears in-app.
- Attempt to submit a too-short message and confirm the form blocks submission.
- Verify category selection changes the intended feedback type.
- Confirm app version and environment details are included in the outbound payload during backend verification.
- Validate operational alerting after intentionally triggering a safe non-production backend error, if an environment exists for that purpose.

## Operational checklist for developers

- Confirm required secrets are present for each Edge Function.
- Confirm Discord webhooks are environment-specific.
- Confirm auth headers are passed for `send-feedback`.
- Confirm alert dedupe and cursor tables exist after migrations.
- Confirm alert volume is low enough to stay actionable.

## Edge cases to watch

- Discord webhook succeeds but the app shows a generic error due to decode mismatch.
- Auth claim lookup fails for an otherwise valid session.
- Alert dedupe grows without cleanup.
- A noisy error source crowds out a more important signal because of `MAX_EVENTS_PER_RUN`.

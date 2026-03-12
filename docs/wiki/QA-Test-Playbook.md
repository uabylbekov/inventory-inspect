# QA Test Playbook

## Purpose

This page gives testers and developers a practical regression plan for Snapshots. It is intentionally organized by user workflow so that onboarding can happen quickly even when automated tests are still minimal.

## Current testing reality

The repo contains placeholder unit and UI test targets, but most release confidence still comes from manual testing. As of March 10, 2026, contributors should assume that high-risk product changes require directed manual QA.

Relevant files:

- [`SnapshotsTests/SnapshotsTests.swift`](/Users/uabylbekov/Projects/snapshots/SnapshotsTests/SnapshotsTests.swift)
- [`SnapshotsUITests/SnapshotsUITests.swift`](/Users/uabylbekov/Projects/snapshots/SnapshotsUITests/SnapshotsUITests.swift)
- [`Docs/payment_testing_guide.md`](/Users/uabylbekov/Projects/snapshots/Docs/payment_testing_guide.md)

## Which backend are you testing?

Before you test anything, check which app config you launched:

- `Prod.xcconfig` -> Supabase `main`
- `Test.xcconfig` -> Supabase `test`

Simple rule for juniors:

- if you cannot explain which backend branch you are using, your test result is not reliable yet
- if `test` behaves differently from `main`, verify whether the difference is app code or branch drift before filing the bug

## If the `test` branch is unhealthy

Sometimes Supabase will show the `test` branch as `MIGRATIONS_FAILED`.

Plain-English meaning:

- the preview branch build history drifted or failed
- app requests may still work for some flows
- but you should not trust that branch for final QA results

What to do:

1. Compare behavior against `main`.
2. Check whether the branch has migration drift instead of blaming the iOS app first.
3. If the branch history is clearly off, rebuild or reset `test` from `main`.
4. Re-run the smoke test only after the branch status is healthy again.

## Recommended smoke path

Run this path after most feature changes:

1. Sign in or restore an existing session.
2. Confirm settings display the expected user name and plan.
3. Create or open a property.
4. Add or verify rooms and inventory items.
5. Start an inspection.
6. Record a mix of present, missing, and damaged states.
7. Complete the inspection.
8. Open the report and export a PDF.
9. Check notifications and sign out.

## Feature-specific test passes

### Auth and profile

- New user login flow
- Existing session restoration on app relaunch
- Profile completion gating
- Edit profile save flow
- Sign-out cleanup

### Properties and inventory

- Add, edit, delete property
- Delete property with active inspection warning
- Add, edit, delete room
- Add, edit, delete inventory item
- Empty-state rendering for no properties, no rooms, and no inventory

### Inspections

- Start inspection
- Progress updates at room and overall level
- Evidence image attachment
- Notes entry
- Cancel inspection
- Reopen cancelled inspection
- Complete inspection only when all required items are checked

### Reports

- Anomaly grouping
- Resolved issue grouping
- Present-and-intact grouping
- PDF generation
- Comparison workflow

### Collaboration and notifications

- Team management on premium property
- Restricted collaboration on free property
- Realtime inspection update on a second device
- Foreground notification behavior
- Background notification deep link behavior
- Tap an inspection-complete notification and confirm it opens the inspection
- Mark read, mark all read, delete notification
- Confirm only the signed-in user’s notifications appear in the inbox

### Entitlements and branding

- Free versus Pro versus Business behavior
- Sandbox and StoreKit testing path
- Supabase subscription override path
- Inherited premium access on a managed property
- Branding visibility in profile
- Branding output in exported PDFs

## High-risk regression areas

- Any change to `SnapshotsAccessManager`
- Any change to property ownership or membership queries
- Any change to inspection completion logic
- Any change to report rendering or PDF generation
- Any change to notification token handling or badge counts
- Any change to Edge Function auth or secrets
- Any difference between Supabase `main` and `test` branch schema or migration status

## Recommended test accounts

Maintain at least these personas in a shared QA environment:

- Free owner
- Pro owner
- Business owner
- Free manager on a Pro-owned property
- Free manager on a Business-owned property
- New user with incomplete profile

## Release signoff questions

- Can a new user reach a usable state without manual database intervention?
- Can a returning user resume work without stale auth or entitlement state?
- Can a property be fully configured end to end?
- Can an inspection be completed and exported?
- Does collaboration still work across users or devices?
- Do premium gates match the intended business rules?
- Do testers have a working feedback path if something breaks?

# Snapshots

Snapshots is an iOS property inspection app built with SwiftUI, Supabase, and StoreKit 2. It is designed for short-term rental operators and property teams who need repeatable room inventory checks, issue tracking, branded reports, and subscription-aware collaboration.

## What the app does

- Authenticates users with Supabase Auth.
- Stores properties, rooms, inventory templates, inspections, and team access in Supabase.
- Guides inspectors room by room through an inventory-based walkthrough.
- Generates PDF inspection reports and comparison workflows.
- Supports team collaboration, push notifications, and feedback submission.
- Gates premium functionality through StoreKit 2 plus Supabase-backed entitlement overrides.

## Tech stack

- iOS app: SwiftUI
- Backend: Supabase Auth, Postgres, Realtime, Storage, Edge Functions
- Payments: StoreKit 2
- Testing targets: `SnapshotsTests`, `SnapshotsUITests`

## Repository layout

- [`Snapshots/`](/Users/uabylbekov/Projects/snapshots/Snapshots) app source
- [`Snapshots/Core/`](/Users/uabylbekov/Projects/snapshots/Snapshots/Core) app lifecycle, auth bootstrap, access manager, notifications
- [`Snapshots/Views/`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views) feature UI grouped by domain
- [`Snapshots/ViewModels/`](/Users/uabylbekov/Projects/snapshots/Snapshots/ViewModels) feature state and Supabase integration
- [`Snapshots/Models/`](/Users/uabylbekov/Projects/snapshots/Snapshots/Models) app and Supabase models
- [`Snapshots/Utilities/`](/Users/uabylbekov/Projects/snapshots/Snapshots/Utilities) PDF generation and support utilities
- [`Snapshots/Utils/`](/Users/uabylbekov/Projects/snapshots/Snapshots/Utils) app configuration and shared helpers
- [`supabase/migrations/`](/Users/uabylbekov/Projects/snapshots/supabase/migrations) SQL migrations
- [`supabase/functions/`](/Users/uabylbekov/Projects/snapshots/supabase/functions) Edge Functions
- [`Docs/`](/Users/uabylbekov/Projects/snapshots/Docs) product, payment, and testing documentation
- [`Docs/wiki/`](/Users/uabylbekov/Projects/snapshots/Docs/wiki) GitHub-wiki-ready onboarding pages

## Core product areas

- Authentication and profile completion
- Property, room, and inventory management
- Inspection execution and issue tracking
- Inspection reporting and PDF export
- Team management and property-based access inheritance
- Subscription plans, branding, and entitlement enforcement
- Notifications, feedback collection, and backend operations

## Local setup

### Prerequisites

- Xcode with iOS SDK support
- A Supabase project with the required schema and Edge Functions
- Apple developer access for push notification and StoreKit configuration when testing device flows

### App configuration

The app reads runtime configuration from the app bundle via [`EnvConfig.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Utils/EnvConfig.swift).

Required keys:

- `SUPABASE_URL`
- `SUPABASE_KEY`
- `TERMS_URL`
- `PRIVACY_URL`

Environment values are currently sourced through:

- [`Snapshots/Test.xcconfig`](/Users/uabylbekov/Projects/snapshots/Snapshots/Test.xcconfig)
- [`Snapshots/Prod.xcconfig`](/Users/uabylbekov/Projects/snapshots/Snapshots/Prod.xcconfig)

### Supabase branches in plain English

If you are new to the project, this is the simplest way to think about the database setup:

- `main` branch: production-style branch for the Snapshots project ref `ulsckwhhnaxxebrthzpn`
- `test` branch: preview/test branch for project ref `nmtifjchsgdnfknkpowu`
- [`Snapshots/Prod.xcconfig`](/Users/uabylbekov/Projects/snapshots/Snapshots/Prod.xcconfig) points at `main`
- [`Snapshots/Test.xcconfig`](/Users/uabylbekov/Projects/snapshots/Snapshots/Test.xcconfig) points at `test`

Why this matters:

- When app behavior looks wrong, always check which config you launched with first.
- A bug in `test` may be caused by branch drift rather than app code.
- A fix is not really done until you know whether it was checked against both branches.

If `test` shows `MIGRATIONS_FAILED`, use simple junior-level thinking:

- the app may still partly work
- but the branch is not trustworthy for QA signoff
- the safest fix is usually to rebuild or reset the `test` branch from `main` instead of hand-editing random SQL in the branch
- branch-only migration history is a warning sign that `test` drifted away from the repo

Important repo rule:

- shared Supabase migrations should be created from Git `main`
- Git `test` is for app testing, not for inventing a separate database history
- if Git `test` contains migration files that Git `main` does not have, Supabase `test` will likely drift and fail again
- once a migration filename has been applied on a shared remote branch, do not rename its timestamp; add a new follow-up migration instead

### Backend expectations

The iOS app expects these Supabase capabilities to exist:

- Auth session management
- `profiles`, `properties`, `property_rooms`, `room_inventory_items`, `inspections`, `inspection_items`, `notifications`, `user_push_tokens`
- Realtime subscriptions for notifications and live inspection updates
- Storage bucket for company logos
- Edge Functions:
  - [`push-notifications`](/Users/uabylbekov/Projects/snapshots/supabase/functions/push-notifications/index.ts)
  - [`send-feedback`](/Users/uabylbekov/Projects/snapshots/supabase/functions/send-feedback/index.ts)
  - [`forward-supabase-errors`](/Users/uabylbekov/Projects/snapshots/supabase/functions/forward-supabase-errors/index.ts)

## App startup flow

1. `InspectionsApp` launches [`RootView`](/Users/uabylbekov/Projects/snapshots/Snapshots/Core/RootView.swift).
2. [`AuthManager`](/Users/uabylbekov/Projects/snapshots/Snapshots/Core/AuthManager.swift) checks for an existing Supabase session.
3. If authenticated, the app verifies whether profile completion is finished.
4. [`SnapshotsAccessManager`](/Users/uabylbekov/Projects/snapshots/Snapshots/Core/SnapshotsAccessManager.swift) refreshes entitlements from StoreKit 2 and Supabase profile data.
5. [`NotificationManager`](/Users/uabylbekov/Projects/snapshots/Snapshots/Core/NotificationManager.swift) requests permissions, registers device state, fetches notifications, and opens realtime listeners.
6. The user lands in the main tab experience: inspections, properties, and settings.

## Important onboarding notes

- The app uses a hybrid entitlement model. A user may have premium access because they purchased directly or because they are operating inside a premium property owned by another user.
- Feature gating is contextual. A user can have premium capabilities on one property and restricted capabilities on another.
- The inspection workflow is inventory-driven. Reports depend on the room and item templates that existed when the inspection was performed.
- Push notifications and realtime updates are separate but complementary. Realtime keeps in-app lists fresh, while APNs drives device alerts and badge counts.
- Owners and managers can change property structure. Maintainers can still use the property, but they should not see edit or delete controls for the template data.

## Testing status in this repo

- Unit tests are currently skeletal in [`SnapshotsTests/SnapshotsTests.swift`](/Users/uabylbekov/Projects/snapshots/SnapshotsTests/SnapshotsTests.swift).
- UI tests are currently skeletal in [`SnapshotsUITests/SnapshotsUITests.swift`](/Users/uabylbekov/Projects/snapshots/SnapshotsUITests/SnapshotsUITests.swift).
- Payment-specific manual validation guidance already exists in [`Docs/payment_testing_guide.md`](/Users/uabylbekov/Projects/snapshots/Docs/payment_testing_guide.md).

New contributors should expect manual QA to still be important, especially around:

- entitlement transitions
- inherited access
- realtime inspection updates
- push notification delivery
- PDF branding output

## Documentation for onboarding

Start with these pages:

- [`Docs/wiki/Home.md`](/Users/uabylbekov/Projects/snapshots/Docs/wiki/Home.md)
- [`Docs/wiki/Architecture-and-Data-Flow.md`](/Users/uabylbekov/Projects/snapshots/Docs/wiki/Architecture-and-Data-Flow.md)
- [`Docs/wiki/QA-Test-Playbook.md`](/Users/uabylbekov/Projects/snapshots/Docs/wiki/QA-Test-Playbook.md)

Feature-specific pages:

- [`Docs/wiki/Authentication-and-Profile-Setup.md`](/Users/uabylbekov/Projects/snapshots/Docs/wiki/Authentication-and-Profile-Setup.md)
- [`Docs/wiki/Properties-Rooms-and-Inventory.md`](/Users/uabylbekov/Projects/snapshots/Docs/wiki/Properties-Rooms-and-Inventory.md)
- [`Docs/wiki/Inspections-and-Reports.md`](/Users/uabylbekov/Projects/snapshots/Docs/wiki/Inspections-and-Reports.md)
- [`Docs/wiki/Team-Collaboration-and-Notifications.md`](/Users/uabylbekov/Projects/snapshots/Docs/wiki/Team-Collaboration-and-Notifications.md)
- [`Docs/wiki/Subscriptions-Entitlements-and-Branding.md`](/Users/uabylbekov/Projects/snapshots/Docs/wiki/Subscriptions-Entitlements-and-Branding.md)
- [`Docs/wiki/Feedback-Alerts-and-Operations.md`](/Users/uabylbekov/Projects/snapshots/Docs/wiki/Feedback-Alerts-and-Operations.md)

## Publishing the wiki to GitHub

GitHub wikis live in a separate repository named `<repo>.wiki.git`. The pages in [`Docs/wiki/`](/Users/uabylbekov/Projects/snapshots/Docs/wiki) were written in GitHub Wiki Markdown format so they can be copied directly into that wiki repository.

Recommended publish flow:

1. Create or clone the repository wiki.
2. Copy the contents of [`Docs/wiki/`](/Users/uabylbekov/Projects/snapshots/Docs/wiki) into the wiki repo root.
3. Keep file names unchanged so GitHub uses them as page titles.
4. Commit and push from the wiki repo.

## Notion Legal Links

The app legal links now point to Notion pages:

- Terms of Service: [Snapshots Terms of Service](https://www.notion.so/323de2034815815182d8feff87988288)
- Privacy Policy: [Snapshots Privacy Policy](https://www.notion.so/323de203481581b7a3d7c8a3be870743)

Configured app targets:

- [`Snapshots/Test.xcconfig`](/Users/uabylbekov/Projects/snapshots/Snapshots/Test.xcconfig)
- [`Snapshots/Prod.xcconfig`](/Users/uabylbekov/Projects/snapshots/Snapshots/Prod.xcconfig)

Before shipping or submitting to the App Store, make sure those Notion pages are published publicly in Notion so the links can open for users who are not signed in to your workspace.

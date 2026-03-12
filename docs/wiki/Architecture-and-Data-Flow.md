# Architecture and Data Flow

## High-level architecture

Snapshots is a SwiftUI iOS app backed by Supabase. The client owns most of the interaction logic, while Supabase provides authentication, persistence, storage, realtime channels, and server-side extensions such as push delivery and operational alert forwarding.

The main layers are:

- App shell and lifecycle in `Snapshots/Core`
- Feature UI in `Snapshots/Views`
- Feature state and data loading in `Snapshots/ViewModels`
- Supabase-facing models in `Snapshots/Models`
- Shared rendering and support utilities in `Snapshots/Utilities` and `Snapshots/Utils`
- Database schema and backend automation in `supabase/migrations` and `supabase/functions`

## Supabase environments

There are two Supabase branches connected to this repo:

- `main`: production-style branch, project ref `ulsckwhhnaxxebrthzpn`
- `test`: preview branch, project ref `nmtifjchsgdnfknkpowu`

For junior contributors, the safest rule is:

- `Prod.xcconfig` means you are testing against `main`
- `Test.xcconfig` means you are testing against `test`
- if something works in one branch but not the other, do not guess; compare schema state and branch status first

One extra rule that saves time:

- do not create branch-only migration chains unless you truly mean to diverge from `main`
- if `test` has different migration versions for the same logical feature, branch drift is usually the real bug
- the clean recovery path is to reset or rebuild `test` from `main`, then re-test

## Startup sequence

1. `InspectionsApp` configures notification delegation and deep-link handling.
2. `RootView` asks `AuthManager` whether a Supabase session already exists.
3. `AuthManager` determines:
   - authenticated or signed out
   - profile complete or incomplete
4. `SnapshotsAccessManager` refreshes StoreKit and Supabase-backed entitlements.
5. `NotificationManager` boots notification permissions, token registration, notification fetch, and realtime subscription for the authenticated user.
6. `MainTabView` exposes inspections, properties, and settings.

## Main data entities

The primary app entities are defined in [`Snapshots/Models/SupabaseModels.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Models/SupabaseModels.swift).

- `PropertyModel`: a property plus owner metadata used for subscription inheritance
- `PropertyRoomModel`: a room within a property
- `RoomInventoryItemModel`: an expected item within a room
- `InspectionModel`: a walkthrough session for a property
- `InspectionItemModel`: the recorded state of an inventory item during an inspection
- `NotificationModel`: an in-app notification row synced from Supabase

The important architectural point is that inspection data references inventory templates rather than embedding copies of room or item names. That keeps the write path simple, but it means the reporting layer must join inspection rows back to rooms and inventory items to produce a usable report.

## Feature ownership map

- Auth bootstrap: [`AuthManager.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Core/AuthManager.swift)
- Entitlements: [`SnapshotsAccessManager.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Core/SnapshotsAccessManager.swift)
- Notifications: [`NotificationManager.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Core/NotificationManager.swift)
- Properties list: [`PropertyViewModel.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/ViewModels/PropertyViewModel.swift)
- Property detail and rooms: [`PropertyDetailViewModel.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/ViewModels/PropertyDetailViewModel.swift)
- Room inventory: [`RoomInventoryViewModel.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/ViewModels/RoomInventoryViewModel.swift)
- Inspection execution: [`InspectionHubViewModel.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/ViewModels/InspectionHubViewModel.swift)
- Reporting: [`InspectionReportViewModel.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/ViewModels/InspectionReportViewModel.swift)
- Comparison: [`ComparisonReportViewModel.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/ViewModels/ComparisonReportViewModel.swift)
- Feedback: [`FeedbackViewModel.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/ViewModels/FeedbackViewModel.swift)

## Realtime model

Snapshots uses realtime in two distinct ways:

- Inspection collaboration: the inspection hub subscribes to `inspection_items` changes for the active inspection and refreshes state when another user records an item.
- Notifications: the app listens for new rows in `notifications` for the signed-in user and updates the in-app inbox immediately.

This means QA should treat realtime behavior as a first-class feature, not as a background implementation detail.

## Backend integrations

### Supabase Auth

- Restores sessions on launch
- Updates profile metadata such as `full_name`
- Provides the bearer token for authenticated Edge Function calls

### Supabase Postgres

- Stores business entities and access relationships
- Supports RPC fallback and access-contract style queries for property visibility
- Holds operational tables for alert dedupe and cursor tracking
- Enforces role rules with RLS so owners and managers can edit template data, while maintainers stay read-only for that part of the app

### Supabase Storage

- Stores company logo uploads used in branded PDFs and profile branding

### Supabase Edge Functions

- `push-notifications`: sends APNs payloads and badge counts
- `send-feedback`: forwards in-app feedback to Discord
- `forward-supabase-errors`: polls Supabase analytics logs and forwards notable errors to Discord

## Entitlement architecture

The app uses a hybrid entitlement model:

- App Store subscriptions are read via StoreKit 2.
- Supabase profile fields can override the tier for VIP or lifetime access.
- Property owners can indirectly grant premium capabilities to managers working inside their properties.

The design intent is that billing identity and property capability are related but not identical. That distinction matters throughout the UI and report generation logic.

## Testing implications

The test targets in this repo are still mostly placeholders, so manual verification remains important. Engineers should assume changes to any of these areas need targeted regression coverage:

- auth bootstrap and sign-out cleanup
- profile completion flow
- premium gating
- property deletion with active inspections
- inspection collaboration and completion rules
- report generation and image rendering
- notifications, deep links, and badge count behavior

# Snapshots Codebase Test Cases

This document maps the existing codebase to test cases. Some cases are automated today in `SnapshotsTests`, while others are integration or manual cases until the app exposes better dependency-injection seams for Supabase, StoreKit, notifications, and PDF export.

## Automated unit coverage in `SnapshotsTests`

### Shared models and utilities

- `ProfileModel` and `BillingDateParser`
  - Parses ISO8601 billing dates with and without fractional seconds.
  - Rejects malformed billing dates.
  - Promotes a free profile to `pro` when synced App Store billing is active and unexpired.
  - Falls back to `free` when the synced App Store subscription is expired.
  - Preserves `business` access for business-tier accounts.

- `PropertyModel`
  - Prefers owner full name for display.
  - Falls back to the email prefix when full name is missing.
  - Grants edit permission to managers and owners.
  - Grants delete permission only to owners.
  - Inherits owner `pro` tier from synced billing state.

- `SnapshotCacheKey`
  - Produces deterministic lowercase cache keys for properties, inspections, reports, and comparisons.

- `ExportFileNameBuilder`
  - Sanitizes whitespace and punctuation.
  - Produces timestamped PDF filenames in the expected format.

- `AppFormatter`
  - Formats inspection types into user-facing labels.
  - Parses ISO8601 dates with and without fractional seconds.
  - Returns the original string when date parsing fails.

- `PropertyUI` and `StatusUI`
  - Returns expected SF Symbol identifiers for known and unknown property, room, and status values.

- `DiffItem` and `ReportItem`
  - Uses stable identity derived from comparison fields.
  - Uses the underlying inspection item ID for report item identity.

- `SnapshotsAccessManager.PhotoAttachmentError`
  - Produces the expected user-facing limit-reached message.

### View model and workflow logic

- `AddPropertyViewModel`
  - Requires a non-empty property name.
  - Rejects overlong property names.
  - Rejects non-positive guest counts.
  - Rejects overlong postal codes.
  - Accepts valid trimmed form values.

- `EditPropertyViewModel`
  - Mirrors add-property validation rules.
  - Disables save while loading or saving.

- `AddRoomViewModel` and `AddItemViewModel`
  - Disables save for blank names.
  - Enables save when names are present.

- `EditRoomViewModel` and `EditItemViewModel`
  - Initializes editable state from the supplied model.
  - Disables save for blank names.

- `ManageTeamViewModel`
  - Accepts trimmed valid emails.
  - Rejects obviously invalid emails.
  - Disables invite while saving.

- `StartInspectionViewModel`
  - Preserves preloaded properties.
  - Skips the loading state when preloaded data exists.

- `FeedbackViewModel`
  - Trims message content.
  - Enforces minimum-length submission rules.
  - Exposes stable category metadata and Discord labels.

- `InspectionHubViewModel`
  - Calculates per-room progress correctly.
  - Marks fully inspected rooms as complete.
  - Treats empty rooms as `Empty`.
  - Prevents an all-empty property from being considered completable.
  - Finds inspection records by inventory item.

- `InspectionsViewModel`
  - Filters inspections by the selected day.
  - Uses `started_at` for in-progress inspections and `completed_at` for completed ones.
  - Resets the filter back to today.

- `ComparisonReportViewModel`
  - Orders the older/newer inspection pair chronologically.

## Remaining codebase cases to automate next

These are good candidates for automated tests once the app injects service dependencies instead of calling globals directly.

### Core app and access control

- `Snapshots/App/SnapshotsApp.swift`
  - APNs token registration updates state and forwards the expected token string.
  - Notification registration error paths do not crash the app.

- `Snapshots/App/RootView.swift`
  - Routes signed-out users to login.
  - Routes signed-in users without profile completion to profile setup.
  - Routes signed-in users with profile completion to the main tab UI.

- `Snapshots/Core/AuthManager.swift`
  - Handles sign-in, sign-out, and session refresh success paths.
  - Surfaces auth errors to the UI.
  - Clears local state after sign-out.

- `Snapshots/Core/SnapshotsAccessManager.swift`
  - Resolves free, pro, business, and lifetime limits.
  - Applies override limits on top of tier defaults.
  - Grants inherited access from a property owner when the current user is not directly entitled.
  - Blocks property creation when the owned-property limit is reached.
  - Blocks team invites when the team-member limit is reached.
  - Allows photo attachment when editing an existing image even if the photo limit is full.
  - Updates photo usage for the signed-in owner.

- `Snapshots/Core/NotificationManager.swift`
  - Fetches unread notifications.
  - Updates badge counts.
  - Handles missing push token and authorization-denied states cleanly.

### Property flows

- `Snapshots/Features/Properties/ViewModels/PropertyViewModel.swift`
  - Resolves add-property destination to paywall vs create flow.
  - Loads cached properties before remote refresh.
  - Saves refreshed properties back into cache.
  - Removes deleted properties from in-memory state and cache.

- `Snapshots/Features/Properties/ViewModels/PropertyDetailViewModel.swift`
  - Resolves owner/manager/maintainer role flags.
  - Resolves manage-team destination to paywall vs team management.
  - Loads cached snapshot before remote refresh.
  - Removes deleted rooms from local state after successful deletion.
  - Removes deleted properties from cache.

- `Snapshots/Features/Properties/ViewModels/RoomInventoryViewModel.swift`
  - Loads room inventory.
  - Updates local inventory state after deletes or edits.
  - Surfaces fetch/save failures.

- `Snapshots/Features/Properties/ViewModels/InventoryItemDetailViewModel.swift`
  - Loads item history and related inspections.
  - Handles missing item data and fetch errors.

### Inspection flows

- `Snapshots/Features/Inspections/ViewModels/StartInspectionViewModel.swift`
  - Detects active inspections for a property.
  - Detects same-day duplicate move-in/move-out inspections.
  - Maps unique-constraint backend errors into user-friendly copy.
  - Returns a newly created inspection ID on success.

- `Snapshots/Features/Inspections/ViewModels/InspectionsViewModel.swift`
  - Counts missing/damaged items as anomalies.
  - Counts resolved items separately.
  - Updates local state after cancel, reopen, and delete actions.
  - Persists updated lists and counts to cache.

- `Snapshots/Features/Inspections/ViewModels/InspectionHubViewModel.swift`
  - Loads cached snapshot before remote refresh.
  - Applies realtime insert/update events to local state.
  - Falls back to polling when realtime subscription fails.
  - Clears cached report/hub state after deletion.

- `Snapshots/Features/Inspections/ViewModels/InspectionItemDetailViewModel.swift`
  - Saves status, notes, and image changes.
  - Uploads images and preserves previous images.
  - Enforces photo limits with the access manager.
  - Handles optimistic UI fallback after save failures.

- `Snapshots/Features/Inspections/ViewModels/InspectionReportViewModel.swift`
  - Loads cached snapshot before refresh.
  - Resolves anomalies into the resolved bucket optimistically.
  - Rolls back optimistic resolution if the backend update fails.

- `Snapshots/Features/Inspections/ViewModels/ComparisonReportViewModel.swift`
  - Loads cached snapshot before refresh.
  - Saves comparison snapshot to cache.

### Team, settings, notifications, and feedback

- `Snapshots/Features/Team/ViewModels/ManageTeamViewModel.swift`
  - Surfaces billing-rule RPC missing-function errors with the custom message.
  - Distinguishes pending invite vs immediate add success messages.
  - Refreshes members after removal.
  - Allows a maintainer to leave a property.

- `Snapshots/Features/Feedback/ViewModels/FeedbackViewModel.swift`
  - Sends the expected payload fields to the Edge Function.
  - Clears message state after successful submission.
  - Surfaces server-side `error` payloads.

- `Snapshots/Features/Settings/Views/EditProfileView.swift`
  - Saves profile updates.
  - Handles optional company branding fields.
  - Preserves existing values when optional fields are blank.

- `Snapshots/Features/Notifications/Views/NotificationsView.swift`
  - Renders unread/read states correctly.
  - Marks notifications read.
  - Handles empty-state rendering.

## UI test cases for the existing app

These belong in `SnapshotsUITests` with seeded test accounts and launch arguments.

- Authentication
  - Launch signed out and verify the login screen.
  - Complete magic-link sign-in on a test account.
  - Verify profile completion gating for first-time users.

- Properties
  - Create a property with valid values.
  - Block property creation when plan limit is reached.
  - Edit and delete a property.
  - Create, edit, and delete rooms.
  - Create, edit, and delete inventory items.

- Inspections
  - Start a routine inspection and navigate room by room.
  - Block duplicate active inspections for the same property.
  - Mark items present, missing, damaged, and resolved.
  - Complete, reopen, cancel, and delete inspections.
  - Open the report and comparison flows.

- Team and billing
  - Open team management from a pro/business property.
  - Verify paywall routing for non-entitled users.
  - Send a property invite and confirm success messaging.
  - Exercise StoreKit paywall purchase, restore, and downgrade states in a StoreKit configuration.

- Notifications and feedback
  - Open the notifications screen and confirm unread indicators.
  - Submit feedback successfully.
  - Verify feedback validation blocks short messages.

## Backend and Supabase function test cases

These can be covered with integration tests or staged-environment smoke tests.

- `supabase/functions/send-property-invite/index.ts`
  - Creates a pending invite for a non-user email.
  - Adds an existing user directly when allowed.
  - Rejects invalid roles or unauthorized callers.

- `supabase/functions/send-feedback/index.ts`
  - Accepts authenticated feedback payloads.
  - Rejects malformed payloads.
  - Forwards category labels and metadata fields correctly.

- `supabase/functions/push-notifications/index.ts`
  - Sends push notifications to valid device tokens.
  - Skips or logs invalid tokens without failing the entire batch.

- `supabase/functions/sync-storekit-subscription/index.ts`
  - Accepts valid transaction IDs and updates tier state.
  - Rejects invalid or expired transactions.
  - Preserves previous billing info when verification fails.

- `supabase/functions/app-store-server-notifications/index.ts`
  - Handles subscription renewal, expiration, and cancellation events.
  - Rejects malformed or unsigned notifications.

- `supabase/functions/forward-supabase-errors/index.ts`
  - Forwards expected error payloads.
  - Avoids leaking secrets in forwarded diagnostics.

## Database migration verification cases

- Apply migrations against a clean database.
- Apply migrations against a recent production clone.
- Verify RLS policies still allow the intended owner/manager/maintainer actions.
- Verify helper RPCs like `can_user_create_property`, `can_invite_property_member`, and `get_property_team_members` exist and return expected results.
- Verify App Store notification tables and subscription columns match the app’s expectations.

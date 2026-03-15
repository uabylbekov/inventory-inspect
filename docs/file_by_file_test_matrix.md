# Snapshots File-By-File Test Matrix

This matrix assigns concrete test cases to each source file in the existing codebase.

Legend:
- `Unit`: deterministic logic, formatting, validation, state transitions
- `UI`: screen rendering, navigation, interaction, accessibility, visual states
- `Integration`: Supabase, StoreKit, notifications, cache, realtime, file export
- `Manual`: device-only or external-system verification

## App

### `Snapshots/App/SnapshotsApp.swift`
- `Integration`: app delegate registers for push notifications and forwards APNs token updates.
- `Integration`: APNs registration failure path does not crash and preserves app launch.
- `Manual`: cold launch with valid notification permissions updates push token in backend.

### `Snapshots/App/RootView.swift`
- `UI`: signed-out state shows login flow.
- `UI`: signed-in user with incomplete profile routes to profile completion.
- `UI`: signed-in user with completed profile routes to main tabs.

### `Snapshots/App/MainTabView.swift`
- `UI`: each main tab renders and can be selected.
- `UI`: badge or notification affordances update when backing state changes.
- `UI`: layout adapts correctly between compact and regular width.

## Core

### `Snapshots/Core/AuthManager.swift`
- `Integration`: sign-in request succeeds and stores session state.
- `Integration`: sign-in failure exposes user-facing error state.
- `Integration`: sign-out clears session-bound state and returns to signed-out UI.

### `Snapshots/Core/SnapshotsAccessManager.swift`
- `Unit`: free, pro, business, and lifetime tiers resolve to expected property, team, and photo limits.
- `Unit`: override limits replace default tier limits.
- `Unit`: inherited owner tier grants access for shared properties.
- `Unit`: `canAddProperty` blocks once owned property count reaches the plan limit.
- `Unit`: `canAddTeamMember` blocks once member count reaches the plan limit.
- `Integration`: `canAttachPhoto` allows existing-image edits even when the photo limit is full.
- `Integration`: StoreKit sync updates active tier and billing state.

### `Snapshots/Core/EnvConfig.swift`
- `Unit`: required config keys load from bundle values when present.
- `Unit`: missing or malformed values fail predictably with a useful error.
- `Manual`: test, staging, and prod xcconfig values map to the intended backend environments.

### `Snapshots/Core/Supabase.swift`
- `Integration`: Supabase client initializes with configured URL and key.
- `Integration`: auth and database calls use the shared configured client.

### `Snapshots/Core/NotificationManager.swift`
- `Integration`: unread notifications fetch correctly from backend.
- `Integration`: mark-read and badge count updates persist.
- `Integration`: missing token or denied notification permissions do not crash.
- `Manual`: push delivery appears on device and opens the expected destination.

## Shared Components

### `Snapshots/Shared/Components/SubscriptionPlanViews.swift`
- `UI`: free, pro, and business plan cards render correct names, prices, and feature lists.
- `UI`: currently selected plan is visually distinguished.
- `UI`: CTA buttons reflect purchase, restore, and loading states.

### `Snapshots/Shared/Components/PropertyUI.swift`
- `Unit`: property type maps to the expected SF Symbol.
- `Unit`: property type maps to the expected accent color.
- `Unit`: room type maps to the expected SF Symbol and fallback for unknown values.

### `Snapshots/Shared/Components/StatusComponents.swift`
- `Unit`: inspection/item statuses map to the expected icon and color.
- `UI`: `PlanBadge` renders only for entitled users and shows the correct label.
- `UI`: `StatusBadge` formats underscored statuses into readable labels.
- `UI`: `LoadingOverlay` renders spinner and message without clipping on small screens.

### `Snapshots/Shared/Components/ImagePicker.swift`
- `UI`: image picker opens camera when capture is available.
- `UI`: image picker falls back to photo library when camera is unavailable.
- `Manual`: selected image is returned to the host view correctly.

### `Snapshots/Shared/Components/NotificationBellView.swift`
- `UI`: unread count appears when notifications are pending.
- `UI`: tapping bell opens the notifications destination.
- `UI`: zero unread count hides or neutralizes badge state appropriately.

### `Snapshots/Shared/Components/FullScreenImageView.swift`
- `UI`: image renders fullscreen with dismiss control.
- `UI`: zoom and pan interactions remain bounded and recover after dismissal.
- `Manual`: remote images render smoothly on device for large assets.

## Shared Utilities

### `Snapshots/Shared/Utilities/SnapshotCacheKey.swift`
- `Unit`: each helper returns a deterministic lowercase cache key.
- `Unit`: comparison report keys preserve ordering of `older` and `newer`.

### `Snapshots/Shared/Utilities/PDFReportGenerator.swift`
- `Integration`: report PDF generation produces non-empty PDF data.
- `Integration`: comparison PDF generation includes expected title and metadata sections.
- `Manual`: generated PDFs render correctly in Quick Look and external share targets.

### `Snapshots/Shared/Utilities/InspectionBadgeStore.swift`
- `Integration`: refresh counts only `in_progress` inspections.
- `Integration`: monitoring loop starts once and stops cleanly.
- `Integration`: backend failure resets count to zero rather than leaving stale state.

### `Snapshots/Shared/Utilities/PlanUsageService.swift`
- `Integration`: owner photo usage is fetched correctly for valid owners.
- `Integration`: backend failures surface safely to callers.

### `Snapshots/Shared/Utilities/ExportFileNameBuilder.swift`
- `Unit`: file names sanitize punctuation and whitespace.
- `Unit`: empty parts are omitted.
- `Unit`: generated name ends with a timestamp and `.pdf`.

### `Snapshots/Shared/Utilities/SnapshotCache.swift`
- `Integration`: save then load round-trips Codable values successfully.
- `Integration`: stale values are not returned when `maxAge` is exceeded.
- `Integration`: remove deletes cached entries.

### `Snapshots/Shared/Utilities/PropertyDataService.swift`
- `Integration`: loads property records, rooms, and recent inspections.
- `Integration`: delete property and delete room mutate backend state correctly.
- `Integration`: active inspection count helpers return correct counts.

### `Snapshots/Shared/Utilities/Formatter.swift`
- `Unit`: inspection types format into the expected user-facing strings.
- `Unit`: ISO8601 dates parse with and without fractional seconds.
- `Unit`: invalid date input is returned untouched by `formatDate`.

### `Snapshots/Shared/Utilities/InspectionExportService.swift`
- `Integration`: inspection report export returns a generated PDF document.
- `Integration`: comparison report export returns a generated PDF document.
- `Manual`: exported file names match report type and selected inspections.

### `Snapshots/Shared/Utilities/DesignSystem.swift`
- `UI`: shared spacing, radius, color, and typography tokens render consistently across screens.
- `UI`: dynamic type and light/dark accessibility settings keep components legible.

### `Snapshots/Shared/Utilities/PrefetchService.swift`
- `Integration`: property prefetch respects the configured item limit.
- `Integration`: inspection destination prefetch respects the configured item limit.
- `Integration`: comparison prefetch orders the pair consistently and caches expected targets.

### `Snapshots/Shared/Utilities/InspectionWorkflowService.swift`
- `Integration`: complete inspection updates status and completion time.
- `Integration`: cancel inspection updates status and notes/reason.
- `Integration`: reopen inspection returns an inspection to `in_progress`.
- `Integration`: delete inspection removes it from backend storage.

### `Snapshots/Shared/Utilities/PlatformSupport.swift`
- `Unit`: platform-specific capability checks return expected values by target.
- `Manual`: device-only branches behave correctly on iPhone, iPad, and simulator.

### `Snapshots/Shared/Utilities/HapticManager.swift`
- `Manual`: success, warning, and error haptics fire on supported devices.
- `Manual`: unsupported environments degrade gracefully without crashing.

### `Snapshots/Shared/Utilities/InspectionItemService.swift`
- `Integration`: saving an inspection item writes status, notes, and image URL changes.
- `Integration`: image upload path and public URL generation are stable.
- `Integration`: deleting or replacing an image removes stale storage references safely.

### `Snapshots/Shared/Utilities/CachedAsyncImage.swift`
- `UI`: placeholder appears before remote image loads.
- `UI`: cached image renders on second load without visible flicker.
- `UI`: failed loads render fallback state instead of hanging.

### `Snapshots/Shared/Utilities/PropertyOwnerProfileLoader.swift`
- `Integration`: owner profiles enrich property records when override columns exist.
- `Integration`: fallback query path works when override columns are unavailable.
- `Integration`: access-contract loader maps inherited owner metadata correctly.

### `Snapshots/Shared/Utilities/ExportDocuments.swift`
- `Integration`: exported PDF/document wrappers present valid file URLs or data blobs.
- `Integration`: document metadata matches the report type and file name.

### `Snapshots/Shared/Utilities/InspectionDataService.swift`
- `Integration`: loads inspection hub snapshot with property, rooms, inventory, and inspection items.
- `Integration`: loads comparison snapshot with changed and unchanged items.
- `Integration`: loads inspection report snapshot with anomalies, present items, and resolved items.
- `Integration`: accessible inspections query honors property membership and ownership rules.

### `Snapshots/Shared/Utilities/ViewPlatformModifiers.swift`
- `UI`: platform-specific modifiers preserve intended layout and behavior on supported targets.
- `UI`: modifiers do not regress interactions in compact or regular size classes.

## Shared Models

### `Snapshots/Shared/Models/ProfileModel.swift`
- `Unit`: effective tier becomes `pro` when synced App Store billing is active and unexpired.
- `Unit`: expired or invalid synced subscription falls back to direct tier.
- `Unit`: `hasProFeatures` and `hasBusinessFeatures` reflect effective tier correctly.

### `Snapshots/Shared/Models/DiffItem.swift`
- `Unit`: `id` changes when comparison fields change.
- `Unit`: `id` remains stable for identical comparison values.

### `Snapshots/Shared/Models/SupabaseModels.swift`
- `Unit`: property owner display name prefers full name, then email prefix, then fallback label.
- `Unit`: owner tier resolves from owner profile subscription and billing fields.
- `Unit`: property membership roles map to edit/delete permissions correctly.
- `Unit`: Codable round-trip preserves schema-backed fields for inserts and reads.

## Notifications Feature

### `Snapshots/Features/Notifications/Views/NotificationsView.swift`
- `UI`: empty state renders when there are no notifications.
- `UI`: unread rows are visually distinct from read rows.
- `UI`: tapping a notification opens the expected destination or detail.
- `Integration`: pull-to-refresh or view refresh loads latest backend notifications.

## Team Feature

### `Snapshots/Features/Team/Views/ManageTeamSheet.swift`
- `UI`: owners and managers can see invite controls.
- `UI`: maintainers cannot see privileged team-management actions.
- `UI`: plan limit warning renders when the property tier blocks more members.
- `UI`: member list renders roles and removal affordances correctly.

### `Snapshots/Features/Team/ViewModels/ManageTeamViewModel.swift`
- `Unit`: trimmed valid email enables invite flow.
- `Unit`: invalid email disables invite flow.
- `Integration`: missing billing RPC surfaces the custom migration-needed message.
- `Integration`: pending invite response shows the pending-email success message.
- `Integration`: direct add response shows the added-member success message.
- `Integration`: removing a member refreshes the member list.
- `Integration`: leaving a property removes the current user membership.

## Properties Views

### `Snapshots/Features/Properties/Views/EditItemSheet.swift`
- `UI`: existing item values prefill correctly.
- `UI`: save button disables for blank item names.
- `Integration`: successful save dismisses and refreshes parent state.

### `Snapshots/Features/Properties/Views/AddRoomSheet.swift`
- `UI`: default room type and blank form render correctly.
- `UI`: save button disables for blank room name.
- `Integration`: successful save dismisses and refreshes room list.

### `Snapshots/Features/Properties/Views/InventoryItemDetailView.swift`
- `UI`: item metadata, history, and linked inspections render correctly.
- `UI`: empty history state is handled gracefully.
- `Integration`: refresh loads latest item detail from backend.

### `Snapshots/Features/Properties/Views/PropertyView.swift`
- `UI`: property list renders owned and shared properties.
- `UI`: add-property CTA routes to paywall or add sheet based on entitlement.
- `UI`: delete confirmation appears only when user has permission.

### `Snapshots/Features/Properties/Views/PropertyDetailView.swift`
- `UI`: property summary, room list, and recent inspections render correctly.
- `UI`: owner, manager, and maintainer controls differ as expected.
- `UI`: manage-team CTA routes to team sheet or paywall based on entitlement.

### `Snapshots/Features/Properties/Views/RoomInventoryView.swift`
- `UI`: inventory items render with quantities and edit actions.
- `UI`: empty-room inventory state prompts item creation.
- `Integration`: deleting an item updates the list without a full relaunch.

### `Snapshots/Features/Properties/Views/EditPropertySheet.swift`
- `UI`: existing property values prefill correctly.
- `UI`: validation messages render for invalid fields.
- `Integration`: successful save dismisses and refreshes property detail.

### `Snapshots/Features/Properties/Views/AddPropertySheet.swift`
- `UI`: default values render for new property creation.
- `UI`: validation blocks blank names and invalid guest/postal fields.
- `Integration`: plan-limit error appears when creation is blocked remotely.

### `Snapshots/Features/Properties/Views/AddItemSheet.swift`
- `UI`: item creation form renders expected default quantity.
- `UI`: save button disables for blank name.
- `Integration`: successful save updates parent inventory list.

### `Snapshots/Features/Properties/Views/EditRoomSheet.swift`
- `UI`: room edit form preloads existing values.
- `UI`: blank room name disables save.
- `Integration`: successful save updates visible room metadata.

## Properties ViewModels

### `Snapshots/Features/Properties/ViewModels/PropertyDetailViewModel.swift`
- `Unit`: role helpers mark owner, manager, and room-edit permissions correctly.
- `Unit`: manage-team destination resolves to paywall or team flow.
- `Integration`: cached snapshot loads before remote refresh.
- `Integration`: deleting rooms updates local state and cache.
- `Integration`: deleting property clears property detail and property list caches.

### `Snapshots/Features/Properties/ViewModels/AddItemViewModel.swift`
- `Unit`: blank name disables save.
- `Integration`: successful save inserts backend item with trimmed optional description.
- `Integration`: backend failure surfaces error message and resets saving state.

### `Snapshots/Features/Properties/ViewModels/RoomInventoryViewModel.swift`
- `Integration`: loads inventory items for a room.
- `Integration`: deleting items updates local state and cache.
- `Integration`: refresh handles backend failure cleanly.

### `Snapshots/Features/Properties/ViewModels/PropertyViewModel.swift`
- `Unit`: owned property count drives add-property availability.
- `Unit`: destination resolves to paywall or add-property sheet when access check completes.
- `Integration`: cached property list loads before remote refresh.
- `Integration`: deleting properties updates in-memory and cached state.

### `Snapshots/Features/Properties/ViewModels/EditItemViewModel.swift`
- `Unit`: initializes editable state from the supplied item.
- `Unit`: blank name disables save.
- `Integration`: successful save updates backend values including nullable description.

### `Snapshots/Features/Properties/ViewModels/EditPropertyViewModel.swift`
- `Unit`: validates required name, guest count, and postal code rules.
- `Unit`: save disables while loading or saving.
- `Integration`: fetch populates editable fields from backend JSON response.
- `Integration`: save sends null for blank optional fields.

### `Snapshots/Features/Properties/ViewModels/EditRoomViewModel.swift`
- `Unit`: initializes editable state from the supplied room.
- `Unit`: blank name disables save.
- `Integration`: save updates room metadata and optional description correctly.

### `Snapshots/Features/Properties/ViewModels/InventoryItemDetailViewModel.swift`
- `Integration`: loads linked inspection records for an inventory item.
- `Integration`: handles missing item detail gracefully.
- `Integration`: refresh path clears previous error state.

### `Snapshots/Features/Properties/ViewModels/AddPropertyViewModel.swift`
- `Unit`: validates required and length-bounded fields.
- `Integration`: missing billing RPC surfaces the migration-needed error.
- `Integration`: plan-limit response blocks creation with the correct message.
- `Integration`: save sends trimmed optional values and resets saving state.

### `Snapshots/Features/Properties/ViewModels/AddRoomViewModel.swift`
- `Unit`: blank name disables save.
- `Integration`: save inserts room with optional description and type.
- `Integration`: backend failure surfaces error message and resets saving state.

## Inspections Views

### `Snapshots/Features/Inspections/Views/InspectionItemDetailView.swift`
- `UI`: item status controls render for present, missing, damaged, and resolved.
- `UI`: photo-limit helper text appears when the user cannot attach more photos.
- `UI`: existing notes and image preview render correctly.
- `Integration`: save flow updates parent inspection state after success.

### `Snapshots/Features/Inspections/Views/ImageAnnotationView.swift`
- `UI`: annotation canvas loads selected image.
- `UI`: drawing, clearing, and saving interactions behave correctly.
- `Manual`: annotated image export quality is acceptable on device.

### `Snapshots/Features/Inspections/Views/CompareSelectSheet.swift`
- `UI`: candidate inspections list renders type and completion date.
- `UI`: selecting a comparison target enables navigation to comparison report.
- `UI`: empty comparison state is handled gracefully.

### `Snapshots/Features/Inspections/Views/StartInspectionSheet.swift`
- `UI`: property picker and inspection type picker render correctly.
- `UI`: duplicate warning appears for same-day move-in and move-out conflicts.
- `UI`: join-existing flow appears when an active inspection already exists.

### `Snapshots/Features/Inspections/Views/InspectionHubView.swift`
- `UI`: room progress list renders counts and completion state.
- `UI`: complete action is disabled when rooms are incomplete or empty.
- `UI`: realtime fallback messaging appears when live updates are unavailable.

### `Snapshots/Features/Inspections/Views/InspectionPDFView.swift`
- `UI`: PDF preview renders property, inspection metadata, and grouped findings.
- `UI`: export button shows loading state during PDF generation.
- `Manual`: preview matches generated PDF content.

### `Snapshots/Features/Inspections/Views/ComparisonReportView.swift`
- `UI`: previous/current inspection headers render in the correct order.
- `UI`: changed and unchanged sections display expected diff rows.
- `Integration`: export action triggers comparison PDF generation.

### `Snapshots/Features/Inspections/Views/InspectionsView.swift`
- `UI`: date filter updates visible inspections.
- `UI`: active inspections show active styling and actions.
- `UI`: completed inspections show anomaly and resolved counts correctly.

### `Snapshots/Features/Inspections/Views/InspectionReportView.swift`
- `UI`: anomalies, resolved items, and present items render in separate sections.
- `UI`: resolving an anomaly updates the visible sections optimistically.
- `Integration`: export action triggers inspection PDF generation.

## Inspections ViewModels

### `Snapshots/Features/Inspections/ViewModels/InspectionHubViewModel.swift`
- `Unit`: room progress and overall completion state are calculated correctly.
- `Integration`: cached snapshot loads before remote refresh.
- `Integration`: realtime updates patch or append inspection items correctly.
- `Integration`: polling fallback starts when realtime subscription fails.
- `Integration`: deleting inspection clears related cache entries.

### `Snapshots/Features/Inspections/ViewModels/StartInspectionViewModel.swift`
- `Unit`: preloaded properties skip initial loading.
- `Integration`: active inspection lookup returns the current in-progress inspection.
- `Integration`: duplicate same-day move-in/move-out detection works.
- `Integration`: duplicate-key backend errors map to user-friendly copy.
- `Integration`: successful create returns new inspection ID.

### `Snapshots/Features/Inspections/ViewModels/ComparisonReportViewModel.swift`
- `Unit`: older/newer inspections are ordered chronologically.
- `Integration`: cached comparison snapshot loads before remote refresh.
- `Integration`: refresh saves new comparison snapshot into cache.
- `Integration`: PDF generation toggles loading state and returns export payload.

### `Snapshots/Features/Inspections/ViewModels/InspectionItemDetailViewModel.swift`
- `Integration`: save updates status, notes, and image URL for an inspection item.
- `Integration`: image replacement preserves or deletes storage objects correctly.
- `Integration`: photo-limit failures surface user-facing error state.
- `Integration`: refresh reloads latest backend item state.

### `Snapshots/Features/Inspections/ViewModels/RoomInspectionViewModel.swift`
- `Integration`: loads all inventory items and existing inspection records for a room.
- `Integration`: per-item completion and navigation state update correctly after saves.
- `Integration`: empty room state is handled without blocking parent inspection flow.

### `Snapshots/Features/Inspections/ViewModels/InspectionReportViewModel.swift`
- `Integration`: cached report snapshot loads before refresh.
- `Integration`: refresh separates anomalies, present items, and resolved items correctly.
- `Integration`: resolving anomaly applies optimistic UI update and persists to backend.
- `Integration`: failed resolution rolls back optimistic state and shows error.
- `Integration`: PDF generation toggles loading state and returns export payload.

### `Snapshots/Features/Inspections/ViewModels/InspectionsViewModel.swift`
- `Unit`: date filtering uses `started_at` for active inspections and `completed_at` otherwise.
- `Unit`: resetting filter returns selected day to today.
- `Integration`: refresh calculates anomaly and resolved counts from inspection items.
- `Integration`: cancel, reopen, and delete mutate local state and cache correctly.
- `Integration`: cached inspections, properties, and counts load before remote refresh.

## Auth Views

### `Snapshots/Features/Auth/Views/LoginView.swift`
- `UI`: invalid email blocks sign-in submission.
- `UI`: valid email enables sign-in CTA.
- `Integration`: submitting email triggers auth request and loading state.
- `UI`: error state is visible when sign-in fails.

### `Snapshots/Features/Auth/Views/CheckInboxView.swift`
- `UI`: email address is interpolated into the success message.
- `UI`: resend/back navigation actions are available as expected.

### `Snapshots/Features/Auth/Views/CompleteProfileView.swift`
- `UI`: required fields validate before completion.
- `Integration`: successful save completes onboarding and routes to main app.
- `UI`: error state is shown when profile save fails.

### `Snapshots/Features/Auth/Views/PremiumPaywallView.swift`
- `UI`: product cards render localized monthly and yearly pricing.
- `UI`: purchase buttons show loading state during transaction.
- `Integration`: purchase success unlocks entitled UI.
- `Integration`: restore purchases refreshes entitlement state.
- `Manual`: StoreKit test configuration covers upgrade, restore, cancel, and expiration.

## Feedback Feature

### `Snapshots/Features/Feedback/Views/FeedbackSheet.swift`
- `UI`: category picker, message field, and submit CTA render correctly.
- `UI`: submit CTA disables for short messages.
- `Integration`: successful submit resets form and shows success state.

### `Snapshots/Features/Feedback/ViewModels/FeedbackViewModel.swift`
- `Unit`: trimmed message drives submission eligibility.
- `Unit`: category raw values and labels remain stable.
- `Integration`: successful submission sends expected metadata fields and clears message.
- `Integration`: server-side error payload surfaces correctly.

## Settings Feature

### `Snapshots/Features/Settings/Views/EditProfileView.swift`
- `UI`: existing profile values prefill correctly.
- `UI`: optional branding fields handle blank values correctly.
- `Integration`: successful save updates profile and dismisses editor.

### `Snapshots/Features/Settings/Views/SettingsView.swift`
- `UI`: settings sections render current account, billing, and legal options.
- `UI`: sign-out action shows confirmation and returns to auth flow.
- `UI`: navigation to edit profile, feedback, and legal links works.

## Supabase Edge Functions

### `supabase/functions/forward-supabase-errors/index.ts`
- `Integration`: forwards expected error payload fields to the configured destination.
- `Integration`: malformed payload is rejected safely.
- `Integration`: sensitive values are redacted from forwarded output.

### `supabase/functions/send-property-invite/index.ts`
- `Integration`: existing user is added directly when allowed.
- `Integration`: unknown email produces a pending invite response.
- `Integration`: invalid role or unauthorized caller is rejected.

### `supabase/functions/push-notifications/index.ts`
- `Integration`: valid device tokens receive outbound push payloads.
- `Integration`: invalid tokens are skipped or logged without aborting the full batch.
- `Manual`: live APNs payload opens the correct in-app destination.

### `supabase/functions/sync-storekit-subscription/index.ts`
- `Integration`: valid transaction updates subscription status and tier.
- `Integration`: expired or invalid transaction downgrades or rejects appropriately.
- `Integration`: original transaction ID fallback path works when current transaction is absent.

### `supabase/functions/send-feedback/index.ts`
- `Integration`: authenticated feedback payload is accepted and forwarded.
- `Integration`: malformed payload is rejected with a useful error.
- `Integration`: category label and metadata fields are preserved in forwarded output.

### `supabase/functions/app-store-server-notifications/index.ts`
- `Integration`: renewal, expiration, refund, and cancellation notifications update backend state correctly.
- `Integration`: malformed or unsigned notifications are rejected.
- `Integration`: duplicate notifications are idempotent and do not double-apply subscription state.

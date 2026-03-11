# Team Collaboration and Notifications

## Why this feature exists

Snapshots is not only a solo inspection tool. It supports team workflows where owners, managers, and collaborators operate on the same property, often with inherited premium access. Notifications close the loop by drawing users back into shared work.

## Main files

- [`Snapshots/Views/Team/ManageTeamSheet.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Team/ManageTeamSheet.swift)
- [`Snapshots/ViewModels/ManageTeamViewModel.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/ViewModels/ManageTeamViewModel.swift)
- [`Snapshots/Views/Team/StartInspectionSheet.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Team/StartInspectionSheet.swift)
- [`Snapshots/Core/NotificationManager.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Core/NotificationManager.swift)
- [`Snapshots/Views/Notifications/NotificationsView.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Notifications/NotificationsView.swift)
- [`Snapshots/Views/Components/NotificationBellView.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Components/NotificationBellView.swift)
- [`supabase/functions/push-notifications/index.ts`](/Users/uabylbekov/Projects/snapshots/supabase/functions/push-notifications/index.ts)

## Team access model

A property can have members with roles. The UI distinguishes owners and managers when deciding whether to show room-management and team-management controls.

Important rule:

- premium access may be inherited from the property owner’s tier, but billing identity still belongs to the purchasing owner

This distinction shows up in team management, branding, and paywall behavior.

## Manage team behavior

Team management is launched from the property detail screen.

- If the current property context is Pro or Enterprise, the sheet opens.
- If not, the user is redirected to the paywall.

The gating is property-aware, not purely user-aware. A manager inside a premium property can receive premium collaboration capability without personally subscribing.

## Notification lifecycle

`NotificationManager` owns the full client-side notification pipeline:

- requests permission once per app lifecycle
- registers for remote notifications
- stores the current APNs token
- upserts token rows into `user_push_tokens`
- fetches notification rows from Supabase
- subscribes to `notifications` realtime updates
- updates unread count and badge count
- unregisters the device token on sign-out

## In-app and device notification split

There are two delivery mechanisms:

- realtime updates refresh the in-app notification list immediately
- the `push-notifications` Edge Function sends APNs alerts for device-level delivery

This is why a notification bug may be caused by:

- client subscription issues
- APNs token registration issues
- Edge Function configuration issues
- unread badge count logic

## Deep linking behavior

Notifications can carry an inspection identifier. When the user taps a delivered notification, the app stores the selected notification id and can load the corresponding inspection through `handleJoinRequest`.

This is a key tester scenario because it crosses:

- app lifecycle state
- local notification handling
- Supabase fetch
- navigation into the inspection hub

## Badge count behavior

Badge counts are based on unread notifications, not total notifications. The push Edge Function also calculates unread count from the database after insert so the APNs payload badge stays aligned with server state.

## Tester checklist

- Invite or manage a teammate on a premium property.
- Confirm collaboration controls are available where expected.
- Confirm collaboration controls are blocked on free properties.
- Receive a notification while the app is foregrounded.
- Receive a notification while the app is backgrounded.
- Tap a notification and confirm the app navigates correctly.
- Mark one notification as read and verify unread count decreases.
- Mark all notifications as read and verify the badge clears.
- Delete notifications and verify the list stays consistent after refresh.
- Sign out and confirm stale badge state does not linger.

## Edge cases to watch

- Device token changes after reinstall or OS-level reset.
- Notification row exists in Supabase but APNs delivery fails.
- Realtime inserts duplicate an item that later gets refetched.
- User signs out before token unregister completes.
- Team member inherits access on one property but not another.

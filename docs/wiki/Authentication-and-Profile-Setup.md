# Authentication and Profile Setup

## Why this feature exists

Authentication establishes the user session, while profile completion determines whether the user can enter the main product. The app treats these as separate checkpoints:

- session exists
- profile has the minimum required data to operate

## Main files

- [`Snapshots/Core/RootView.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Core/RootView.swift)
- [`Snapshots/Core/AuthManager.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Core/AuthManager.swift)
- [`Snapshots/Views/Auth/LoginView.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Auth/LoginView.swift)
- [`Snapshots/Views/Auth/CheckInboxView.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Auth/CheckInboxView.swift)
- [`Snapshots/Views/Auth/CompleteProfileView.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Auth/CompleteProfileView.swift)
- [`Snapshots/Views/Tabs/EditProfileView.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Tabs/EditProfileView.swift)

## Runtime behavior

On launch, `AuthManager` attempts to load `supabase.auth.session`.

- If a session exists:
  - `isAuthenticated` becomes true.
  - `checkProfileCompletion` inspects `session.user.userMetadata["full_name"]`.
  - `SnapshotsAccessManager` refreshes entitlements.
- If no session exists:
  - the user is routed to `LoginView`
  - cached entitlements are cleared

The current definition of a complete profile is simple: the authenticated user must have a non-empty `full_name` in Supabase user metadata.

## Important developer implications

- A user can be authenticated but still blocked from the main app if the profile is incomplete.
- Profile completion currently depends on auth metadata, not only the `profiles` table.
- Sign-out should be treated as a cleanup workflow, not only an auth state change, because device token cleanup is also triggered.

## Edit profile capabilities

`EditProfileView` mixes basic identity editing with premium branding settings.

All users can edit:

- full name
- email address

Pro and Business users can additionally manage:

- company logo

Business users can additionally manage:

- business name
- business address
- business phone
- business website

These fields are used later by the reporting and branding system.

## Logo upload behavior

Logo uploads are stored in the `company-logos` bucket under a user-specific path. The client appends a timestamp query parameter to the generated public URL to defeat stale cache behavior after re-upload.

That means testers should verify both:

- first-time upload works
- replacing an existing logo visibly updates in the app and in generated reports

## Account deletion

The edit profile flow exposes account deletion while in edit mode. This is a high-risk area because it can affect auth records, profile state, and downstream ownership assumptions. Any changes here should be tested with properties, inspections, and team memberships already present.

## Tester checklist

- Sign in with a new user and confirm the app routes to profile completion.
- Complete the profile and confirm the app routes into the main tabs.
- Sign out and confirm the app returns to login cleanly.
- Edit name and email and confirm the updated values appear in settings.
- On a Pro or Business account, upload a logo and confirm it persists.
- On a free account, confirm business-branding upsell content is shown instead of logo/business settings.

## Edge cases to watch

- Session exists but user metadata is missing `full_name`.
- Email update succeeds but local UI still shows stale values until refresh.
- Sign-out occurs while notification token registration is in flight.
- A profile has premium data in the database but the current user does not have direct premium billing access.

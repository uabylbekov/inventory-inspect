# Subscriptions, Entitlements, and Branding

## Why this feature exists

Snapshots is monetized as a tiered product, but the entitlement rules are more complex than simple direct billing. This page is critical for onboarding because many UI decisions only make sense once you understand the difference between direct subscriptions and property-level inherited access.

If you are junior or new to billing systems, use this simple mental model:

- the app checks "what plan does this person have for themselves?"
- the app also checks "what plan does the property owner have?"
- then it decides what the user can do in this exact property

## Main files

- [`Snapshots/Core/SnapshotsAccessManager.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Core/SnapshotsAccessManager.swift)
- [`Snapshots/Views/Auth/PremiumPaywallView.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Auth/PremiumPaywallView.swift)
- [`Snapshots/Views/Components/SubscriptionPlanViews.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Components/SubscriptionPlanViews.swift)
- [`Snapshots/Views/Tabs/EditProfileView.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Tabs/EditProfileView.swift)
- [`Docs/payment_technical_docs.md`](/Users/uabylbekov/Projects/snapshots/Docs/payment_technical_docs.md)
- [`Docs/payment_testing_guide.md`](/Users/uabylbekov/Projects/snapshots/Docs/payment_testing_guide.md)

## Tier model

- Free
- Pro
- Business
- Lifetime override through Supabase profile data

Free supports the base workflow. Pro unlocks expanded property counts, team usage, photos, and branding upgrades. Business unlocks white-label reporting and larger manually managed account limits.

### Plain-English limits

These are the default limits in the app code right now:

- Free: 1 owned property, 0 extra team members, 150 saved photos
- Pro: 10 owned properties, 3 team members, 10,000 saved photos
- Business: 50 owned properties, 20 team members, 50,000 saved photos

Important:

- these are defaults, not hard forever rules
- Supabase can override them per user with limit override columns in `profiles`

## Sources of entitlement truth

`SnapshotsAccessManager` combines two sources:

- Supabase profile fields
- StoreKit 2 transactions

The rule is effectively highest-tier-wins.

That means:

- if StoreKit says Pro and Supabase says free, the user still gets Pro
- if Supabase says Business, Business wins even if StoreKit only shows Pro
- if Supabase says Lifetime, that behaves like permanent top-tier access

### Supabase profile fields

The profile can grant:

- `pro`
- `business`
- `lifetime`

These values are useful for internal testers, VIPs, and manually managed business accounts.

### StoreKit 2

The app checks verified current entitlements for:

- `com.ulukskywalker.snapshots.pro.monthly`
- `com.ulukskywalker.snapshots.pro.yearly`

The app also sends the App Store transaction id to the `sync-storekit-subscription` Supabase Edge Function so the backend can stay in sync with the device.

## Direct access versus inherited access

This distinction is the most important onboarding concept in the monetization model.

Direct access means:

- the current user purchased or was directly granted the tier

Inherited access means:

- the current user is operating on a property whose owner has the tier

Inherited access affects property-specific capabilities such as:

- team management
- inspection photo evidence
- report branding based on the owner’s company identity

Inherited access should not automatically make the user appear to be the paying account in settings or profile plan badges.

### Easy example

Example 1:

- Alice pays for Pro
- Bob is only a free user
- Bob is added to Alice's property as a manager
- Bob gets Pro-like behavior inside Alice's property
- Bob should still not look like the billing owner in Settings

Example 2:

- Bob leaves Alice's property
- Bob loses that inherited Pro behavior
- Bob goes back to whatever his own direct access is

## Where gating happens

Examples of access checks:

- `canAddProperty(ownedCount:)`
- `canAddTeamMember(for:currentMemberCount:)`
- `isPro(for: property)`
- `isBusiness(for: property)`

This means developers should not replace property-aware gating with global user-tier checks without carefully reviewing the business model first.

### Junior-safe rule

When you touch subscription checks, ask:

1. is this about the user personally?
2. or is this about the current property owner?

If you use the wrong one, billing and permissions will look wrong.

## Branding behavior

Branding depends on tier:

- Free: limited or Snapshots-branded output
- Pro: company logo support
- Business: fuller business details and white-label style output

Branding data originates in the profile editing flow and is later consumed by the report and PDF generation layer.

Another simple rule:

- the branding on a report should come from the property owner context
- not automatically from whichever teammate pressed the export button

## Testing guidance

Use the dedicated payment guide in [`Docs/payment_testing_guide.md`](/Users/uabylbekov/Projects/snapshots/Docs/payment_testing_guide.md) for StoreKit and sandbox validation.

In addition, QA should explicitly validate:

- free user on own property
- direct Pro user on own property
- direct Business user on own property
- free manager inside a Pro property
- free manager inside a Business property
- lifetime override behavior from Supabase

Also verify against the correct backend branch:

- `Prod.xcconfig` -> Supabase `main`
- `Test.xcconfig` -> Supabase `test`

## Tester checklist

- Confirm free users are limited to one owned property.
- Confirm Pro users can create additional properties up to the documented limit.
- Confirm Business users can exceed Pro limits.
- Confirm a manager inside a premium property gets the premium behavior relevant to that property.
- Confirm settings plan badges reflect direct billing state rather than inherited property access.
- Confirm profile branding fields appear only on the correct tiers.
- Confirm exported PDFs reflect the expected branding tier.
- Confirm restore or entitlement refresh updates UI state without app restart where possible.

## Common mistakes juniors make here

- confusing direct paid access with inherited property access
- counting managed properties against the owned-property limit
- showing a Pro or Business badge in Settings for a user who only has inherited access
- testing purchases on the wrong backend branch
- forgetting that Supabase overrides can beat StoreKit

## Edge cases to watch

- StoreKit says free but Supabase profile says business.
- User loses direct subscription but still manages a premium property owned by another user.
- Sandbox environment accidentally masks a production gating bug.
- Branding fields exist in the profile but the account no longer has the tier that unlocked them.

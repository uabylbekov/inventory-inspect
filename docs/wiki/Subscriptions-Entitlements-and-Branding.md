# Subscriptions, Entitlements, and Branding

## Why this feature exists

Snapshots is monetized as a tiered product, but the entitlement rules are more complex than simple direct billing. This page is critical for onboarding because many UI decisions only make sense once you understand the difference between direct subscriptions and property-level inherited access.

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

## Sources of entitlement truth

`SnapshotsAccessManager` combines two sources:

- Supabase profile fields
- StoreKit 2 transactions

The rule is effectively highest-tier-wins.

### Supabase profile fields

The profile can grant:

- `pro`
- `business`
- `lifetime`

These values are useful for internal testers, VIPs, and manually managed business accounts.

### StoreKit 2

The app checks verified current entitlements for:

- `com.ulukskywalker.snapshots.pro.monthly`

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

## Where gating happens

Examples of access checks:

- `canAddProperty(ownedCount:)`
- `canAddTeamMember(for:currentMemberCount:)`
- `isPro(for: property)`
- `isBusiness(for: property)`

This means developers should not replace property-aware gating with global user-tier checks without carefully reviewing the business model first.

## Branding behavior

Branding depends on tier:

- Free: limited or Snapshots-branded output
- Pro: company logo support
- Business: fuller business details and white-label style output

Branding data originates in the profile editing flow and is later consumed by the report and PDF generation layer.

## Testing guidance

Use the dedicated payment guide in [`Docs/payment_testing_guide.md`](/Users/uabylbekov/Projects/snapshots/Docs/payment_testing_guide.md) for StoreKit and sandbox validation.

In addition, QA should explicitly validate:

- free user on own property
- direct Pro user on own property
- direct Business user on own property
- free manager inside a Pro property
- free manager inside a Business property
- lifetime override behavior from Supabase

## Tester checklist

- Confirm free users are limited to one owned property.
- Confirm Pro users can create additional properties up to the documented limit.
- Confirm Business users can exceed Pro limits.
- Confirm a manager inside a premium property gets the premium behavior relevant to that property.
- Confirm settings plan badges reflect direct billing state rather than inherited property access.
- Confirm profile branding fields appear only on the correct tiers.
- Confirm exported PDFs reflect the expected branding tier.
- Confirm restore or entitlement refresh updates UI state without app restart where possible.

## Edge cases to watch

- StoreKit says free but Supabase profile says business.
- User loses direct subscription but still manages a premium property owned by another user.
- Sandbox environment accidentally masks a production gating bug.
- Branding fields exist in the profile but the account no longer has the tier that unlocked them.

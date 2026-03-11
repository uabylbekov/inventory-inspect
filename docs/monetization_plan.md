# Snapshots Monetization & Access Implementation Plan

This document outlines the architecture and implementation steps for transitioning **Snapshots** into a professional B2B SaaS application with tiered access.

## 1. Core Entitlement Logic (The "Triple Check")
We will implement an `AccessManager` that grants "Pro" status if **ANY** of these conditions are met:
1.  **VIP Status**: The user's Supabase profile has `subscription_tier = 'lifetime'`.
2.  **TestFlight**: The app detects it is running in the Apple Sandbox environment.
3.  **Paid Subscription**: A valid StoreKit 2 transaction is found (Product IDs: `com.ulukskywalker.snapshots.pro.monthly`, `com.ulukskywalker.snapshots.pro.yearly`).

## 2. Database Schema Updates (Supabase)
We need to modify the `profiles` table to store entitlement data that persists across devices.

```sql
-- Add subscription fields to profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS subscription_tier TEXT DEFAULT 'free', -- 'free', 'pro', 'lifetime'
ADD COLUMN IF NOT EXISTS company_logo_url TEXT,
ADD COLUMN IF NOT EXISTS business_details TEXT;
```

## 3. Tiered Feature Gating

| Feature | Gate Mechanism | UI Implementation |
| :--- | :--- | :--- |
| **Properties** | count > limit | Free: 1, Pro: 10, Business: custom. |
| **Team Management** | `!isPro` | Show Lock icon on "Manage Team"; Redirect to `PaywallSheet`. |
| **Custom Branding** | `!isPro` | Show "Add Logo" placeholder with "Pro" label. |

## 4. Implementation Phases

### Phase 1: Access Manager & Environment Detection
*   Create `SnapshotsAccessManager.swift` using `@Observable`.
*   Implement `checkTestFlight()` using `sandboxReceipt` detection.
*   Integrate profile fetching to read `subscription_tier` from Supabase.

### Phase 2: Property & Team Gating
*   Update `InspectionsViewModel` to check current property count before allowing creation.
*   Add a `.sheet` to the property list to display the `PaywallView` when limits are hit.
*   Update `PropertyDetailView` to gate the "Manage Team" navigation link.

### Phase 3: Premium UI & StoreKit
*   Design the `PremiumPaywallView` with a professional B2B aesthetic (Midnight theme).
*   Implement StoreKit 2 fetching for localized pricing.
*   Add the "Custom Logo" upload field in Property Settings (Gated).

### Phase 4: Testing & VIP Whitelisting
*   Verify that TestFlight users automatically see the app as "Pro."
*   Provide a manual override in the database to grant a specific email "Lifetime" access for testing.

## 5. Pricing Strategy (Apple Storefront Localization)
*   **Tier 1 (US/Europe)**: $49.99/mo (Professional Property Manager).
*   **Tier 2 (Emerging Markets)**: Use Apple’s automated localized tiers (approx. $9.99 - $14.99 equivalent).

---

> [!IMPORTANT]
> **Safety First**: All photo resolutions will remain high-quality for all users. We will NEVER downscale evidence, as it compromises the core B2B value of "Legal Protection."

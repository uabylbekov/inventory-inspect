# Snapshots Payment & Entitlement Technical Documentation

## 1. Overview
The Snapshots monetization system is a hybrid entitlement engine that combines **StoreKit 2** (for App Store purchases) with **Supabase** (for VIP/Lifetime overrides and cross-device sync).

## 2. Subscription Tiers (B2B SaaS Model)

| Tier | Property Limit | Team Limit | Features |
| :--- | :--- | :--- | :--- |
| **Standard (Free)** | 1 Property | Single User | Basic PDF Reports |
| **Professional** | 10 Properties | 5 Managers | Custom PDF Branding |
| **Enterprise** | Unlimited | Unlimited | Full White-label + Admin Tools |

## 3. Entitlement Logic (`SnapshotsAccessManager`)
The system follows a "Highest Tier Wins" logic. Access is granted if ANY of the following sources verify the status:

### A. Environment Check (TestFlight/Sandbox)
*   **Simulator**: Returns `isPro = true` and `isEnterprise = true` automatically.
*   **Sandbox/TestFlight**: If the `appStoreReceiptURL` contains `sandboxReceipt`, the user is granted full access for testing purposes.

### B. Database Check (Supabase `profiles`)
The profiles table stores a `subscription_tier` string:
*   `'pro'`: Grants Professional features.
*   `'enterprise'`: Grants all features.
*   `'lifetime'`: Permanent Enterprise access (used for VIPs/Testers).

### C. StoreKit 2 Check (Verified Transactions)
The app listens to `Transaction.currentEntitlements`. 
*   Uses `com.ulukskywalker.snapshots.pro` and `com.ulukskywalker.snapshots.enterprise`.
*   Entitlements are verified using `.verified(transaction)` to ensure against receipt tampering.

## 4. Implementation Details

### Database Schema (Supabase)
```sql
-- Profiles table structure
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS subscription_tier TEXT DEFAULT 'free', 
ADD COLUMN IF NOT EXISTS company_logo_url TEXT,
ADD COLUMN IF NOT EXISTS business_details JSONB; -- Stores address, phone etc.
```

### Visual Gating (SwiftUI)
*   **Gating Check**: Uses `accessManager.canAddProperty(currentCount:)`.
*   **UI Trigger**: If the check fails, the app presents the `PremiumPaywallView` sheet.
*   **Feature Labels**: Buttons for locked features (e.g., Manage Team) display a "PRO" or "ENTERPRISE" badge.

## 5. Security & Persistence
1.  **JWT Verification**: Supabase RLS (Row Level Security) ensures only the user can see their own subscription level.
2.  **App Store Sync**: Tapping "Restore Purchases" triggers a re-sync of the StoreKit entitlement queue and updates the local user state.
3.  **Real-time Updates**: The `SnapshotsAccessManager` is an `@Observable` object, ensuring the UI reacts instantly when a purchase is completed.

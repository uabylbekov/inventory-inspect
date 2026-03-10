# Snapshots Payment & Entitlement Technical Documentation

## 1. Overview
The Snapshots monetization system is a hybrid entitlement engine that combines **StoreKit 2** (for App Store purchases) with **Supabase** (for VIP/Lifetime overrides and cross-device sync).

## 2. Subscription Tiers (B2B SaaS Model)

| Tier | Property Limit | Team Limit | Features |
| :--- | :--- | :--- | :--- |
| **Standard (Free)** | 1 Property | Single User | Text-only Inspections, Snapshots-branded PDF |
| **Professional** | 10 Properties | 5 Managers | Photo Attachments, Custom Company Logo on PDF |
| **Enterprise** | Unlimited | Unlimited | Full White-label PDF (no Snapshots branding) |

## 3. Entitlement Logic (`SnapshotsAccessManager`)
The system follows a "Highest Tier Wins" logic. Access is granted if ANY of the following sources verify the status:

### A. Environment Check (TestFlight/Sandbox)
*   **Simulator**: Returns `isPro = true` and `isEnterprise = true` automatically.
*   **Sandbox/TestFlight**: Uses `AppTransaction.shared` (StoreKit 2) to check if the environment is `.xcode` or `.sandbox`. The result is cached at startup. All sandbox users are granted full access for testing purposes.

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
ADD COLUMN IF NOT EXISTS business_details TEXT; -- Stored as a plain string in ProfileModel
```

### Visual Gating (SwiftUI)
*   **Property Gating**: `accessManager.canAddProperty(currentCount:)` — Free: 1, Pro: 10, Enterprise: unlimited.
*   **Team Member Gating**: `accessManager.canAddTeamMember(currentManagerCount:)` — Free: not allowed, Pro: 5 managers, Enterprise: unlimited.
*   **UI Trigger**: If a check fails, the app presents the `PremiumPaywallView` sheet.
*   **Feature Labels**: Buttons for locked features display a "PRO" or "ENTERPRISE" badge.

## 5. Security & Persistence
1.  **JWT Verification**: Supabase RLS (Row Level Security) ensures only the user can see their own subscription level.
2.  **App Store Sync**: Tapping "Restore Purchases" triggers a re-sync of the StoreKit entitlement queue and updates the local user state.
3.  **Real-time Updates**: The `SnapshotsAccessManager` is an `@Observable` object, ensuring the UI reacts instantly when a purchase is completed.

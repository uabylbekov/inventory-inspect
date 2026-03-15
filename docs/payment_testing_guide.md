# Testing Snapshots Payments & Entitlements

This guide is written in simple language on purpose.

If you are not comfortable with App Store billing yet, follow the steps in order and do not skip the "which backend am I on?" check.

## 0. First check: which backend are you using?

- `Prod.xcconfig` means the app is talking to Supabase `main`
- `Test.xcconfig` means the app is talking to Supabase `test`

Why you care:

- if a purchase looks wrong, the problem might be the backend branch and not the app
- if you cannot say which backend branch you tested, the result is not trustworthy

## 1. Local Development Testing (StoreKit Testing)
Snapshots uses **StoreKit 2**. For local testing in the Simulator or on a physical device during development, follow these steps:

### A. StoreKit Configuration File
1.  In Xcode, go to `File > New > File...` and select **StoreKit Configuration File**.
2.  Save it as `Snapshots.storekit` in the `Snapshots/` folder.
3.  Add the following **Auto-Renewable Subscriptions**:
    *   **Group**: `Snapshots Plans`
    *   **Product ID**: `dev.ukulabs.snapshots.pro.monthly`
    *   **Product ID**: `dev.ukulabs.snapshots.pro.yearly`

### B. Enable the Configuration
1.  In Xcode, click on the **Snapshots** scheme (near the Play button).
2.  Select **Edit Scheme...**
3.  Go to **Run > Options**.
4.  Change **StoreKit Configuration** from "None" to `Snapshots.storekit`.

### C. Local Testing Logic
*   **Manual Trigger**: To test the actual selection UI and purchase flow in the Simulator, ensure you are using the `Snapshots.storekit` file, which will simulate a real App Store transaction without charging you.

### D. What you should expect locally

When local StoreKit testing works:

- you can open the paywall
- you can simulate buying Pro
- the app should refresh access without needing a full reinstall
- if backend sync succeeds, the profile row should reflect the synced App Store state

## 2. TestFlight & Sandbox Testing
TestFlight uses the **App Store Sandbox** environment.

### A. Verification Flow
1.  Upload a build to **App Store Connect**.
2.  Invite your internal/external testers via **TestFlight**.
3.  If they encounter a paywall (e.g., during a fresh database install), the "Purchase" button will show a Sandbox confirmation dialog. **No actual charges will be made.**

### Common TestFlight confusion

- Sandbox dialogs are expected
- no real money should be charged in Sandbox
- if the app says restore/sync failed, check the backend branch and Edge Function logs before assuming StoreKit is broken


## 3. Database Overrides (VIP Access)
To manually grant a user permanent access regardless of their App Store status:
1.  Go to the **Supabase Dashboard**.
2.  Open the `profiles` table.
3.  Locate the user's row and set their `subscription_tier` to:
    *   `'pro'`: For Professional features.
    *   `'business'`: For white-label and manually managed business access.
    *   `'lifetime'`: Permanent business access.

Plain English:

- this is the fastest way to test higher tiers without making a purchase
- use it for QA users, internal testers, or manually managed business accounts
- remember that a database override can make the app look "paid" even if StoreKit is currently free

---

## 4. Resetting Test Purchases
If you need to test the purchase flow multiple times:
1.  **Local**: In the Xcode debug bar, click the **StoreKit** icon and select "Manage Transactions" to delete previous test purchases.
2.  **Sandbox**: Go to `Settings > App Store > Sandbox Account` on your iPhone to manage or clear your test subscriptions.

## 5. Minimum payment smoke test

If you only have a few minutes, do this:

1. Confirm which backend branch you launched.
2. Open the paywall.
3. Buy Pro using local StoreKit or Sandbox.
4. Confirm property/team/photo limits update.
5. Close and reopen the app.
6. Confirm access is still correct.
7. Test "Restore Purchases".
8. If using a team property, verify inherited access still behaves correctly.

## 6. Important warning

Do not mix these up:

- direct subscription: the user personally paid or was directly granted access
- inherited access: the property owner paid, and the teammate gets premium behavior only in that property

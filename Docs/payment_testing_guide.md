# Testing Snapshots Payments & Entitlements

## 1. Local Development Testing (StoreKit Testing)
Snapshots uses **StoreKit 2**. For local testing in the Simulator or on a physical device during development, follow these steps:

### A. StoreKit Configuration File
1.  In Xcode, go to `File > New > File...` and select **StoreKit Configuration File**.
2.  Save it as `Snapshots.storekit` in the `Snapshots/` folder.
3.  Add the following **Auto-Renewable Subscriptions**:
    *   **Group**: `Snapshots Plans`
    *   **Product ID**: `com.ulukskywalker.snapshots.pro` ($49.99/mo)
    *   **Product ID**: `com.ulukskywalker.snapshots.enterprise` ($199.99/mo)

### B. Enable the Configuration
1.  In Xcode, click on the **Snapshots** scheme (near the Play button).
2.  Select **Edit Scheme...**
3.  Go to **Run > Options**.
4.  Change **StoreKit Configuration** from "None" to `Snapshots.storekit`.

### C. Local Testing Logic
*   **Simulator Bypass**: Our `SnapshotsAccessManager` detects the iOS Simulator and grants **Pro** and **Enterprise** access automatically to avoid blocking functional testing of premium features.
*   **Manual Trigger**: To test the actual selection UI and purchase flow in the Simulator, ensure you are using the `Snapshots.storekit` file, which will simulate a real App Store transaction without charging you.

## 2. TestFlight & Sandbox Testing
TestFlight uses the **App Store Sandbox** environment.

### A. Environment Detection
The app automatically detects the Sandbox environment using the following logic in `SnapshotsAccessManager`:
```swift
private func isSandbox() -> Bool {
    guard let url = Bundle.main.appStoreReceiptURL else { return false }
    return url.lastPathComponent == "sandboxReceipt"
}
```
*   **Automatic Pro**: In TestFlight/Sandbox, all users are treated as **Enterprise** so they can test every feature (Team Management, Branded Reports, Unlimited Properties) for free.

### B. Verification Flow
1.  Upload a build to **App Store Connect**.
2.  Invite your internal/external testers via **TestFlight**.
3.  When a tester opens the app, they will see the "PRO Partner" status in **Settings**.
4.  If they encounter a paywall (e.g., during a fresh database install), the "Purchase" button will show a Sandbox confirmation dialog. **No actual charges will be made.**

## 3. Database Overrides (VIP Access)
To manually grant a user permanent access regardless of their App Store status:
1.  Go to the **Supabase Dashboard**.
2.  Open the `profiles` table.
3.  Locate the user's row and set their `subscription_tier` to:
    *   `'pro'`: For Professional features.
    *   `'enterprise'`: For full White-labeling and unlimited everything.
    *   `'lifetime'`: Permanent full access.

---

## 4. Resetting Test Purchases
If you need to test the purchase flow multiple times:
1.  **Local**: In the Xcode debug bar, click the **StoreKit** icon and select "Manage Transactions" to delete previous test purchases.
2.  **Sandbox**: Go to `Settings > App Store > Sandbox Account` on your iPhone to manage or clear your test subscriptions.

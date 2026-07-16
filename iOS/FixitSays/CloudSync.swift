import Foundation

/// Disabled no-op stub. This app's iCloud/CloudKit container capability was removed 2026-07-02
/// (bundle id had to be renamed after a wrong-team registration mistake, and the ASC public API
/// has no endpoint to provision a new CloudKit container — that requires interactive Xcode/browser
/// capability setup). This was always purely best-effort owner visibility, never load-bearing:
/// Pro gating is ALWAYS decided by StoreKit `currentEntitlements` (see `Store`). Kept as a no-op
/// stub so call sites don't need to change.
enum CloudSync {
    static func recordPaidStatus(isPro: Bool, transactionID: String?) {
        // no-op: CloudKit container not provisioned for this bundle id.
    }

    static func deletePaidStatus(userID: String) {
        // no-op: CloudKit container not provisioned for this bundle id.
    }
}

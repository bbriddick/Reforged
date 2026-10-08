import Foundation
import StoreKit

/// StoreKit 2 tip jar. Tips are **consumable** in-app purchases that unlock
/// nothing — they exist purely so users can support development, satisfying
/// App Store Guideline 3.1.1 (donations tied to a digital app must use IAP).
///
/// Singleton like the rest of the app's services. `@MainActor` because it
/// publishes UI-facing state and StoreKit 2's `Product`/`Transaction` APIs are
/// used from the main actor here.
@MainActor
final class TipJarManager: ObservableObject {
    static let shared = TipJarManager()

    /// Product identifiers as configured in App Store Connect (and in the
    /// bundled `Reforged.storekit` file for local testing). Ordered small →
    /// large so the UI renders tiers in ascending price.
    enum TipProduct: String, CaseIterable {
        case small  = "com.reforged.app.tip.small"
        case medium = "com.reforged.app.tip.medium"
        case large  = "com.reforged.app.tip.large"

        /// Fallback label if StoreKit hasn't loaded the product's display name.
        /// A giving ladder echoing the ministry's support tiers (Supporter →
        /// Builder → Sponsor). Keep these in sync with the App Store Connect
        /// product display names.
        var fallbackName: String {
            switch self {
            case .small:  return "Supporter"
            case .medium: return "Builder"
            case .large:  return "Sponsor"
            }
        }

        /// SF Symbol for the tier's leading badge (Reforged uses SF Symbols /
        /// Lucide-style glyphs, not emoji).
        var symbol: String {
            switch self {
            case .small:  return "heart.fill"
            case .medium: return "hammer.fill"
            case .large:  return "sparkles"
            }
        }
    }

    /// Loaded products, sorted into `TipProduct` order.
    @Published private(set) var products: [Product] = []
    /// True while a purchase is in flight (drives button spinners / disabling).
    @Published private(set) var purchaseInFlight = false
    /// True while products are being fetched (so the UI shows a spinner only
    /// during an actual load, never indefinitely).
    @Published private(set) var isLoadingProducts = false
    /// True once a load attempt has completed at least once — lets the UI tell
    /// "still loading" apart from "loaded but empty".
    @Published private(set) var didAttemptLoad = false
    /// Set after a successful, verified tip so the sheet can show a thank-you.
    @Published var didCompleteTip = false
    /// Non-nil when product loading or a purchase failed, for surfacing a message.
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        // Listen for transactions that arrive outside an explicit purchase call
        // (Ask to Buy approvals, StoreKit retries). Consumables must still be
        // finished so StoreKit stops re-delivering them.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(verificationResult: update)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Whether any tip products are available to show.
    var hasProducts: Bool { !products.isEmpty }

    /// Fetch products from the App Store. Safe to call repeatedly.
    func loadProducts() async {
        isLoadingProducts = true
        errorMessage = nil
        defer {
            isLoadingProducts = false
            didAttemptLoad = true
        }
        do {
            let fetched = try await Product.products(for: TipProduct.allCases.map(\.rawValue))
            // Preserve our small → large ordering rather than StoreKit's.
            let order = TipProduct.allCases.map(\.rawValue)
            self.products = fetched.sorted {
                (order.firstIndex(of: $0.id) ?? 0) < (order.firstIndex(of: $1.id) ?? 0)
            }
            // An empty result (no error) means the products aren't available to
            // this account yet — most often not "Ready to Submit", the Paid Apps
            // agreement isn't active, or App Store Connect hasn't propagated them.
            if fetched.isEmpty {
                self.errorMessage = "Tips aren’t available right now. Please try again in a little while."
            }
        } catch {
            self.errorMessage = "Couldn’t load tip options. Please check your connection and try again."
        }
    }

    /// Purchase a tip. Verifies the transaction, finishes it (consumables are
    /// never restored), and flips `didCompleteTip` on success.
    func purchase(_ product: Product) async {
        guard !purchaseInFlight else { return }
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verificationResult: verification)
            case .userCancelled:
                break
            case .pending:
                // Awaiting external approval (e.g. Ask to Buy). Transaction.updates
                // will deliver it later.
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "The purchase couldn't be completed. Please try again."
        }
    }

    /// Verify and finish a transaction. For consumables this just acknowledges
    /// delivery — there's nothing to unlock.
    private func handle(verificationResult: VerificationResult<Transaction>) async {
        switch verificationResult {
        case .verified(let transaction):
            await transaction.finish()
            didCompleteTip = true
        case .unverified:
            // Failed StoreKit's signature check; don't credit or thank.
            errorMessage = "The purchase couldn't be verified."
        }
    }
}

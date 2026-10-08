import Foundation

/// Reforged Shop (Printful merch). The catalog comes from the `shop-products`
/// Supabase Edge Function, which holds the Printful token server-side, so new
/// products appear automatically. Checkout opens the Printful Quick Store in
/// Safari — physical goods can't use Apple In-App Purchase.
struct ShopProduct: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let price: Double?
    let currency: String
    let imageURL: String?
    let url: String

    var displayPrice: String? {
        guard let price else { return nil }
        return price.formatted(.currency(code: currency).precision(.fractionLength(price.rounded() == price ? 0 : 2)))
    }
}

@MainActor
final class ShopService: ObservableObject {
    static let shared = ShopService()

    static let storeURL = URL(string: "https://reforged.printful.me")!

    @Published private(set) var products: [ShopProduct] = []
    @Published private(set) var isLoading = false
    @Published private(set) var didFail = false

    private let cacheKey = "reforged_shop_products_v1"
    private let cacheDateKey = "reforged_shop_products_date_v1"
    private var lastFetch: Date?

    private init() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([ShopProduct].self, from: data) {
            products = cached
        }
        lastFetch = UserDefaults.standard.object(forKey: cacheDateKey) as? Date
    }

    private struct Response: Decodable { let products: [ShopProduct] }

    /// Refreshes at most every 30 minutes unless forced. Keeps showing the
    /// cached catalog if the network fails.
    func refresh(force: Bool = false) async {
        if !force, let lastFetch, Date().timeIntervalSince(lastFetch) < 1800, !products.isEmpty { return }
        guard let base = SettingsManager.shared.supabaseProjectURL else { return }
        let anonKey = SettingsManager.shared.supabaseAnonKey
        guard !anonKey.isEmpty else { return }

        var request = URLRequest(url: base.appendingPathComponent("functions/v1/shop-products"))
        request.timeoutInterval = 20
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("ios", forHTTPHeaderField: "x-client-platform")

        isLoading = true
        defer { isLoading = false }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            products = decoded.products
            didFail = false
            lastFetch = Date()
            UserDefaults.standard.set(try? JSONEncoder().encode(decoded.products), forKey: cacheKey)
            UserDefaults.standard.set(lastFetch, forKey: cacheDateKey)
        } catch {
            debugLog("[Shop] ❌ \(error.localizedDescription)")
            didFail = products.isEmpty
        }
    }
}

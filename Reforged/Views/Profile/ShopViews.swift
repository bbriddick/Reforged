import SwiftUI
import SafariServices

// MARK: - Copy

enum ShopCopy {
    static let headline = "Wear the mission."
    static let tagline = "Every order helps keep Reforged free and ad-free for the next generation."
}

// MARK: - In-app Safari (checkout happens on the Printful store)

struct SafariSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredControlTintColor = UIColor(Color.reforgedCoral)
        return vc
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

private struct IdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

// MARK: - Product tile

struct ShopProductTile: View {
    let product: ShopProduct
    var width: CGFloat? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Color.adaptiveChipBackground(colorScheme)
                if let raw = product.imageURL, let url = URL(string: raw) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            Image(systemName: "tshirt").font(.title2)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        default:
                            ProgressView()
                        }
                    }
                } else {
                    Image(systemName: "tshirt").font(.title2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(width: width)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let price = product.displayPrice {
                    Text("From \(price)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .frame(width: width, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this product in the Reforged Shop")
    }
}

// MARK: - Home card

/// "Wear the mission." card on Home: a horizontal strip of products, each
/// opening its store page; "Shop all" opens the full shop.
struct ShopHomeCard: View {
    @ObservedObject private var shop = ShopService.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var openURL: IdentifiedURL?
    @State private var showShop = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ShopCopy.headline)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(ShopCopy.tagline)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button("Shop all") { showShop = true }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy)
            }

            if shop.products.isEmpty {
                Button { openURL = IdentifiedURL(url: ShopService.storeURL) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "tshirt.fill")
                            .font(.title3)
                            .foregroundStyle(Color.reforgedGold)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.reforgedGold.opacity(0.15)))
                        Text(shop.isLoading ? "Loading the shop…" : "Visit the Reforged Shop")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .padding(14)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(shop.products.prefix(8)) { product in
                            Button {
                                if let url = URL(string: product.url) { openURL = IdentifiedURL(url: url) }
                            } label: {
                                ShopProductTile(product: product, width: 140)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
            }
        }
        .task { await shop.refresh() }
        .sheet(item: $openURL) { SafariSheet(url: $0.url).ignoresSafeArea() }
        .sheet(isPresented: $showShop) { ShopView() }
    }
}

// MARK: - Full shop

struct ShopView: View {
    @ObservedObject private var shop = ShopService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var openURL: IdentifiedURL?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(ShopCopy.headline)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text(ShopCopy.tagline)
                            .font(.body)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)

                    if shop.products.isEmpty {
                        VStack(spacing: 12) {
                            if shop.isLoading {
                                ProgressView()
                            } else {
                                Text(shop.didFail ? "The shop couldn't load right now." : "New items are on the way.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 160)
                    } else {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(shop.products) { product in
                                Button {
                                    if let url = URL(string: product.url) { openURL = IdentifiedURL(url: url) }
                                } label: {
                                    ShopProductTile(product: product)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button { openURL = IdentifiedURL(url: ShopService.storeURL) } label: {
                        Label("Open the full store", systemImage: "safari")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Capsule().fill(Color.reforgedCoral))
                    }
                    .buttonStyle(.plain)

                    Text("Checkout is handled securely by Printful. Items are printed on demand and shipped to you.")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .readableContentWidth()
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Reforged Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .refreshable { await shop.refresh(force: true) }
            .task { await shop.refresh() }
            .sheet(item: $openURL) { SafariSheet(url: $0.url).ignoresSafeArea() }
        }
    }
}

// MARK: - Profile row

struct ShopEntryCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showShop = false

    var body: some View {
        Button { showShop = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "tshirt.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.reforgedCoral)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.reforgedCoral.opacity(colorScheme == .dark ? 0.2 : 0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reforged Shop")
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(ShopCopy.headline)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(16)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous))
            .shadow(color: ReforgedTheme.cardShadow, radius: ReforgedTheme.cardShadowRadius, y: ReforgedTheme.cardShadowY)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showShop) { ShopView() }
    }
}

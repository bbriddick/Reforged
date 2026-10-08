import SwiftUI
import StoreKit

// MARK: - Tip Jar Sheet
//
// Replaces the old "Buy Me a Coffee" external-link prompt. Tips are consumable
// In-App Purchases (see TipJarManager) so the app complies with App Store
// Guideline 3.1.1 — a supporting purchase tied to a digital app must use IAP,
// not an external payment link.
//
// Styled to the Reforged brand: charcoal logo mark on a warm card, gold reward
// accents for the gift theme, coral for the tap-to-give action.

struct TipJarView: View {
    @Binding var isPresented: Bool
    /// Optional context line (milestone prompts pass their own copy).
    var message: String = "Reforged is supported by readers like you. A one-time tip helps cover the API, hosting, and development that keep the app fast, reliable, and ad-free."

    @StateObject private var tipJar = TipJarManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header

                if tipJar.didCompleteTip {
                    thankYou
                } else {
                    VStack(spacing: 8) {
                        Text("A ONE-TIME GIFT")
                            .font(.caption).fontWeight(.semibold)
                            .tracking(1.6)
                            .foregroundStyle(Color.reforgedGold)

                        Text("Support Reforged")
                            .font(.title2).fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .multilineTextAlignment(.center)

                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.top, 2)
                    }

                    tipOptions

                    Button {
                        dismiss()
                    } label: {
                        Text("Maybe Later")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .padding(.vertical, 10)
                    }
                }
            }
            .padding(28)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.12), radius: 30, y: 8)
            .padding(28)
        }
        .task {
            if !tipJar.hasProducts { await tipJar.loadProducts() }
        }
    }

    // MARK: Header — charcoal logo circle (the Reforged mark)

    private var header: some View {
        ZStack {
            Circle()
                .fill(Color.reforgedCharcoal)
                .frame(width: 96, height: 96)
                .shadow(color: Color.reforgedCharcoal.opacity(0.28), radius: 16, y: 6)

            if tipJar.didCompleteTip {
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Color.reforgedBrandCream)
            } else {
                Image("ReforgedMark")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .foregroundStyle(Color.reforgedBrandCream)
            }
        }
    }

    // MARK: Tip options

    @ViewBuilder
    private var tipOptions: some View {
        if tipJar.hasProducts {
            VStack(spacing: 12) {
                ForEach(tipJar.products, id: \.id) { product in
                    tipButton(for: product)
                }
            }
        } else if tipJar.isLoadingProducts || !tipJar.didAttemptLoad {
            // Spinner ONLY during an actual fetch — never indefinitely.
            ProgressView()
                .tint(Color.reforgedCoral)
                .padding(.vertical, 30)
        } else {
            // Load finished with no products (empty result or error). Show a
            // clear message and let the user retry instead of spinning forever.
            VStack(spacing: 14) {
                Text(tipJar.errorMessage ?? "Tips aren’t available right now. Please try again in a little while.")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Button {
                    Task { await tipJar.loadProducts() }
                } label: {
                    Text("Try Again")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.reforgedBrandCream)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.reforgedCharcoal))
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func tipButton(for product: Product) -> some View {
        let tier = TipJarManager.TipProduct(rawValue: product.id)
        let name = product.displayName.isEmpty ? (tier?.fallbackName ?? "Tip") : product.displayName
        return Button {
            Task { await tipJar.purchase(product) }
        } label: {
            HStack(spacing: 14) {
                // Gold reward badge
                ZStack {
                    Circle()
                        .fill(Color.reforgedGold.opacity(0.16))
                        .frame(width: 46, height: 46)
                    Image(systemName: tier?.symbol ?? "cup.and.saucer.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.reforgedGold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.headline).fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("One-time tip")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                Spacer(minLength: 8)

                // Coral action pill = tap to give. A price must never wrap
                // ("$24.9 / 9"): keep it on one line and let the name give way.
                Text(product.displayPrice)
                    .font(.subheadline).fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.reforgedCoral))
                    .layoutPriority(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.reforgedGold.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.reforgedGold.opacity(0.30), lineWidth: 1)
            )
            .opacity(tipJar.purchaseInFlight ? 0.6 : 1)
            .overlay {
                if tipJar.purchaseInFlight {
                    ProgressView().tint(Color.reforgedCoral)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(tipJar.purchaseInFlight)
    }

    // MARK: Thank you

    private var thankYou: some View {
        VStack(spacing: 14) {
            Text("Thank you")
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text("Your gift directly funds the work of keeping Reforged growing and ad-free. It means a great deal.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(.headline).fontWeight(.semibold)
                    .foregroundStyle(Color.reforgedBrandCream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.reforgedCharcoal)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.top, 4)
        }
    }

    private func dismiss() {
        // Reset the thank-you flag so a later reopen starts fresh.
        tipJar.didCompleteTip = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

// MARK: - Support Reforged Button
//
// Drop-in replacement for the old BuyMeACoffeeButton. Self-contained: it owns
// the sheet presenting the tip jar, so callers just place `SupportReforgedButton()`.
// Styled as the brand's dark CTA — charcoal pill with cream text and a gold heart.

struct SupportReforgedButton: View {
    @State private var showTipJar = false

    var body: some View {
        Button {
            showTipJar = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.reforgedGold)
                Text("Support Reforged")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.reforgedBrandCream)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
            .background(Capsule().fill(Color.reforgedCharcoal))
            .shadow(color: Color.reforgedCharcoal.opacity(0.20), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .sheet(isPresented: $showTipJar) {
            TipJarView(isPresented: $showTipJar)
                .presentationDetents([.medium, .large])
        }
    }
}

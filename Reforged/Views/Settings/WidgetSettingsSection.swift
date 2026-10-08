import SwiftUI
import WidgetKit

/// Settings → Widgets: choose the Verse of the Day widget's look. The choice is
/// written to the App Group (via `AppState.equip`), which the widget reads on
/// every timeline reload, so it applies to every placed widget.
struct WidgetSettingsSection: View {
    @ObservedObject private var appState = AppState.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showShop = false
    @State private var refreshed = false

    private var allStyles: [CosmeticItem] { CrownCatalog.items(in: .widget) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Live preview of the equipped style
            if let current = appState.equippedItem(.widget) {
                CosmeticPreview(item: current, large: true)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityLabel("Preview: \(current.name)")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Verse of the Day style")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                VStack(spacing: 0) {
                    ForEach(Array(allStyles.enumerated()), id: \.element.id) { index, item in
                        styleRow(item)
                        if index < allStyles.count - 1 { Divider().padding(.leading, 60) }
                    }
                }
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text("Nature Photo shows a new Unsplash landscape each day. Other styles come from the Crown Shop.")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            Button {
                WidgetCenter.shared.reloadAllTimelines()
                HapticManager.shared.lightImpact()
                withAnimation { refreshed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { refreshed = false } }
            } label: {
                Label(refreshed ? "Widgets refreshed" : "Refresh widgets now",
                      systemImage: refreshed ? "checkmark" : "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Capsule().fill(Color.adaptiveChipBackground(colorScheme)))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                Text("Add the widget")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                ForEach(Array([
                    "Press and hold an empty area of your Home Screen.",
                    "Tap Edit, then Add Widget.",
                    "Search for Reforged and choose Verse of the Day, small or medium.",
                ].enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.reforgedGold))
                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showShop) {
            CrownShopView().environmentObject(appState)
        }
    }

    private func styleRow(_ item: CosmeticItem) -> some View {
        let owned = appState.isOwned(item)
        let equipped = appState.isEquipped(item)
        return Button {
            if owned {
                appState.equip(item)
                HapticManager.shared.lightImpact()
            } else {
                showShop = true
            }
        } label: {
            HStack(spacing: 12) {
                swatch(item)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(1)
                }
                Spacer()
                if equipped {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.reforgedGold)
                } else if !owned, let price = item.price {
                    CrownPrice(amount: price)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(equipped ? .isSelected : [])
    }

    /// A tiny widget-shaped swatch: the style's paper with its accent and ink.
    private func swatch(_ item: CosmeticItem) -> some View {
        let c = WidgetStylePreviewColors.for(item.value, scheme: colorScheme)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(c.background)
            if item.value == "classic" {
                Image(systemName: "photo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(c.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Capsule().fill(c.accent).frame(width: 14, height: 3)
                    Capsule().fill(c.ink.opacity(0.8)).frame(width: 22, height: 3)
                    Capsule().fill(c.ink.opacity(0.8)).frame(width: 18, height: 3)
                }
                .padding(7)
            }
        }
        .frame(width: 36, height: 36)
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 0.5))
    }
}

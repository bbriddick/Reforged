import SwiftUI

// MARK: - Crown Shop

/// Spend crowns — earned by making Scripture stick — on cosmetics. Every item
/// has a fixed price and a live preview; nothing is random and nothing is sold
/// for money.
struct CrownShopView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var tab: CosmeticCategory.Tab = .themes
    @State private var selected: CosmeticItem?
    @State private var showEarnRules = false
    /// A theme equipped in the shop is applied after the sheet closes, because
    /// applying a palette rebuilds the app's root view.
    @State private var themeChanged = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ReforgedTheme.spacingL) {
                    balanceHeader
                    tabBar
                    ForEach(tab.categories) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.title)
                                    .font(.headline)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                Text(category.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 4)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(CrownCatalog.items(in: category)) { item in
                                    Button { selected = item } label: { ShopItemCard(item: item) }
                                        .buttonStyle(ShopCardPressStyle())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, ReforgedTheme.spacingXL)
                .readableContentWidth()
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Crown Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selected) { item in
                ShopItemDetailSheet(item: item, onThemeEquipped: { themeChanged = true })
                    .environmentObject(appState)
                    .presentationDetents([.medium, .large])
            }
        }
        .onDisappear {
            guard themeChanged else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { appState.applyEquippedTheme() }
        }
    }

    // MARK: Header

    private var balanceHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.reforgedGold)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Color.reforgedGold.opacity(colorScheme == .dark ? 0.2 : 0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(appState.crownBalance)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .contentTransition(.numericText())
                    Text(appState.crownBalance == 1 ? "crown to spend" : "crowns to spend")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer()
            }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showEarnRules.toggle() }
            } label: {
                HStack {
                    Text("How to earn crowns")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(showEarnRules ? 180 : 0))
                }
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showEarnRules {
                VStack(spacing: 8) {
                    earnRow("brain.head.profile", "A verse becomes Familiar", 1)
                    earnRow("brain.head.profile", "Known", 3)
                    earnRow("brain.head.profile", "Well-Known", 5)
                    earnRow("crown.fill", "Mastered", 10)
                    earnRow("checkmark.circle.fill", "Finish a review session", 1)
                    earnRow("sun.max.fill", "Meet your daily goal", 1)
                    earnRow("calendar", "A perfect week", 5)
                    earnRow("map.fill", "Complete a learning-path unit", 5)
                    earnRow("book.closed.fill", "Finish a book of the Bible", 3)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge + 4, style: .continuous))
        .shadow(color: ReforgedTheme.cardShadow, radius: ReforgedTheme.cardShadowRadius, y: ReforgedTheme.cardShadowY)
        .padding(.top, 8)
    }

    private func earnRow(_ icon: String, _ text: String, _ crowns: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .frame(width: 18)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Spacer()
            CrownPrice(amount: crowns, prefix: "+")
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CosmeticCategory.Tab.allCases) { t in
                    let isOn = t == tab
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { tab = t }
                    } label: {
                        Text(t.rawValue)
                            .font(.subheadline.weight(isOn ? .semibold : .regular))
                            .foregroundStyle(isOn ? Color.adaptiveCardBackground(colorScheme) : Color.adaptiveText(colorScheme))
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(Capsule().fill(isOn ? Color.adaptiveNavyText(colorScheme) : Color.adaptiveChipBackground(colorScheme)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
    }
}

private struct ShopCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Price pill

struct CrownPrice: View {
    let amount: Int
    var prefix: String = ""
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "crown.fill").font(.system(size: 10, weight: .bold))
            Text("\(prefix)\(amount)").font(.caption.weight(.bold)).monospacedDigit()
        }
        .foregroundStyle(Color.reforgedGold)
    }
}

// MARK: - Item card

struct ShopItemCard: View {
    let item: CosmeticItem
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let owned = appState.isOwned(item)
        let equipped = appState.isEquipped(item)
        VStack(alignment: .leading, spacing: 10) {
            CosmeticPreview(item: item)
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineLimit(1)
                statusLine(owned: owned, equipped: equipped)
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous)
                .stroke(equipped ? Color.reforgedGold : .clear, lineWidth: 2)
        )
        .shadow(color: ReforgedTheme.cardShadow, radius: ReforgedTheme.cardShadowRadius, y: ReforgedTheme.cardShadowY)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(equipped ? "equipped" : owned ? "owned" : item.price.map { "\($0) crowns" } ?? "free")")
    }

    @ViewBuilder
    private func statusLine(owned: Bool, equipped: Bool) -> some View {
        if equipped {
            Label(item.category.isToggle ? "On" : "Equipped", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.reforgedGold)
        } else if owned {
            Text(item.isFree ? "Free" : "Owned")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        } else if let price = item.price {
            HStack(spacing: 6) {
                CrownPrice(amount: price)
                if let hint = appState.perkHint(for: item) {
                    Text(hint)
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }
}

// MARK: - Detail sheet

struct ShopItemDetailSheet: View {
    let item: CosmeticItem
    var onThemeEquipped: () -> Void = {}
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var celebrate = false
    @State private var previewingSound = false

    var body: some View {
        let owned = appState.isOwned(item)
        let equipped = appState.isEquipped(item)
        VStack(spacing: 18) {
            CosmeticPreview(item: item, large: true)
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if celebrate {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.reforgedGold)
                            .padding(12)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(celebrate ? 1.02 : 1)

            VStack(spacing: 6) {
                Text(item.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                if let hint = appState.perkHint(for: item), !owned {
                    Text(hint + ", or buy it now")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }

            if AmbientSoundPlayer.isSound(item.value) {
                Button {
                    previewingSound.toggle()
                    if previewingSound { AmbientSoundPlayer.shared.play(item.value) } else { AmbientSoundPlayer.shared.stop() }
                } label: {
                    Label(previewingSound ? "Stop preview" : "Listen", systemImage: previewingSound ? "stop.fill" : "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(Capsule().fill(Color.adaptiveChipBackground(colorScheme)))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            actionButton(owned: owned, equipped: equipped)
        }
        .padding(20)
        .padding(.top, 8)
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .onDisappear {
            if previewingSound {
                AmbientSoundPlayer.shared.stop()
                // Resume the equipped sound, if any, after a preview.
                AmbientSoundPlayer.shared.syncWithEquipped()
            }
        }
    }

    @ViewBuilder
    private func actionButton(owned: Bool, equipped: Bool) -> some View {
        if owned {
            Button {
                appState.equip(item)
                HapticManager.shared.success()
                if item.category == .theme { onThemeEquipped() }
                if item.category == .reader { AmbientSoundPlayer.shared.syncWithEquipped() }
                dismiss()
            } label: {
                primaryLabel(equipped
                    ? (item.category.isToggle ? "Turn off" : "Equipped")
                    : (item.category.isToggle ? "Turn on" : "Equip"),
                             filled: !equipped || item.category.isToggle)
            }
            .buttonStyle(.plain)
            .disabled(equipped && !item.category.isToggle)
        } else if let price = item.price {
            let canAfford = appState.crownBalance >= price
            VStack(spacing: 8) {
                Button {
                    guard appState.purchase(item) else { return }
                    HapticManager.shared.success()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { celebrate = true }
                } label: {
                    HStack(spacing: 6) {
                        Text("Buy for")
                        Image(systemName: "crown.fill").font(.subheadline.weight(.bold))
                        Text("\(price)").monospacedDigit()
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(Color.reforgedCoral))
                    .opacity(canAfford ? 1 : 0.4)
                }
                .buttonStyle(.plain)
                .disabled(!canAfford)
                if !canAfford {
                    Text("You need \(price - appState.crownBalance) more crowns")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
        }
    }

    private func primaryLabel(_ title: String, filled: Bool) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(filled ? .white : Color.adaptiveTextSecondary(colorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Capsule().fill(filled ? Color.reforgedCoral : Color.adaptiveChipBackground(colorScheme)))
    }
}

// MARK: - Previews

/// A live miniature of each cosmetic, drawn from the same values the app uses.
struct CosmeticPreview: View {
    let item: CosmeticItem
    var large = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch item.category {
        case .theme: themePreview
        case .frame: framePreview
        case .emblem: emblemPreview
        case .verseCard: VerseCardStylePreview(style: item.value, large: large)
        case .widget: widgetPreview
        case .highlight: highlightPreview
        case .reader: readerPreview
        }
    }

    // Split light | dark mini screens in the palette's own colors.
    private var themePreview: some View {
        let p = ThemePalette.named(item.value)
        return HStack(spacing: 0) {
            miniScreen(bg: p.lightBackground, card: p.lightCard, ink: Color(white: 0.18), p: p)
            miniScreen(bg: p.darkBackground, card: p.darkCard, ink: Color(white: 0.92), p: p)
        }
    }

    private func miniScreen(bg: Color, card: Color, ink: Color, p: ThemePalette) -> some View {
        ZStack {
            bg
            VStack(alignment: .leading, spacing: large ? 8 : 5) {
                RoundedRectangle(cornerRadius: 3).fill(ink.opacity(0.8)).frame(width: large ? 60 : 36, height: large ? 7 : 5)
                VStack(alignment: .leading, spacing: large ? 6 : 4) {
                    RoundedRectangle(cornerRadius: 2).fill(ink.opacity(0.35)).frame(height: large ? 5 : 3)
                    RoundedRectangle(cornerRadius: 2).fill(ink.opacity(0.35)).frame(width: large ? 70 : 40, height: large ? 5 : 3)
                    HStack(spacing: 4) {
                        Capsule().fill(p.action).frame(width: large ? 44 : 26, height: large ? 14 : 9)
                        Circle().fill(p.reward).frame(width: large ? 14 : 9, height: large ? 14 : 9)
                    }
                }
                .padding(large ? 10 : 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: large ? 8 : 5).fill(card))
            }
            .padding(large ? 16 : 9)
        }
    }

    private var framePreview: some View {
        ZStack {
            Color.adaptiveChipBackground(colorScheme).opacity(0.6)
            ZStack {
                Circle().fill(Color.adaptiveCardBackground(colorScheme))
                Text("🦁").font(.system(size: large ? 56 : 34))
            }
            .frame(width: large ? 104 : 64, height: large ? 104 : 64)
            .overlay(AvatarFrameRing(style: item.value, lineWidth: large ? 5 : 3.5).padding(large ? -7 : -5))
        }
    }

    private var emblemPreview: some View {
        ZStack {
            Color.adaptiveChipBackground(colorScheme).opacity(0.6)
            if item.value.isEmpty {
                Image(systemName: "circle.slash")
                    .font(.system(size: large ? 40 : 26))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.5))
            } else {
                Image(systemName: item.value)
                    .font(.system(size: large ? 44 : 28, weight: .semibold))
                    .foregroundStyle(Color.reforgedGold)
                    .frame(width: large ? 96 : 60, height: large ? 96 : 60)
                    .background(Circle().fill(Color.reforgedGold.opacity(0.16)))
            }
        }
    }

    private var widgetPreview: some View {
        let s = WidgetStylePreviewColors.for(item.value, scheme: colorScheme)
        return ZStack {
            Color.adaptiveChipBackground(colorScheme).opacity(0.6)
            VStack(alignment: .leading, spacing: large ? 8 : 5) {
                Text("VERSE OF THE DAY")
                    .font(.system(size: large ? 9 : 6, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(s.accent)
                Text("The LORD is my shepherd; I shall not want.")
                    .font(.system(size: large ? 14 : 9, design: .serif))
                    .foregroundStyle(s.ink)
                    .lineLimit(3)
                Spacer(minLength: 0)
                Text("Psalm 23:1")
                    .font(.system(size: large ? 10 : 7, weight: .semibold))
                    .foregroundStyle(s.accent)
            }
            .padding(large ? 14 : 9)
            .frame(width: large ? 150 : 90, height: large ? 150 : 90, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: large ? 24 : 16, style: .continuous).fill(s.background))
        }
    }

    private var highlightPreview: some View {
        let colors = HighlightPalette.colors(for: item.value)
        return ZStack {
            Color.adaptiveCardBackground(colorScheme)
            VStack(alignment: .leading, spacing: large ? 8 : 5) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: large ? 6 : 4) {
                        ForEach(0..<2, id: \.self) { col in
                            let c = colors[row * 2 + col]
                            Text(row == 0 && col == 0 ? "In the" : row == 0 ? "beginning" : row == 1 && col == 0 ? "was the" : row == 1 ? "Word," : col == 0 ? "and the" : "Word…")
                                .font(.system(size: large ? 15 : 10, design: .serif))
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                                .padding(.horizontal, 3)
                                .background(HighlighterBackground(color: c.opacity(colorScheme == .dark ? 0.5 : 0.65)))
                        }
                    }
                }
            }
        }
    }

    private var readerPreview: some View {
        ZStack {
            Color.adaptiveChipBackground(colorScheme).opacity(0.6)
            if item.value == "dropcaps" {
                HStack(alignment: .top, spacing: 6) {
                    IlluminatedInitial(letter: "I", size: large ? 64 : 40)
                    VStack(alignment: .leading, spacing: large ? 6 : 4) {
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.adaptiveTextSecondary(colorScheme).opacity(0.35))
                                .frame(width: large ? CGFloat(90 - i * 12) : CGFloat(50 - i * 8), height: large ? 5 : 3)
                        }
                    }
                    .padding(.top, 4)
                }
            } else {
                VStack(spacing: large ? 10 : 6) {
                    Image(systemName: AmbientSoundPlayer.icon(for: item.value))
                        .font(.system(size: large ? 44 : 28, weight: .semibold))
                        .foregroundStyle(Color.reforgedGold)
                    HStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { i in
                            Capsule().fill(Color.reforgedGold.opacity(0.5))
                                .frame(width: 3, height: CGFloat([6, 12, 18, 10, 16, 8, 12][i]) * (large ? 1.4 : 0.9))
                        }
                    }
                }
            }
        }
    }
}

/// Widget style colors, mirrored in the widget extension (ReforgedWidget) —
/// keep the two in step.
enum WidgetStylePreviewColors {
    struct Colors { let background: Color; let ink: Color; let accent: Color }

    static func `for`(_ style: String, scheme: ColorScheme) -> Colors {
        func hex(_ v: UInt32) -> Color {
            Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
        }
        switch style {
        case "parchment": return Colors(background: hex(0xF3EAD7), ink: hex(0x3B2F22), accent: hex(0xA0652F))
        case "midnight": return Colors(background: hex(0x0E1422), ink: hex(0xE9ECF3), accent: hex(0xE0B872))
        case "charcoal": return Colors(background: hex(0x333333), ink: hex(0xE8E4DC), accent: hex(0xD4A574))
        case "stainedglass": return Colors(background: hex(0x17305A), ink: hex(0xF3F5FA), accent: hex(0xE3B341))
        default: // Classic = the nature-photo widget, approximated by its dark green
            return Colors(background: hex(0x1F2E27), ink: .white, accent: hex(0xFFDB73))
        }
    }
}

// MARK: - Entry card (Profile)

struct CrownShopEntryCard: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var showShop = false

    var body: some View {
        Button { showShop = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.reforgedGold)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.reforgedGold.opacity(colorScheme == .dark ? 0.2 : 0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Crown Shop")
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Themes, frames, verse cards, and more")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer()
                CrownPrice(amount: appState.crownBalance)
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
        .sheet(isPresented: $showShop) {
            CrownShopView().environmentObject(appState)
        }
    }
}

// MARK: - Crown gain toast

/// Non-blocking "+3 crowns · Romans 8:28 is now Known" — the moment effort
/// turns into something you can spend.
struct CrownGainToast: View {
    let amount: Int
    let reason: String
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if isPresented {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.reforgedGold)
                VStack(alignment: .leading, spacing: 1) {
                    Text("+\(amount) crown\(amount == 1 ? "" : "s")")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.adaptiveCardBackground(colorScheme)))
            .overlay(Capsule().stroke(Color.reforgedGold.opacity(0.4), lineWidth: 1))
            .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                HapticManager.shared.lightImpact()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                    withAnimation(.easeIn(duration: 0.25)) { isPresented = false }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

// MARK: - Reader panel controls (Bible "AA" panel)

/// Where owned crown-shop extras are controlled day to day: switch themes and
/// highlighter sets, toggle illuminated capitals, and pick an ambient sound with
/// its volume — without leaving the chapter. Only owned items appear.
struct ReaderCrownExtrasSection: View {
    @ObservedObject private var appState = AppState.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showShop = false
    @State private var volume: Double = AmbientSoundPlayer.shared.volume

    private func owned(_ category: CosmeticCategory) -> [CosmeticItem] {
        CrownCatalog.items(in: category).filter { appState.isOwned($0) }
    }

    private var ownedSounds: [CosmeticItem] {
        owned(.reader).filter { AmbientSoundPlayer.isSound($0.value) }
    }

    private var ownsCapitals: Bool {
        appState.isOwned(CrownCatalog.item("reader.dropcaps")!)
    }

    private var activeSoundID: String? {
        ownedSounds.first { appState.isEquipped($0) }?.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Crown Extras")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                Spacer()
                Button { showShop = true } label: {
                    HStack(spacing: 4) {
                        CrownPrice(amount: appState.crownBalance)
                        Text("Shop").font(.caption.weight(.semibold))
                        Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(Color.reforgedGold)
                }
                .buttonStyle(.plain)
            }

            if owned(.theme).count > 1 {
                chipRow(title: "Color theme", items: owned(.theme)) { item in
                    let p = ThemePalette.named(item.value)
                    return AnyView(HStack(spacing: 3) {
                        Circle().fill(p.action).frame(width: 9, height: 9)
                        Circle().fill(p.reward).frame(width: 9, height: 9)
                    })
                } onSelect: { item in
                    appState.equip(item)
                    // Rebuilds the root view to repaint every surface.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { appState.applyEquippedTheme() }
                }
            }

            if owned(.highlight).count > 1 {
                chipRow(title: "Highlighters", items: owned(.highlight)) { item in
                    AnyView(HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle().fill(HighlightPalette.colors(for: item.value)[i]).frame(width: 8, height: 8)
                        }
                    })
                } onSelect: { appState.equip($0) }
            }

            if ownsCapitals {
                Toggle(isOn: Binding(
                    get: { appState.isEquipped(CrownCatalog.item("reader.dropcaps")!) },
                    set: { _ in appState.equip(CrownCatalog.item("reader.dropcaps")!) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Illuminated capitals")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text("A gilded first letter on every chapter.")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }
                .tint(Color.reforgedGold)
            }

            if !ownedSounds.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ambience")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            soundChip(title: "Off", icon: "speaker.slash.fill", isOn: activeSoundID == nil) {
                                if let active = ownedSounds.first(where: { appState.isEquipped($0) }) {
                                    appState.equip(active)   // toggles it off
                                }
                                AmbientSoundPlayer.shared.syncWithEquipped()
                            }
                            ForEach(ownedSounds) { item in
                                soundChip(title: item.name, icon: AmbientSoundPlayer.icon(for: item.value),
                                          isOn: activeSoundID == item.id) {
                                    if activeSoundID != item.id { appState.equip(item) }
                                    AmbientSoundPlayer.shared.syncWithEquipped()
                                }
                            }
                        }
                    }
                    if activeSoundID != nil {
                        HStack(spacing: 10) {
                            Image(systemName: "speaker.fill").font(.caption)
                            Slider(value: $volume, in: 0.05...1) { _ in }
                                .tint(Color.reforgedGold)
                                .onChange(of: volume) { AmbientSoundPlayer.shared.volume = $0 }
                            Image(systemName: "speaker.wave.3.fill").font(.caption)
                        }
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Ambience volume")
                    }
                }
            }

            if owned(.theme).count <= 1 && owned(.highlight).count <= 1 && !ownsCapitals && ownedSounds.isEmpty {
                Text("Spend crowns on reader themes, highlighter sets, illuminated capitals, and ambient sounds. They'll appear here to switch while you read.")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
        .sheet(isPresented: $showShop) {
            CrownShopView().environmentObject(appState)
        }
    }

    private func chipRow(title: String, items: [CosmeticItem],
                         swatch: @escaping (CosmeticItem) -> AnyView,
                         onSelect: @escaping (CosmeticItem) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        let isOn = appState.isEquipped(item)
                        Button {
                            HapticManager.shared.lightImpact()
                            onSelect(item)
                        } label: {
                            HStack(spacing: 6) {
                                swatch(item)
                                Text(item.name).font(.caption.weight(isOn ? .semibold : .regular))
                            }
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(Capsule().fill(Color.adaptiveCardBackground(colorScheme)))
                            .overlay(Capsule().stroke(isOn ? Color.reforgedGold : Color.adaptiveBorder(colorScheme), lineWidth: isOn ? 1.5 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
            }
        }
    }

    private func soundChip(title: String, icon: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.lightImpact()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(title).font(.caption.weight(isOn ? .semibold : .regular))
            }
            .foregroundStyle(isOn ? Color.adaptiveCardBackground(colorScheme) : Color.adaptiveText(colorScheme))
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(isOn ? Color.adaptiveNavyText(colorScheme) : Color.adaptiveCardBackground(colorScheme)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

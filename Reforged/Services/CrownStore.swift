import Foundation
import SwiftUI
import WidgetKit

// MARK: - Crown economy
//
// Crowns are earned by effort that makes Scripture stick (verses deepening,
// finished review sessions, full days, whole units, whole books) and spent in
// the crown shop on cosmetics. They are EARNED ONLY — never sold for money —
// which keeps them clear of App Store virtual-currency rules, and there are no
// random draws: every item has a fixed price and a preview.
//
// State lives on `UserProfile.cosmetics` and syncs through one CloudKit JSON
// field. Balance = earned − spent, merged like XP (max of each), so a purchase
// on one device can't be undone by another device's higher balance.

struct CosmeticsState: Codable, Equatable {
    var crownsEarned: Int = 0
    var crownsSpent: Int = 0
    /// Item ids bought with crowns. Perk-unlocked and free items are derived,
    /// not stored, so they can never be "lost".
    var owned: [String] = []
    /// Category rawValue → equipped item id.
    var equipped: [String: String] = [:]
    /// One-time award keys ("tier:John 3:16:3", "unit:faith", "book:Ruth") so a
    /// milestone can only pay out once, even across devices.
    var awardedKeys: [String] = []
    var lastDailyGoalDay: String = ""
    var lastPerfectWeek: String = ""

    var balance: Int { max(0, crownsEarned - crownsSpent) }

    mutating func merge(_ other: CosmeticsState) {
        crownsEarned = max(crownsEarned, other.crownsEarned)
        crownsSpent = max(crownsSpent, other.crownsSpent)
        owned = Array(Set(owned).union(other.owned)).sorted()
        awardedKeys = Array(Set(awardedKeys).union(other.awardedKeys))
        for (k, v) in other.equipped where equipped[k] == nil { equipped[k] = v }
        lastDailyGoalDay = max(lastDailyGoalDay, other.lastDailyGoalDay)
        lastPerfectWeek = max(lastPerfectWeek, other.lastPerfectWeek)
    }
}

// MARK: - Catalog

enum CosmeticCategory: String, CaseIterable, Identifiable {
    case theme, frame, emblem, verseCard, widget, highlight, reader

    var id: String { rawValue }

    var title: String {
        switch self {
        case .theme: return "Themes"
        case .frame: return "Avatar Frames"
        case .emblem: return "Emblems"
        case .verseCard: return "Verse Cards"
        case .widget: return "Widget Styles"
        case .highlight: return "Highlighters"
        case .reader: return "Reader Extras"
        }
    }

    /// One line explaining what the category changes, shown under its shop heading.
    var subtitle: String {
        switch self {
        case .theme: return "Recolor the whole app: paper, cards, and accents."
        case .frame: return "The ring around your profile picture."
        case .emblem: return "A small symbol shown beside your name."
        case .verseCard: return "Text styles for the verse images you share."
        case .widget: return "The look of your Verse of the Day home-screen widget. Nature Photo shows a new Unsplash landscape each day."
        case .highlight: return "New colors for your Bible highlights. Your highlights stay where they are."
        case .reader: return "Add-ons for the Bible reader: a gilded first letter on every chapter, or soft background sound while you read. One sound plays at a time."
        }
    }

    var icon: String {
        switch self {
        case .theme: return "paintpalette.fill"
        case .frame: return "circle.circle.fill"
        case .emblem: return "seal.fill"
        case .verseCard: return "photo.on.rectangle.angled"
        case .widget: return "square.grid.2x2.fill"
        case .highlight: return "highlighter"
        case .reader: return "text.book.closed.fill"
        }
    }

    /// Shop tabs group the seven categories into five.
    enum Tab: String, CaseIterable, Identifiable {
        case themes = "Themes", profile = "Profile", verseCards = "Verse Cards",
             widgets = "Widgets", reader = "Reader"
        var id: String { rawValue }
        var categories: [CosmeticCategory] {
            switch self {
            case .themes: return [.theme]
            case .profile: return [.frame, .emblem]
            case .verseCards: return [.verseCard]
            case .widgets: return [.widget]
            case .reader: return [.highlight, .reader]
            }
        }
    }

    /// Reader extras are toggles (many can be on); every other category equips one.
    var isToggle: Bool { self == .reader }
}

struct CosmeticItem: Identifiable, Hashable {
    enum Unlock: Hashable {
        case free
        case crowns(Int)
        /// Free once a level/streak perk unlocks; otherwise buyable for crowns.
        case perk(id: String, orCrowns: Int)
    }

    let id: String
    let category: CosmeticCategory
    let name: String
    let detail: String
    /// Category-specific payload: palette id, SF Symbol, style key…
    let value: String
    /// Crown price, or nil when free.
    let price: Int?
    /// Perk that unlocks this for free (still buyable for `price`).
    let perkID: String?

    var isFree: Bool { price == nil }

    /// `Unlock` is only the catalog's authoring syntax; it's decomposed into
    /// plain stored fields here. Keeping the associated-value enum out of the
    /// stored state avoids a Swift 6.3 optimizer crash ("Found ownership
    /// error") when views read it in Release/Archive builds.
    init(id: String, category: CosmeticCategory, name: String, detail: String, unlock: Unlock, value: String) {
        self.id = id
        self.category = category
        self.name = name
        self.detail = detail
        self.value = value
        switch unlock {
        case .free:
            price = nil; perkID = nil
        case .crowns(let c):
            price = c; perkID = nil
        case .perk(let perk, let c):
            price = c; perkID = perk
        }
    }
}

enum CrownCatalog {
    static let items: [CosmeticItem] = themes + frames + emblems + verseCards + widgets + highlighters + reader

    static func items(in category: CosmeticCategory) -> [CosmeticItem] {
        items.filter { $0.category == category }
    }

    static func item(_ id: String) -> CosmeticItem? { items.first { $0.id == id } }

    static func defaultItem(for category: CosmeticCategory) -> CosmeticItem? {
        items(in: category).first { $0.isFree }
    }

    // Themes — ids match ThemePalette ids.
    static let themes: [CosmeticItem] = [
        .init(id: "theme.classic", category: .theme, name: "Classic", detail: "Warm paper, coral and gold", unlock: .free, value: "classic"),
        .init(id: "theme.parchment", category: .theme, name: "Parchment", detail: "Aged paper and terracotta", unlock: .perk(id: "theme-parchment", orCrowns: 40), value: "parchment"),
        .init(id: "theme.midnight", category: .theme, name: "Midnight", detail: "Deep blue for late reading", unlock: .perk(id: "theme-midnight", orCrowns: 40), value: "midnight"),
        .init(id: "theme.forest", category: .theme, name: "Forest", detail: "Quiet greens", unlock: .perk(id: "theme-forest", orCrowns: 50), value: "forest"),
        .init(id: "theme.royal", category: .theme, name: "Royal Purple", detail: "Majestic purple accents", unlock: .perk(id: "theme-royal", orCrowns: 50), value: "royal"),
        .init(id: "theme.vellum", category: .theme, name: "Vellum", detail: "Manuscript cream and oxblood", unlock: .crowns(60), value: "vellum"),
        .init(id: "theme.candlelight", category: .theme, name: "Candlelight", detail: "Warm amber glow", unlock: .crowns(60), value: "candlelight"),
        .init(id: "theme.stainedglass", category: .theme, name: "Stained Glass", detail: "Cobalt and jewel gold", unlock: .crowns(70), value: "stainedglass"),
        .init(id: "theme.olive", category: .theme, name: "Olive Grove", detail: "Soft olive and wheat", unlock: .crowns(60), value: "olive"),
        .init(id: "theme.desertdawn", category: .theme, name: "Desert Dawn", detail: "Sunrise terracotta", unlock: .crowns(60), value: "desertdawn"),
        .init(id: "theme.sabbath", category: .theme, name: "Sabbath", detail: "Restful slate blue", unlock: .crowns(60), value: "sabbath"),
    ]

    // Avatar frames — ids for perk borders match the existing activeProfileBorder values.
    static let frames: [CosmeticItem] = [
        .init(id: "frame.none", category: .frame, name: "Simple", detail: "A thin gold ring", unlock: .free, value: ""),
        .init(id: "border-gold", category: .frame, name: "Gold", detail: "A golden ring", unlock: .perk(id: "border-gold", orCrowns: 25), value: "border-gold"),
        .init(id: "border-flame", category: .frame, name: "Flame", detail: "For a burning streak", unlock: .perk(id: "border-flame", orCrowns: 45), value: "border-flame"),
        .init(id: "border-crown", category: .frame, name: "Royal", detail: "Crown-adorned", unlock: .perk(id: "border-crown", orCrowns: 60), value: "border-crown"),
        .init(id: "border-diamond", category: .frame, name: "Diamond", detail: "A sparkling edge", unlock: .perk(id: "border-diamond", orCrowns: 80), value: "border-diamond"),
        .init(id: "frame.olive", category: .frame, name: "Olive Wreath", detail: "Peace, in green", unlock: .crowns(35), value: "frame.olive"),
        .init(id: "frame.sea", category: .frame, name: "Galilee", detail: "Sea-glass blue", unlock: .crowns(35), value: "frame.sea"),
        .init(id: "frame.dawn", category: .frame, name: "Dawn", detail: "First light", unlock: .crowns(40), value: "frame.dawn"),
        .init(id: "frame.stainedglass", category: .frame, name: "Stained Glass", detail: "Many colors, one light", unlock: .crowns(55), value: "frame.stainedglass"),
    ]

    // Emblems — a small mark beside your name and avatar.
    static let emblems: [CosmeticItem] = [
        .init(id: "emblem.none", category: .emblem, name: "No Emblem", detail: "Keep it simple", unlock: .free, value: ""),
        .init(id: "emblem.dove", category: .emblem, name: "Dove", detail: "The Spirit's peace", unlock: .crowns(20), value: "bird.fill"),
        .init(id: "emblem.fish", category: .emblem, name: "Ichthys", detail: "The early church's sign", unlock: .crowns(20), value: "fish.fill"),
        .init(id: "emblem.olive", category: .emblem, name: "Olive Branch", detail: "Grafted in", unlock: .crowns(25), value: "leaf.fill"),
        .init(id: "emblem.lamp", category: .emblem, name: "Lamp", detail: "A lamp unto my feet", unlock: .crowns(25), value: "flame.fill"),
        .init(id: "emblem.mountain", category: .emblem, name: "Mountain", detail: "I lift up mine eyes", unlock: .crowns(30), value: "mountain.2.fill"),
        .init(id: "emblem.shield", category: .emblem, name: "Shield", detail: "The shield of faith", unlock: .crowns(30), value: "shield.fill"),
        .init(id: "emblem.crown", category: .emblem, name: "Crown", detail: "A crown of life", unlock: .crowns(50), value: "crown.fill"),
    ]

    // Verse image card styles — typography/layout treatments over any photo.
    static let verseCards: [CosmeticItem] = [
        .init(id: "card.classic", category: .verseCard, name: "Classic", detail: "Centered serif", unlock: .free, value: "classic"),
        .init(id: "card.illuminated", category: .verseCard, name: "Illuminated", detail: "Gold drop capital and rule", unlock: .crowns(30), value: "illuminated"),
        .init(id: "card.manuscript", category: .verseCard, name: "Manuscript", detail: "Parchment panel, ink text", unlock: .crowns(30), value: "manuscript"),
        .init(id: "card.poster", category: .verseCard, name: "Poster", detail: "Bold uppercase headline", unlock: .crowns(25), value: "poster"),
        .init(id: "card.minimal", category: .verseCard, name: "Minimal", detail: "Small, quiet, lower third", unlock: .crowns(20), value: "minimal"),
        .init(id: "card.framed", category: .verseCard, name: "Framed", detail: "A fine gold border", unlock: .crowns(25), value: "framed"),
    ]

    // Widget styles — read by the widget extension from the App Group.
    static let widgets: [CosmeticItem] = [
        .init(id: "widget.classic", category: .widget, name: "Nature Photo", detail: "A fresh Unsplash landscape behind the verse each day", unlock: .free, value: "classic"),
        .init(id: "widget.parchment", category: .widget, name: "Parchment", detail: "Warm paper and ink", unlock: .crowns(30), value: "parchment"),
        .init(id: "widget.midnight", category: .widget, name: "Midnight", detail: "Deep blue with gold", unlock: .crowns(30), value: "midnight"),
        .init(id: "widget.charcoal", category: .widget, name: "Charcoal", detail: "The logo's charcoal and cream", unlock: .crowns(25), value: "charcoal"),
        .init(id: "widget.stainedglass", category: .widget, name: "Stained Glass", detail: "Cobalt glass and gold", unlock: .crowns(40), value: "stainedglass"),
    ]

    // Highlighter palettes — recolor the six highlight slots in the reader.
    static let highlighters: [CosmeticItem] = [
        .init(id: "hl.classic", category: .highlight, name: "Classic", detail: "Bright marker colors", unlock: .free, value: "classic"),
        .init(id: "hl.goldleaf", category: .highlight, name: "Gold Leaf", detail: "Gilded, like old Bibles", unlock: .crowns(35), value: "goldleaf"),
        .init(id: "hl.pastel", category: .highlight, name: "Pastel", detail: "Soft and gentle", unlock: .crowns(25), value: "pastel"),
        .init(id: "hl.jewel", category: .highlight, name: "Jewel", detail: "Ruby, emerald, sapphire", unlock: .crowns(35), value: "jewel"),
        .init(id: "hl.earth", category: .highlight, name: "Earth", detail: "Clay, sage, and sand", unlock: .crowns(25), value: "earth"),
    ]

    // Reader extras — independent toggles.
    static let reader: [CosmeticItem] = [
        .init(id: "reader.dropcaps", category: .reader, name: "Illuminated Capitals", detail: "A gilded first letter on every chapter", unlock: .crowns(50), value: "dropcaps"),
        .init(id: "reader.rain", category: .reader, name: "Rain", detail: "Ambient sound while you read", unlock: .crowns(30), value: "rain"),
        .init(id: "reader.sea", category: .reader, name: "Galilee Shore", detail: "Waves while you read", unlock: .crowns(30), value: "sea"),
        .init(id: "reader.hearth", category: .reader, name: "Hearth", detail: "A crackling fire", unlock: .crowns(30), value: "hearth"),
        .init(id: "reader.chapel", category: .reader, name: "Chapel", detail: "A soft sustained drone", unlock: .crowns(40), value: "chapel"),
    ]
}

// MARK: - Earning & spending

extension AppState {
    /// Crowns paid for each verse depth tier reached for the first time.
    static let crownsForVerseLevel: [Int: Int] = [2: 1, 3: 3, 4: 5, 5: 10]

    var crownBalance: Int { user.cosmetics.balance }

    /// Awards crowns and shows the toast. `key` makes an award one-time.
    func awardCrowns(_ amount: Int, reason: String, key: String? = nil) {
        guard amount > 0 else { return }
        if let key {
            guard !user.cosmetics.awardedKeys.contains(key) else { return }
            user.cosmetics.awardedKeys.append(key)
        }
        user.cosmetics.crownsEarned += amount
        lastCrownGain = amount
        lastCrownReason = reason
        showCrownGain = true
        saveToLocalStorage()
    }

    // MARK: Ownership

    func isOwned(_ item: CosmeticItem) -> Bool {
        if item.isFree { return true }
        if user.cosmetics.owned.contains(item.id) { return true }
        guard let perkId = item.perkID else { return false }
        return user.perks.contains { $0.id == perkId && $0.isUnlocked }
    }

    /// The perk condition text for perk-unlockable items, e.g. "Free at level 12".
    func perkHint(for item: CosmeticItem) -> String? {
        guard let perkId = item.perkID,
              let perk = SampleData.perks.first(where: { $0.id == perkId }) else { return nil }
        switch perk.unlockCondition {
        case .level(let l): return "Free at level \(l)"
        case .streak(let d): return "Free at a \(d)-day streak"
        case .badge: return "Free with a badge"
        case .xp(let x): return "Free at \(x) XP"
        }
    }

    @discardableResult
    func purchase(_ item: CosmeticItem) -> Bool {
        guard !isOwned(item), let price = item.price, crownBalance >= price else { return false }
        user.cosmetics.crownsSpent += price
        user.cosmetics.owned.append(item.id)
        saveToLocalStorage()
        return true
    }

    // MARK: Equipping

    func equippedItem(_ category: CosmeticCategory) -> CosmeticItem? {
        if let id = user.cosmetics.equipped[category.rawValue], let item = CrownCatalog.item(id) {
            return item
        }
        return CrownCatalog.defaultItem(for: category)
    }

    func isEquipped(_ item: CosmeticItem) -> Bool {
        if item.category.isToggle {
            return user.cosmetics.equipped[item.id] == "on"
        }
        return equippedItem(item.category)?.id == item.id
    }

    func equip(_ item: CosmeticItem) {
        guard isOwned(item) else { return }
        if item.category.isToggle {
            user.cosmetics.equipped[item.id] = isEquipped(item) ? nil : "on"
            // Only one ambient sound at a time.
            if item.id != "reader.dropcaps", user.cosmetics.equipped[item.id] == "on" {
                for other in CrownCatalog.reader where other.id != item.id && other.id != "reader.dropcaps" {
                    user.cosmetics.equipped[other.id] = nil
                }
            }
        } else {
            user.cosmetics.equipped[item.category.rawValue] = item.id
        }
        applyCosmetics()
        saveToLocalStorage()
    }

    /// Before crowns, borders and themes were chosen by toggling perks in Profile
    /// (activeProfileBorder / activeTheme). Carry those choices over once.
    private func migrateLegacyCosmetics() {
        if user.cosmetics.equipped[CosmeticCategory.frame.rawValue] == nil,
           !user.activeProfileBorder.isEmpty, CrownCatalog.item(user.activeProfileBorder) != nil {
            user.cosmetics.equipped[CosmeticCategory.frame.rawValue] = user.activeProfileBorder
        }
        if user.cosmetics.equipped[CosmeticCategory.theme.rawValue] == nil, user.activeTheme.hasPrefix("theme-") {
            let id = "theme." + user.activeTheme.replacingOccurrences(of: "theme-", with: "")
            if CrownCatalog.item(id) != nil { user.cosmetics.equipped[CosmeticCategory.theme.rawValue] = id }
        }
    }

    /// Pushes equipped cosmetics to the systems that render them.
    func applyCosmetics() {
        migrateLegacyCosmetics()
        // Profile frame keeps using the existing activeProfileBorder field.
        user.activeProfileBorder = equippedItem(.frame)?.value ?? ""
        user.activeTheme = equippedItem(.theme)?.value ?? "classic"

        UserDefaults.standard.set(equippedItem(.highlight)?.value ?? "classic", forKey: HighlightPalette.defaultsKey)
        UserDefaults.standard.set(equippedItem(.verseCard)?.value ?? "classic", forKey: VerseCardStyle.defaultsKey)
        UserDefaults.standard.set(isReaderExtraOn("reader.dropcaps"), forKey: ReaderCosmetics.illuminatedCapitalsKey)

        let shared = UserDefaults(suiteName: "group.com.reforged.app")
        shared?.set(equippedItem(.widget)?.value ?? "classic", forKey: "widget_style")
        WidgetReload.all()
    }

    /// Theme is applied separately (it rebuilds the root view), so callers can
    /// choose when — e.g. after the shop sheet has dismissed.
    func applyEquippedTheme() {
        let paletteID = equippedItem(.theme)?.value ?? "classic"
        if ThemeManager.shared.palette.id != paletteID {
            ThemeManager.shared.palette = ThemePalette.named(paletteID)
        }
    }

    var isReaderExtraOn: (String) -> Bool {
        { id in self.user.cosmetics.equipped[id] == "on" && self.user.cosmetics.owned.contains(id) }
    }
}

enum WidgetReload {
    static func all() { WidgetCenter.shared.reloadAllTimelines() }
}

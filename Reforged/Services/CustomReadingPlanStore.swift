import Foundation

/// Stores member-built reading plans and bridges them into the existing reading
/// plan machinery.
///
/// Custom plans persist as lightweight `CustomReadingPlanSpec` values (UserDefaults
/// JSON) and are rebuilt into `BibleReadingPlan`s on demand via
/// `BibleReadingPlans.custom`. Because a rebuilt plan keeps the spec's `id`, it
/// flows through `ReadingPlanService` (progress, auto-completion) and
/// `ReadingPlansView` with no special-casing.
@MainActor
final class CustomReadingPlanStore: ObservableObject {
    static let shared = CustomReadingPlanStore()

    nonisolated static let storageKey = "reforged_custom_reading_plans"

    @Published private(set) var specs: [CustomReadingPlanSpec] = []

    private init() {
        specs = Self.loadSpecs()
    }

    /// Non-isolated read of the raw specs, so `BibleReadingPlans.custom` (which can
    /// be reached from `ReadingPlanService` off the main actor) never has to hop
    /// actors. UserDefaults is thread-safe for this.
    nonisolated static func loadSpecs() -> [CustomReadingPlanSpec] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CustomReadingPlanSpec].self, from: data) else {
            return []
        }
        return decoded
    }

    func add(_ spec: CustomReadingPlanSpec) {
        specs.append(spec)
        persist()
    }

    func delete(id: String) {
        specs.removeAll { $0.id == id }
        // Drop any tracked progress for the removed plan so it doesn't linger.
        ReadingPlanService.shared.resetPlan(id)
        persist()
    }

    func spec(withId id: String) -> CustomReadingPlanSpec? {
        specs.first { $0.id == id }
    }

    func deleteAll() {
        specs = []
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(specs) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - Bridge into BibleReadingPlan

extension BibleReadingPlan {
    /// Rebuilds a runtime plan from a saved custom spec.
    init(spec: CustomReadingPlanSpec) {
        self.init(
            id: spec.id,
            name: spec.name,
            description: spec.planDescription,
            iconName: spec.iconName,
            accentColor: spec.accent.color(nil),
            entries: spec.entries.map {
                BiblePlanEntry(planId: spec.id,
                               day: $0.day,
                               scriptureReference: $0.reference,
                               refinementPrompt: $0.prompt)
            },
            isDevotional: false
        )
    }
}

extension BibleReadingPlans {
    /// All member-built plans, rebuilt from saved specs.
    static var custom: [BibleReadingPlan] {
        CustomReadingPlanStore.loadSpecs().map(BibleReadingPlan.init(spec:))
    }

    /// Built-in plans plus every custom plan — the full set to enumerate and to
    /// resolve a plan id against.
    static var everything: [BibleReadingPlan] {
        all + custom
    }
}

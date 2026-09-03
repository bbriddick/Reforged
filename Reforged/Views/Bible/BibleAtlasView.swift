import SwiftUI
import MapKit

/// Interactive Bible Atlas — an offline gazetteer of ~1,300 places from openbible.info's
/// Bible Geocoding data (CC-BY), plotted on a map. Tapping a place lists the verses that
/// mention it, each of which opens the reader. Map tiles require a network connection; the
/// searchable place list works offline regardless.
struct BibleAtlasView: View {
    /// Optional place to center on when opened from a verse's "Places" section.
    var focusPlaceID: String? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 31.7, longitude: 35.2),
        span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
    )
    @State private var query = ""
    @State private var selectedPlace: BiblePlace?

    /// Cap plotted markers for legibility/performance: the most-referenced places by default,
    /// or every name match while searching.
    private let defaultMarkerCount = 140

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var visiblePlaces: [BiblePlace] {
        let all = BiblePlaceService.shared.allPlaces
        if trimmedQuery.isEmpty {
            return Array(all.sorted { $0.verses.count > $1.verses.count }.prefix(defaultMarkerCount))
        }
        return all.filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Map(coordinateRegion: $region,
                    interactionModes: .all,
                    annotationItems: visiblePlaces) { place in
                    MapAnnotation(coordinate: place.coordinate) {
                        marker(for: place)
                    }
                }
                .ignoresSafeArea(edges: .bottom)

                searchBar
            }
            .navigationTitle("Bible Atlas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .sheet(item: $selectedPlace) { place in
                PlaceDetailSheet(place: place, onNavigate: { dismiss() })
                    .presentationDetents([.medium, .large])
            }
            .onAppear(perform: focusIfNeeded)
        }
    }

    private func marker(for place: BiblePlace) -> some View {
        Button { selectedPlace = place } label: {
            VStack(spacing: 2) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.reforgedGold)
                    .background(Circle().fill(.white).padding(3))
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                if !trimmedQuery.isEmpty || place.verses.count >= 25 {
                    Text(place.name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill(.ultraThinMaterial))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            TextField("Search places", text: $query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func focusIfNeeded() {
        guard let focusPlaceID, let place = BiblePlaceService.shared.place(id: focusPlaceID) else { return }
        region = MKCoordinateRegion(
            center: place.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)
        )
        selectedPlace = place
    }
}

/// Bottom sheet for a tapped place: name plus the verses that mention it, each tappable.
struct PlaceDetailSheet: View {
    let place: BiblePlace
    /// Called after a verse is chosen, so the presenter can dismiss the atlas.
    var onNavigate: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = SettingsManager.shared

    @State private var insight: PlaceInsight?
    @State private var isLoadingInsight = false
    @State private var insightFailed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.title3).bold()
                            .foregroundStyle(Color.reforgedGold)
                        Text(String(format: "%.4f, %.4f", place.lat, place.lon))
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }

                    if settings.aiEnabled {
                        aboutSection
                    }

                    if place.verses.isEmpty {
                        Text("No verse references recorded for this place.")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    } else {
                        Text("Mentioned in")
                            .font(.caption).bold()
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        FlowLayout(spacing: 6, lineSpacing: 6) {
                            ForEach(place.verses, id: \.self) { reference in
                                Button { navigate(to: reference) } label: {
                                    Text(reference)
                                        .font(.caption).fontWeight(.medium)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(Color.adaptiveChipBackground(colorScheme))
                                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .task { await loadInsight() }
        }
    }

    // MARK: - About this place (AI + commentary grounded)

    @ViewBuilder
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption.bold())
                    .foregroundStyle(Color.reforgedGold)
                Text("About this place")
                    .font(.caption).bold()
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            if isLoadingInsight {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Gathering study details…")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            } else if insightFailed {
                Button {
                    Task { await loadInsight(force: true) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Couldn't load details — tap to try again")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.reforgedGold)
                }
                .buttonStyle(.plain)
            } else if let insight {
                Text(insight.overview)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                if !insight.significance.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(insight.significance, id: \.self) { fact in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 5))
                                    .foregroundStyle(Color.reforgedGold)
                                    .padding(.top, 6)
                                Text(fact)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if !insight.studyPrompt.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(Color.reforgedGold)
                        Text(insight.studyPrompt)
                            .font(.footnote)
                            .italic()
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.reforgedGold.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Text("AI-assisted overview. Verify significant details against Scripture.")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.7))
            }
        }
    }

    private func loadInsight(force: Bool = false) async {
        guard settings.aiEnabled else { return }
        guard force || (insight == nil && !isLoadingInsight) else { return }
        isLoadingInsight = true
        insightFailed = false
        do {
            insight = try await GeminiService.shared.generatePlaceInsight(
                name: place.name,
                verses: place.verses,
                commentaryContext: commentaryContext()
            )
        } catch {
            insightFailed = true
        }
        isLoadingInsight = false
    }

    /// Pulls a little on-device commentary text from the place's first verses to
    /// ground the AI overview in the historic commentators, when the user has them.
    private func commentaryContext() -> String {
        var blocks: [String] = []
        for reference in place.verses.prefix(3) {
            for entry in CommentaryService.shared.entries(for: reference).prefix(2) {
                let snippet = entry.text.prefix(400)
                blocks.append("[\(reference) — \(entry.source.displayName)] \(snippet)")
            }
            if blocks.count >= 4 { break }
        }
        return blocks.joined(separator: "\n\n")
    }

    private func navigate(to reference: String) {
        NotificationCenter.default.post(
            name: .navigateToBibleVerse,
            object: nil,
            userInfo: [
                AppNotificationUserInfoKey.reference: reference,
                AppNotificationUserInfoKey.translation: settings.defaultTranslation.rawValue
            ]
        )
        dismiss()
        onNavigate()
    }
}

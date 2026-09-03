import SwiftUI

/// A radial "connections" diagram for a verse's cross references — the native counterpart
/// to openbible.info's cross-reference arc visualization (lab #10), built entirely on the
/// already-bundled `CrossReferences.json` (no network, no new data).
///
/// The center node is the current verse; spokes fan out to its top cross references, with
/// line weight scaled by each reference's vote count (`CrossReferenceEntry.votes`, already
/// sorted descending by `CrossReferenceService`). Tapping a node selects that reference.
struct CrossReferenceMapView: View {
    let sourceReference: String
    let entries: [CrossReferenceEntry]
    /// Called with the tapped cross reference (canonical "Book C:V").
    let onSelect: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme

    /// Cap the fan-out so the diagram stays legible and tap targets stay large.
    private var topEntries: [CrossReferenceEntry] { Array(entries.prefix(8)) }
    private var maxVotes: Int { topEntries.map(\.votes).max() ?? 1 }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size / 2 - 46

            ZStack {
                // Spokes, weighted by votes.
                Canvas { context, _ in
                    for (index, entry) in topEntries.enumerated() {
                        let point = nodePoint(index: index, count: topEntries.count,
                                              center: center, radius: radius)
                        var path = Path()
                        path.move(to: center)
                        path.addLine(to: point)
                        let weight = CGFloat(entry.votes) / CGFloat(maxVotes)
                        context.stroke(
                            path,
                            with: .color(Color.reforgedGold.opacity(0.25 + 0.55 * weight)),
                            lineWidth: 1 + 4 * weight
                        )
                    }
                }

                // Outer cross-reference nodes.
                ForEach(Array(topEntries.enumerated()), id: \.element.reference) { index, entry in
                    let point = nodePoint(index: index, count: topEntries.count,
                                          center: center, radius: radius)
                    Button { onSelect(entry.reference) } label: {
                        nodeLabel(entry.reference, votes: entry.votes)
                    }
                    .buttonStyle(.plain)
                    .position(point)
                }

                // Center (current verse) node.
                centerLabel
                    .position(center)
            }
        }
        .frame(height: 320)
        .accessibilityLabel("Cross reference map for \(sourceReference)")
    }

    private func nodePoint(index: Int, count: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        guard count > 0 else { return center }
        let angle = (2 * Double.pi * Double(index) / Double(count)) - Double.pi / 2
        return CGPoint(x: center.x + radius * CGFloat(cos(angle)),
                       y: center.y + radius * CGFloat(sin(angle)))
    }

    private var centerLabel: some View {
        Text(sourceReference)
            .font(.caption).bold()
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy)
            )
    }

    private func nodeLabel(_ reference: String, votes: Int) -> some View {
        VStack(spacing: 2) {
            Text(reference)
                .font(.caption2).bold()
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text("\(votes)")
                .font(.system(size: 9))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.adaptiveCardBackground(colorScheme))
        .overlay(
            Capsule().stroke(Color.reforgedGold.opacity(0.5), lineWidth: 1)
        )
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .fixedSize()
    }
}

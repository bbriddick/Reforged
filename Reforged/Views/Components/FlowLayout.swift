import SwiftUI

// MARK: - Flow Layout (shared component)

/// A layout that arranges views in a flowing, word-wrap style.
/// Used by MemoryPracticeView (word chips) and WordTappableVerseText (word-level tap targets).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Always use the actual bounds width for placement so words wrap
        // correctly even if sizeThatFits was called with an unconstrained proposal.
        let constrainedProposal = ProposedViewSize(width: bounds.width, height: proposal.height)
        let result = arrange(proposal: constrainedProposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        // Guard against nil or infinite width (can occur during SwiftUI's measurement
        // pass inside a ScrollView). Fall back to the device screen width so words
        // always wrap rather than running off-screen.
        let rawWidth = proposal.width ?? UIScreen.main.bounds.width
        let maxWidth = rawWidth.isFinite ? rawWidth : UIScreen.main.bounds.width
        let verticalGap = lineSpacing ?? spacing
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + verticalGap
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

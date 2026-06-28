import SwiftUI

// MARK: - Flow Layout (shared component)

/// A layout that arranges views in a flowing, word-wrap style.
/// Used by MemoryPracticeView (word chips) and WordTappableVerseText (word-level tap targets).
/// Set `isRTL = true` for Hebrew/Arabic text so words flow right-to-left and wrap RTL.
///
/// Performance: a verse paragraph can be hundreds of word subviews, and SwiftUI calls into the
/// layout repeatedly while scrolling. To keep scrolling smooth we measure each subview's intrinsic
/// size ONCE (in `makeCache`/`updateCache`) and then only re-run the cheap line-breaking math when
/// the proposed width actually changes — instead of calling `subview.sizeThatFits` for every word on
/// every layout pass (which previously happened twice per pass, in both `sizeThatFits` and
/// `placeSubviews`).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat?
    var isRTL: Bool = false

    /// Per-instance layout cache: intrinsic subview sizes (measured once) plus the most recent
    /// arrangement, memoized by the width it was computed for.
    struct Cache {
        var sizes: [CGSize]
        var arrangedWidth: CGFloat = -1
        var result: (size: CGSize, positions: [CGPoint]) = (.zero, [])
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(sizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        // Subview set/content changed — re-measure and invalidate the arrangement.
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        cache.arrangedWidth = -1
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        arrange(width: resolvedWidth(proposal.width), cache: &cache)
        return cache.result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        // Always use the actual bounds width for placement so words wrap correctly even if
        // sizeThatFits was called with an unconstrained proposal.
        arrange(width: bounds.width, cache: &cache)
        for (index, position) in cache.result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    // MARK: - Width resolution

    /// Guard against nil or infinite width (can occur during SwiftUI's measurement pass inside a
    /// ScrollView). Fall back to the app window width so words always wrap rather than running off.
    private func resolvedWidth(_ proposed: CGFloat?) -> CGFloat {
        let raw = proposed ?? AppWindow.width
        return raw.isFinite ? raw : AppWindow.width
    }

    // MARK: - Arrangement (memoized by width)

    /// Recomputes line-breaking only when `width` differs from the last arrangement. Pure math over
    /// the cached intrinsic sizes — no subview measurement.
    private func arrange(width: CGFloat, cache: inout Cache) {
        guard cache.arrangedWidth != width else { return }
        cache.arrangedWidth = width
        cache.result = isRTL
            ? arrangeRTL(maxWidth: width, sizes: cache.sizes)
            : arrangeLTR(maxWidth: width, sizes: cache.sizes)
    }

    // MARK: - LTR arrangement (default)

    private func arrangeLTR(maxWidth: CGFloat, sizes: [CGSize]) -> (size: CGSize, positions: [CGPoint]) {
        let verticalGap = lineSpacing ?? spacing
        var positions: [CGPoint] = []
        positions.reserveCapacity(sizes.count)
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for size in sizes {
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

    // MARK: - RTL arrangement (Hebrew/Arabic)

    /// Places words right-to-left. The first word sits at the far right; each subsequent
    /// word is placed to its left. When a line is full the next line starts at the far right.
    private func arrangeRTL(maxWidth: CGFloat, sizes: [CGSize]) -> (size: CGSize, positions: [CGPoint]) {
        let verticalGap = lineSpacing ?? spacing
        var positions: [CGPoint] = []
        positions.reserveCapacity(sizes.count)
        var currentX: CGFloat = maxWidth   // cursor starts at right edge
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for size in sizes {
            // Wrap to new line when the word doesn't fit (and we're not at the line start)
            if currentX - size.width < 0 && currentX < maxWidth {
                currentX = maxWidth
                currentY += lineHeight + verticalGap
                lineHeight = 0
            }

            // Place word so its right edge aligns with cursor
            let xPos = max(0, currentX - size.width)
            positions.append(CGPoint(x: xPos, y: currentY))
            currentX -= size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

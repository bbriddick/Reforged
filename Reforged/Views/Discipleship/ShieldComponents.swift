import SwiftUI

// MARK: - Shield UI Components
//
// Shared building blocks for the Focus & Purity Shield screens.
//
// The shield accumulated a lot of settings, and rendering each as its own
// full-weight card turned the screen into an undifferentiated wall of white
// rectangles — nothing told you what mattered. These give it hierarchy:
// a quiet eyebrow label, ONE grouped card per section, and compact rows inside
// it. Config lives in rows that push to detail screens; only live state and the
// urgent action get full-card weight.
//
// Colour semantics across the shield (Theme.swift trap: `reforgedNavy` is
// #333333 charcoal, so it disappears as an accent on dark cards — use the
// adaptive helpers for anything neutral):
//   green  → protected / on
//   coral  → needs attention / off / destructive
//   gold   → the protected-days streak & Scripture

// MARK: - Section Label

/// Small uppercase eyebrow above a group — mirrors the Discipleship hub's
/// `sectionLabel` so the two screens read as one family.
struct ShieldSectionLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .tracking(1.0)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.bottom, -6)
    }
}

// MARK: - Section Card

/// Groups rows into a single card with hairline dividers, instead of N floating
/// cards each carrying its own shadow.
struct ShieldSectionCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 8, y: 3)
    }
}

/// Hairline between rows, inset past the icon so it reads as a group.
struct ShieldRowDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(Color.adaptiveTextSecondary(colorScheme).opacity(0.12))
            .frame(height: 0.5)
            .padding(.leading, 56)
    }
}

// MARK: - Row Icon

/// Compact 32pt badge — the old 50pt circles were card-sized and far too heavy
/// once several sat in a list together.
struct ShieldRowIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.14))
                .frame(width: 32, height: 32)
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Rows

/// A row with a trailing value + chevron that pushes to a detail screen.
struct ShieldNavRow<Destination: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let color: Color
    let title: String
    var value: String? = nil
    /// Tints the value (e.g. coral for "Not set") to flag it needs attention.
    var valueColor: Color? = nil
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 12) {
                ShieldRowIcon(systemName: icon, color: color)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Spacer(minLength: 8)

                if let value {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(valueColor ?? Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A row that runs an action (no push) — same metrics as `ShieldNavRow`.
struct ShieldButtonRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let color: Color
    let title: String
    var value: String? = nil
    var valueColor: Color? = nil
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.buttonTap()
            action()
        } label: {
            HStack(spacing: 12) {
                ShieldRowIcon(systemName: icon, color: color)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Spacer(minLength: 8)

                if let value {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(valueColor ?? Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A row with a trailing toggle. Shows a lock glyph when the accountability PIN
/// guards turning it off.
struct ShieldToggleRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let color: Color
    let title: String
    var detail: String? = nil
    var locked: Bool = false
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            ShieldRowIcon(systemName: icon, color: color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if locked && isOn {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .accessibilityHidden(true)
            }

            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    HapticManager.shared.selectionChanged()
                    isOn = newValue
                }
            ))
            .labelsHidden()
            .tint(Color.reforgedGold)
            .accessibilityLabel(title)
            .accessibilityHint(locked ? "Locked by accountability PIN." : (detail ?? ""))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

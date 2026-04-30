import SwiftUI
import UIKit

// MARK: - Formatting Coordinator

final class FormattingCoordinator: NSObject, ObservableObject, UITextViewDelegate {
    weak var textView: UITextView?
    var attributedTextBinding: Binding<NSAttributedString>?

    @Published var isBold = false
    @Published var isItalic = false
    @Published var isUnderline = false

    // MARK: UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        attributedTextBinding?.wrappedValue = textView.attributedText ?? NSAttributedString()
        updateActiveStates(in: textView)
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        updateActiveStates(in: textView)
    }

    private func updateActiveStates(in tv: UITextView) {
        let range = tv.selectedRange
        let text = tv.attributedText ?? NSAttributedString()

        let attrs: [NSAttributedString.Key: Any]
        if text.length == 0 || range.location == 0 {
            attrs = tv.typingAttributes
        } else {
            let loc = range.length > 0 ? range.location : max(0, range.location - 1)
            guard loc < text.length else { attrs = tv.typingAttributes; return evaluateAttrs(attrs) }
            attrs = text.attributes(at: loc, effectiveRange: nil)
        }
        evaluateAttrs(attrs)
    }

    private func evaluateAttrs(_ attrs: [NSAttributedString.Key: Any]) {
        if let font = attrs[.font] as? UIFont {
            isBold   = font.fontDescriptor.symbolicTraits.contains(.traitBold)
            isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
        }
        isUnderline = (attrs[.underlineStyle] as? Int ?? 0) != 0
    }

    // MARK: Format Actions

    func applyBold()      { toggleTrait(.traitBold) }
    func applyItalic()    { toggleTrait(.traitItalic) }
    func applyUnderline() { toggleUnderlineStyle() }
    func insertBullet()   { insertListPrefix("• ") }

    func insertNumbered() {
        guard let tv = textView else { return }
        let text = tv.text ?? ""
        let loc = tv.selectedRange.location
        let nsText = text as NSString
        var lineStart = loc
        while lineStart > 0 && nsText.character(at: lineStart - 1) != 10 { lineStart -= 1 }

        var num = 1
        var pos = 0
        while pos < lineStart {
            let searchRange = NSRange(location: pos, length: lineStart - pos)
            let found = nsText.range(of: "\n", range: searchRange)
            if found.location == NSNotFound { break }
            let lineContent = nsText.substring(with: NSRange(location: pos, length: found.location - pos))
            if lineContent.first?.isNumber == true { num += 1 }
            pos = found.location + 1
        }
        insertListPrefix("\(num). ")
    }

    private func insertListPrefix(_ prefix: String) {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        let text = tv.text ?? ""
        let nsText = text as NSString

        var lineStart = range.location
        while lineStart > 0 && nsText.character(at: lineStart - 1) != 10 { lineStart -= 1 }

        let font = tv.font ?? UIFont.systemFont(ofSize: 17)
        let mutable = NSMutableAttributedString(attributedString: tv.attributedText ?? NSAttributedString())
        let prefixAttr = NSAttributedString(
            string: prefix,
            attributes: [.font: font, .foregroundColor: UIColor.label]
        )
        mutable.insert(prefixAttr, at: lineStart)
        tv.attributedText = mutable
        tv.selectedRange = NSRange(location: range.location + prefix.count, length: 0)
        attributedTextBinding?.wrappedValue = mutable
    }

    private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        let text  = tv.attributedText ?? NSAttributedString()

        if range.length == 0 {
            var attrs = tv.typingAttributes
            let font  = (attrs[.font] as? UIFont) ?? UIFont.systemFont(ofSize: 17)
            var traits = font.fontDescriptor.symbolicTraits
            if traits.contains(trait) { traits.remove(trait) } else { traits.insert(trait) }
            if let desc = font.fontDescriptor.withSymbolicTraits(traits) {
                attrs[.font] = UIFont(descriptor: desc, size: font.pointSize)
            }
            tv.typingAttributes = attrs
            updateActiveStates(in: tv)
            return
        }

        guard range.location + range.length <= text.length else { return }

        var allHave = true
        text.enumerateAttribute(.font, in: range, options: []) { val, _, _ in
            if let f = val as? UIFont, !f.fontDescriptor.symbolicTraits.contains(trait) { allHave = false }
        }

        let mutable = NSMutableAttributedString(attributedString: text)
        mutable.enumerateAttribute(.font, in: range, options: []) { val, sub, _ in
            let f  = (val as? UIFont) ?? UIFont.systemFont(ofSize: 17)
            var t2 = f.fontDescriptor.symbolicTraits
            if allHave { t2.remove(trait) } else { t2.insert(trait) }
            if let desc = f.fontDescriptor.withSymbolicTraits(t2) {
                mutable.addAttribute(.font, value: UIFont(descriptor: desc, size: f.pointSize), range: sub)
            }
        }
        tv.attributedText = mutable
        tv.selectedRange  = range
        attributedTextBinding?.wrappedValue = mutable
        updateActiveStates(in: tv)
    }

    private func toggleUnderlineStyle() {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        let text  = tv.attributedText ?? NSAttributedString()

        if range.length == 0 {
            var attrs = tv.typingAttributes
            let current = attrs[.underlineStyle] as? Int ?? 0
            if current != 0 { attrs.removeValue(forKey: .underlineStyle) }
            else            { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
            tv.typingAttributes = attrs
            isUnderline = !isUnderline
            return
        }

        guard range.location + range.length <= text.length else { return }

        var allHave = true
        text.enumerateAttribute(.underlineStyle, in: range, options: []) { val, _, _ in
            if (val as? Int ?? 0) == 0 { allHave = false }
        }

        let mutable = NSMutableAttributedString(attributedString: text)
        if allHave { mutable.removeAttribute(.underlineStyle, range: range) }
        else       { mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
        tv.attributedText = mutable
        tv.selectedRange  = range
        attributedTextBinding?.wrappedValue = mutable
        updateActiveStates(in: tv)
    }
}

// MARK: - UITextView Representable

struct RichTextEditorUIKitView: UIViewRepresentable {
    let coordinator: FormattingCoordinator
    @Binding var attributedText: NSAttributedString
    var baseFont: UIFont = .systemFont(ofSize: 17)

    func makeCoordinator() -> FormattingCoordinator { coordinator }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate              = coordinator
        coordinator.textView     = tv
        tv.isScrollEnabled       = false
        tv.isEditable            = true
        tv.backgroundColor       = .clear
        tv.textContainerInset    = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.font = baseFont
        tv.typingAttributes = [.font: baseFont, .foregroundColor: UIColor.label]
        if attributedText.length > 0 { tv.attributedText = attributedText }
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        coordinator.attributedTextBinding = $attributedText
        coordinator.textView = tv
        if !tv.isFirstResponder {
            if tv.attributedText != attributedText {
                tv.attributedText = attributedText.length > 0
                    ? attributedText
                    : NSAttributedString(string: "", attributes: [.font: baseFont, .foregroundColor: UIColor.label])
            }
        }
    }
}

// MARK: - Formatting Toolbar

struct FormattingToolbar: View {
    @ObservedObject var coordinator: FormattingCoordinator
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 2) {
            FormatButton(icon: "bold",      isActive: coordinator.isBold,      action: coordinator.applyBold)
            FormatButton(icon: "italic",    isActive: coordinator.isItalic,    action: coordinator.applyItalic)
            FormatButton(icon: "underline", isActive: coordinator.isUnderline, action: coordinator.applyUnderline)

            Rectangle()
                .fill(Color.adaptiveBorder(colorScheme))
                .frame(width: 1, height: 20)
                .padding(.horizontal, 4)

            FormatButton(icon: "list.bullet", isActive: false, action: coordinator.insertBullet)
            FormatButton(icon: "list.number", isActive: false, action: coordinator.insertNumbered)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.adaptiveBackground(colorScheme))
        .overlay(
            Rectangle()
                .fill(Color.adaptiveBorder(colorScheme))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

struct FormatButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isActive ? Color.reforgedNavy : Color.adaptiveTextSecondary(colorScheme))
                .frame(width: 34, height: 34)
                .background(isActive ? Color.reforgedNavy.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rich Text Editor (combined toolbar + editor)

struct RichTextEditor: View {
    @Binding var attributedText: NSAttributedString
    var placeholder: String = "Start writing..."
    var minHeight: CGFloat = 120

    @StateObject private var coordinator = FormattingCoordinator()
    @Environment(\.colorScheme) var colorScheme

    private var isEmpty: Bool {
        attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            FormattingToolbar(coordinator: coordinator)

            ZStack(alignment: .topLeading) {
                RichTextEditorUIKitView(
                    coordinator: coordinator,
                    attributedText: $attributedText
                )
                .frame(minHeight: minHeight)
                .padding(12)

                if isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.5))
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                }
            }
        }
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }
}

// MARK: - NSAttributedString helpers

extension NSAttributedString {
    static func from(_ text: String, font: UIFont = .systemFont(ofSize: 17)) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: UIColor.label
        ])
    }
}

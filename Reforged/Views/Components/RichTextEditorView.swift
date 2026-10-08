import SwiftUI
import UIKit

// MARK: - Paragraph Styles

/// Named block styles offered by the editor (Apple Notes-like).
enum NoteParagraphStyle: String, CaseIterable, Identifiable {
    case title
    case heading
    case subheading
    case body

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .title:      return "Title"
        case .heading:    return "Heading"
        case .subheading: return "Subheading"
        case .body:       return "Body"
        }
    }

    var pointSize: CGFloat {
        switch self {
        case .title:      return 26
        case .heading:    return 21
        case .subheading: return 18
        case .body:       return 17
        }
    }

    var weight: UIFont.Weight {
        switch self {
        case .title:      return .bold
        case .heading:    return .semibold
        case .subheading: return .semibold
        case .body:       return .regular
        }
    }

    var font: UIFont {
        UIFont.systemFont(ofSize: pointSize, weight: weight)
    }

    /// Best-effort classification of an existing font back into a style.
    static func from(font: UIFont?) -> NoteParagraphStyle {
        guard let font else { return .body }
        let size = font.pointSize
        let isBoldish = font.fontDescriptor.symbolicTraits.contains(.traitBold)
        if size >= 24 { return .title }
        if size >= 20 && isBoldish { return .heading }
        if size >= 18 && isBoldish { return .subheading }
        return .body
    }
}

/// Text colors offered by the editor's color menu.
enum NoteTextColor: String, CaseIterable, Identifiable {
    case standard
    case coral
    case gold
    case blue
    case green
    case purple

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Default"
        case .coral:    return "Coral"
        case .gold:     return "Gold"
        case .blue:     return "Blue"
        case .green:    return "Green"
        case .purple:   return "Purple"
        }
    }

    var uiColor: UIColor {
        switch self {
        case .standard: return .label
        case .coral:    return UIColor(red: 0.914, green: 0.271, blue: 0.376, alpha: 1)
        case .gold:     return UIColor(red: 0.72, green: 0.53, blue: 0.30, alpha: 1)
        case .blue:     return UIColor(red: 0.20, green: 0.48, blue: 0.86, alpha: 1)
        case .green:    return UIColor(red: 0.16, green: 0.60, blue: 0.36, alpha: 1)
        case .purple:   return UIColor(red: 0.52, green: 0.36, blue: 0.80, alpha: 1)
        }
    }

    var swatch: Color { Color(uiColor) }
}

// MARK: - Checklist glyphs

private enum Checklist {
    static let unchecked = "☐ "
    static let checked = "☑ "
    static func isPrefix(_ line: String) -> Bool {
        line.hasPrefix(unchecked) || line.hasPrefix(checked)
    }
}

// MARK: - Formatting Coordinator

final class FormattingCoordinator: NSObject, ObservableObject, UITextViewDelegate, UIGestureRecognizerDelegate {
    weak var textView: UITextView?
    var attributedTextBinding: Binding<NSAttributedString>?

    @Published var isBold = false
    @Published var isItalic = false
    @Published var isUnderline = false
    @Published var isStrikethrough = false
    @Published var isHighlighted = false
    @Published var paragraphStyle: NoteParagraphStyle = .body

    static let highlightColor = UIColor.systemYellow.withAlphaComponent(0.35)

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
            guard loc < text.length else { evaluateAttrs(tv.typingAttributes); return }
            attrs = text.attributes(at: loc, effectiveRange: nil)
        }
        evaluateAttrs(attrs)
    }

    private func evaluateAttrs(_ attrs: [NSAttributedString.Key: Any]) {
        if let font = attrs[.font] as? UIFont {
            isBold   = font.fontDescriptor.symbolicTraits.contains(.traitBold)
            isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
            paragraphStyle = NoteParagraphStyle.from(font: font)
        }
        isUnderline = (attrs[.underlineStyle] as? Int ?? 0) != 0
        isStrikethrough = (attrs[.strikethroughStyle] as? Int ?? 0) != 0
        isHighlighted = (attrs[.backgroundColor] as? UIColor) != nil
    }

    // MARK: Format Actions

    func applyBold()      { toggleTrait(.traitBold) }
    func applyItalic()    { toggleTrait(.traitItalic) }
    func applyUnderline() { toggleAttribute(.underlineStyle) }
    func applyStrikethrough() { toggleAttribute(.strikethroughStyle) }
    func insertBullet()   { insertListPrefix("• ") }
    func insertChecklist() { insertListPrefix(Checklist.unchecked) }

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

    /// Applies a block/paragraph style to every paragraph touched by the selection.
    func applyParagraphStyle(_ style: NoteParagraphStyle) {
        guard let tv = textView else { return }
        let font = style.font

        if (tv.attributedText?.length ?? 0) == 0 || tv.selectedRange.length == 0 {
            // No selection: set typing attributes so new text uses the style, and
            // also restyle the current line if it has content.
            var typing = tv.typingAttributes
            typing[.font] = font
            tv.typingAttributes = typing
            let lineRange = currentParagraphRange(in: tv)
            if lineRange.length > 0 {
                applyFont(font, to: lineRange, on: tv)
            } else {
                paragraphStyle = style
            }
            HapticManager.shared.selectionChanged()
            return
        }

        let text = tv.attributedText ?? NSAttributedString()
        let ns = text.string as NSString
        let paraRange = ns.paragraphRange(for: tv.selectedRange)
        applyFont(font, to: paraRange, on: tv)
        HapticManager.shared.selectionChanged()
    }

    func applyTextColor(_ color: NoteTextColor) {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        if range.length == 0 {
            var typing = tv.typingAttributes
            typing[.foregroundColor] = color.uiColor
            tv.typingAttributes = typing
            return
        }
        let mutable = NSMutableAttributedString(attributedString: tv.attributedText ?? NSAttributedString())
        guard range.location + range.length <= mutable.length else { return }
        mutable.addAttribute(.foregroundColor, value: color.uiColor, range: range)
        tv.attributedText = mutable
        tv.selectedRange = range
        attributedTextBinding?.wrappedValue = mutable
    }

    func toggleHighlight() {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        if range.length == 0 {
            var typing = tv.typingAttributes
            if typing[.backgroundColor] != nil {
                typing.removeValue(forKey: .backgroundColor)
                isHighlighted = false
            } else {
                typing[.backgroundColor] = Self.highlightColor
                isHighlighted = true
            }
            tv.typingAttributes = typing
            return
        }
        guard range.location + range.length <= (tv.attributedText?.length ?? 0) else { return }
        var allHave = true
        tv.attributedText.enumerateAttribute(.backgroundColor, in: range, options: []) { val, _, _ in
            if val == nil { allHave = false }
        }
        let mutable = NSMutableAttributedString(attributedString: tv.attributedText ?? NSAttributedString())
        if allHave { mutable.removeAttribute(.backgroundColor, range: range) }
        else       { mutable.addAttribute(.backgroundColor, value: Self.highlightColor, range: range) }
        tv.attributedText = mutable
        tv.selectedRange = range
        attributedTextBinding?.wrappedValue = mutable
        updateActiveStates(in: tv)
    }

    // MARK: Helpers

    private func applyFont(_ font: UIFont, to range: NSRange, on tv: UITextView) {
        let mutable = NSMutableAttributedString(attributedString: tv.attributedText ?? NSAttributedString())
        guard range.location + range.length <= mutable.length else { return }
        // Preserve bold/italic emphasis already present on runs where possible,
        // but base the size/weight on the chosen style.
        mutable.addAttribute(.font, value: font, range: range)
        tv.attributedText = mutable
        tv.selectedRange = range
        attributedTextBinding?.wrappedValue = mutable
        updateActiveStates(in: tv)
    }

    private func currentParagraphRange(in tv: UITextView) -> NSRange {
        let ns = (tv.text ?? "") as NSString
        return ns.paragraphRange(for: tv.selectedRange)
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

    /// Toggles a simple integer-valued attribute (underline / strikethrough).
    private func toggleAttribute(_ attribute: NSAttributedString.Key) {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        let text  = tv.attributedText ?? NSAttributedString()
        let onValue = NSUnderlineStyle.single.rawValue

        if range.length == 0 {
            var attrs = tv.typingAttributes
            let current = attrs[attribute] as? Int ?? 0
            if current != 0 { attrs.removeValue(forKey: attribute) }
            else            { attrs[attribute] = onValue }
            tv.typingAttributes = attrs
            updateActiveStates(in: tv)
            return
        }

        guard range.location + range.length <= text.length else { return }

        var allHave = true
        text.enumerateAttribute(attribute, in: range, options: []) { val, _, _ in
            if (val as? Int ?? 0) == 0 { allHave = false }
        }

        let mutable = NSMutableAttributedString(attributedString: text)
        if allHave { mutable.removeAttribute(attribute, range: range) }
        else       { mutable.addAttribute(attribute, value: onValue, range: range) }
        tv.attributedText = mutable
        tv.selectedRange  = range
        attributedTextBinding?.wrappedValue = mutable
        updateActiveStates(in: tv)
    }

    // MARK: Checklist tap-to-toggle

    @objc func handleCheckboxTap(_ recognizer: UITapGestureRecognizer) {
        guard let tv = textView, let attr = tv.attributedText else { return }
        let point = recognizer.location(in: tv)
        let layout = tv.layoutManager
        let container = tv.textContainer
        let adjusted = CGPoint(x: point.x - tv.textContainerInset.left,
                               y: point.y - tv.textContainerInset.top)
        var fraction: CGFloat = 0
        let index = layout.characterIndex(for: adjusted, in: container, fractionOfDistanceBetweenInsertionPoints: &fraction)
        guard index < attr.length else { return }

        let ns = attr.string as NSString
        let lineRange = ns.lineRange(for: NSRange(location: index, length: 0))
        let line = ns.substring(with: lineRange)

        // Only toggle when the tap lands on the checkbox glyph at the line start.
        guard Checklist.isPrefix(line), index <= lineRange.location + 1 else { return }

        let mutable = NSMutableAttributedString(attributedString: attr)
        let isChecked = line.hasPrefix(Checklist.checked)
        let replacement = isChecked ? Checklist.unchecked : Checklist.checked
        let font = (tv.font ?? UIFont.systemFont(ofSize: 17))
        let glyphRange = NSRange(location: lineRange.location, length: 2) // glyph + space
        mutable.replaceCharacters(in: glyphRange,
                                  with: NSAttributedString(string: replacement,
                                                           attributes: [.font: font, .foregroundColor: UIColor.label]))
        let caret = tv.selectedRange
        tv.attributedText = mutable
        tv.selectedRange = caret
        attributedTextBinding?.wrappedValue = mutable
        HapticManager.shared.selectionChanged()
    }

    // Let the tap gesture coexist with the text view's own gestures.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
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
        tv.textContainer.widthTracksTextView = true
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.font = baseFont
        tv.typingAttributes = [.font: baseFont, .foregroundColor: UIColor.label]
        if attributedText.length > 0 { tv.attributedText = attributedText }

        // Tap-to-toggle checkboxes.
        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(FormattingCoordinator.handleCheckboxTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = coordinator
        tv.addGestureRecognizer(tap)
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                // Paragraph style menu
                Menu {
                    ForEach(NoteParagraphStyle.allCases) { style in
                        Button {
                            coordinator.applyParagraphStyle(style)
                        } label: {
                            Label(style.displayName,
                                  systemImage: coordinator.paragraphStyle == style ? "checkmark" : "textformat.size")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "textformat")
                            .font(.system(size: 14, weight: .medium))
                        Text(coordinator.paragraphStyle.displayName)
                            .font(.caption.weight(.medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(Color.reforgedNavy.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                toolbarDivider

                FormatButton(icon: "bold",          isActive: coordinator.isBold,          action: coordinator.applyBold)
                FormatButton(icon: "italic",        isActive: coordinator.isItalic,        action: coordinator.applyItalic)
                FormatButton(icon: "underline",     isActive: coordinator.isUnderline,     action: coordinator.applyUnderline)
                FormatButton(icon: "strikethrough", isActive: coordinator.isStrikethrough, action: coordinator.applyStrikethrough)

                toolbarDivider

                FormatButton(icon: "highlighter", isActive: coordinator.isHighlighted, action: coordinator.toggleHighlight)

                // Text color menu
                Menu {
                    ForEach(NoteTextColor.allCases) { color in
                        Button {
                            coordinator.applyTextColor(color)
                        } label: {
                            Label(color.displayName, systemImage: "circle.fill")
                        }
                    }
                } label: {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .frame(width: 34, height: 34)
                }

                toolbarDivider

                FormatButton(icon: "list.bullet",       isActive: false, action: coordinator.insertBullet)
                FormatButton(icon: "list.number",       isActive: false, action: coordinator.insertNumbered)
                FormatButton(icon: "checklist",         isActive: false, action: coordinator.insertChecklist)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .background(Color.adaptiveBackground(colorScheme))
        .overlay(
            Rectangle()
                .fill(Color.adaptiveBorder(colorScheme))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.adaptiveBorder(colorScheme))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 4)
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
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
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

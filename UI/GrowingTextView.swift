import AppKit
import SwiftUI

/// Многострочное поле на NSTextView: растёт по содержимому, без фона,
/// Return / Backspace / Tab отдаёт наружу. SwiftUI-`TextField(axis: .vertical)`
/// в списке на macOS не растёт и рисует белый фон при фокусе.
struct GrowingTextView<Field: Hashable>: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: NSFont
    var color: NSColor
    var field: Field
    @Binding var focus: Field?
    var onReturn: () -> Void = {}
    var onBackspaceEmpty: () -> Void = {}
    var onTab: (() -> Void)?
    var onBacktab: (() -> Void)?
    /// Стрелки: срабатывают только с последней (вниз) или первой (вверх) строки текста.
    var onArrowDown: (() -> Void)?
    var onArrowUp: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> AutoTextView {
        let view = AutoTextView()
        view.delegate = context.coordinator
        view.isRichText = false
        view.allowsUndo = true
        view.drawsBackground = false
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.textContainerInset = NSSize(width: 0, height: 2)
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.isHorizontallyResizable = false
        view.isVerticallyResizable = true
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        apply(to: view)
        return view
    }

    func updateNSView(_ view: AutoTextView, context: Context) {
        context.coordinator.parent = self
        apply(to: view)
        if view.string != text {
            let selection = view.selectedRange()
            view.string = text
            let clamped = min(selection.location, (text as NSString).length)
            view.setSelectedRange(NSRange(location: clamped, length: 0))
            view.invalidateIntrinsicContentSize()
        }
        if focus == field, let window = view.window, window.firstResponder !== view, !context.coordinator.isResigning {
            DispatchQueue.main.async { window.makeFirstResponder(view) }
        }
    }

    private func apply(to view: AutoTextView) {
        view.font = font
        view.textColor = color
        view.insertionPointColor = color
        view.placeholder = placeholder
        view.placeholderColor = color.withAlphaComponent(0.35)
        view.typingAttributes = [.font: font, .foregroundColor: color]
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: GrowingTextView
        var isResigning = false

        init(_ parent: GrowingTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? AutoTextView else { return }
            parent.text = view.string
        }

        func textDidBeginEditing(_ notification: Notification) {
            let field = parent.field
            DispatchQueue.main.async { [self] in
                if parent.focus != field { parent.focus = field }
            }
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                parent.onReturn()
                return true
            case #selector(NSResponder.deleteBackward(_:)):
                guard textView.string.isEmpty else { return false }
                parent.onBackspaceEmpty()
                return true
            case #selector(NSResponder.insertTab(_:)):
                guard let onTab = parent.onTab else { return false }
                onTab()
                return true
            case #selector(NSResponder.insertBacktab(_:)):
                guard let onBacktab = parent.onBacktab else { return false }
                onBacktab()
                return true
            case #selector(NSResponder.moveDown(_:)):
                guard let onArrowDown = parent.onArrowDown, caretOnLastLine(textView) else { return false }
                onArrowDown()
                return true
            case #selector(NSResponder.moveUp(_:)):
                guard let onArrowUp = parent.onArrowUp, caretOnFirstLine(textView) else { return false }
                onArrowUp()
                return true
            default:
                return false
            }
        }

        private func caretOnLastLine(_ textView: NSTextView) -> Bool {
            let text = textView.string as NSString
            let caret = textView.selectedRange().location
            return text.range(of: "\n", options: [], range: NSRange(location: caret, length: text.length - caret)).location == NSNotFound
        }

        private func caretOnFirstLine(_ textView: NSTextView) -> Bool {
            let text = textView.string as NSString
            let caret = min(textView.selectedRange().location, text.length)
            return text.range(of: "\n", options: [], range: NSRange(location: 0, length: caret)).location == NSNotFound
        }
    }
}

final class AutoTextView: NSTextView {
    var placeholder = "" { didSet { needsDisplay = true } }
    var placeholderColor = NSColor.placeholderTextColor

    override var intrinsicContentSize: NSSize {
        guard let container = textContainer, let manager = layoutManager else { return super.intrinsicContentSize }
        manager.ensureLayout(for: container)
        let height = manager.usedRect(for: container).height + textContainerInset.height * 2
        let fontHeight = (font?.ascender ?? 12) - (font?.descender ?? -3) + textContainerInset.height * 2
        return NSSize(width: NSView.noIntrinsicMetric, height: max(height, fontHeight))
    }

    override func setFrameSize(_ newSize: NSSize) {
        let changed = newSize.width != frame.width
        super.setFrameSize(newSize)
        if changed { invalidateIntrinsicContentSize() }
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty, let font else { return }
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: placeholderColor]
        (placeholder as NSString).draw(at: NSPoint(x: textContainerInset.width, y: textContainerInset.height), withAttributes: attributes)
    }

    // Клик по пустому месту поля тоже ставит курсор.
    override func mouseDown(with event: NSEvent) {
        if window?.firstResponder !== self { window?.makeFirstResponder(self) }
        super.mouseDown(with: event)
    }
}

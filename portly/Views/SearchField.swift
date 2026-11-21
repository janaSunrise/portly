import SwiftUI

// SwiftUI's .searchable needs a toolbar, which a menu bar panel doesn't have.
// keys go to the list while you type, like Spotlight
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    let prompt: String
    var onMove: (Int) -> Void = { _ in }
    var onSubmit: () -> Void = {}
    var onDelete: () -> Bool = { false }

    func makeNSView(context: Context) -> NSSearchField {
        let field = AutofocusSearchField()
        field.placeholderString = prompt
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchField

        init(parent: SearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveDown(_:)): parent.onMove(1); return true
            case #selector(NSResponder.moveUp(_:)): parent.onMove(-1); return true
            case #selector(NSResponder.insertNewline(_:)): parent.onSubmit(); return true
            // ⌘⌫ stops the selected row, or edits text like normal when nothing's selected
            case #selector(NSResponder.deleteToBeginningOfLine(_:)): return parent.onDelete()
            default: return false
            }
        }
    }
}

// grabs focus every time the panel opens, so you can just start typing
private final class AutofocusSearchField: NSSearchField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        guard let window else { return }
        NotificationCenter.default.addObserver(
            self, selector: #selector(focus), name: NSWindow.didBecomeKeyNotification, object: window
        )
        focus()
    }

    @objc private func focus() {
        window?.makeFirstResponder(self)
    }
}

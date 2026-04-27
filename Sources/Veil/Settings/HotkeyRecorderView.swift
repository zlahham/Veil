import SwiftUI
import AppKit
import Carbon.HIToolbox

/// An NSViewRepresentable that captures a key combination from the user.
struct HotkeyRecorderView: NSViewRepresentable {
    let onRecord: (KeyCombination) -> Void

    func makeNSView(context: Context) -> HotkeyRecorderField {
        let field = HotkeyRecorderField()
        field.onRecord = onRecord
        return field
    }

    func updateNSView(_ nsView: HotkeyRecorderField, context: Context) {}
}

final class HotkeyRecorderField: NSTextField {
    var onRecord: ((KeyCombination) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        stringValue = "Press a key..."
        isEditable = false
        isSelectable = false
        alignment = .center
        font = .systemFont(ofSize: 11)
        bezelStyle = .roundedBezel
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Grab focus immediately so the user can just type the combo.
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self)
        }
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { stringValue = "Press a key…" }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        // If we resign without having captured a combo, restore the placeholder.
        if stringValue == "Press a key…" {
            stringValue = ""
        }
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Require at least one modifier key
        guard !modifiers.isEmpty else {
            if event.keyCode == UInt16(kVK_Escape) {
                // Cancel recording
                window?.makeFirstResponder(nil)
            }
            return
        }

        let combo = KeyCombination(
            keyCode: UInt32(event.keyCode),
            modifiers: KeyCombination.carbonModifiers(from: modifiers)
        )

        stringValue = combo.displayString
        onRecord?(combo)
        window?.makeFirstResponder(nil)
    }
}

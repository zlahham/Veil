import AppKit
import Carbon.HIToolbox

/// A key combination (key code + modifier flags) for global hotkeys.
struct KeyCombination: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    /// Carbon modifier flags from Cocoa modifier flags.
    static func carbonModifiers(from cocoaFlags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if cocoaFlags.contains(.command) { carbon |= UInt32(cmdKey) }
        if cocoaFlags.contains(.option)  { carbon |= UInt32(optionKey) }
        if cocoaFlags.contains(.control) { carbon |= UInt32(controlKey) }
        if cocoaFlags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        return carbon
    }

    /// Human-readable display string.
    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("\u{2303}") }
        if modifiers & UInt32(optionKey)  != 0 { parts.append("\u{2325}") }
        if modifiers & UInt32(shiftKey)   != 0 { parts.append("\u{21E7}") }
        if modifiers & UInt32(cmdKey)     != 0 { parts.append("\u{2318}") }

        // Get the key name from the key code
        let keyName = keyNameForCode(keyCode)
        parts.append(keyName)

        return parts.joined()
    }
}

private func keyNameForCode(_ code: UInt32) -> String {
    switch Int(code) {
    case kVK_Return: return "\u{21A9}"
    case kVK_Tab: return "\u{21E5}"
    case kVK_Space: return "Space"
    case kVK_Delete: return "\u{232B}"
    case kVK_Escape: return "\u{238B}"
    case kVK_F1: return "F1"
    case kVK_F2: return "F2"
    case kVK_F3: return "F3"
    case kVK_F4: return "F4"
    case kVK_F5: return "F5"
    case kVK_F6: return "F6"
    case kVK_F7: return "F7"
    case kVK_F8: return "F8"
    case kVK_F9: return "F9"
    case kVK_F10: return "F10"
    case kVK_F11: return "F11"
    case kVK_F12: return "F12"
    case kVK_UpArrow: return "\u{2191}"
    case kVK_DownArrow: return "\u{2193}"
    case kVK_LeftArrow: return "\u{2190}"
    case kVK_RightArrow: return "\u{2192}"
    default:
        // Use the character for the key code
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "?"
        }
        let data = unsafeBitCast(layoutData, to: CFData.self) as Data
        return data.withUnsafeBytes { ptr -> String in
            guard let basePtr = ptr.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return "?"
            }
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length: Int = 0
            UCKeyTranslate(
                basePtr, UInt16(code), UInt16(kUCKeyActionDisplay), 0,
                UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState, 4, &length, &chars
            )
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
    }
}

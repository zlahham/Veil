import AppKit
import ApplicationServices

enum Permissions {
    /// Whether accessibility access has been granted.
    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user to grant accessibility access.
    /// Opens System Settings to the appropriate pane.
    static func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}

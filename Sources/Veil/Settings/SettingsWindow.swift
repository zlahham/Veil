import AppKit
import SwiftUI

/// Custom settings window managed outside SwiftUI's App lifecycle.
/// Avoids the SwiftUI Settings scene, which triggers layout crashes in some
/// configurations when combined with status items and no main window.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func show(itemStore: MenuBarItemStore) {
        if window == nil {
            let hostingController = NSHostingController(
                rootView: SettingsView(itemStore: itemStore)
            )
            let w = NSWindow(contentViewController: hostingController)
            w.title = "Veil Settings"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.setContentSize(NSSize(width: 440, height: 360))
            w.center()
            w.isReleasedWhenClosed = false
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

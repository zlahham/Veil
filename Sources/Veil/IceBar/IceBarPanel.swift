import AppKit
import SwiftUI

/// A floating panel that shows hidden menu bar items below the menu bar.
/// Created lazily and released when closed — zero memory when not in use.
@MainActor
final class IceBarPanel: NSPanel {
    private let menuBarController: MenuBarController
    private let itemStore: MenuBarItemStore

    init(menuBarController: MenuBarController, itemStore: MenuBarItemStore) {
        self.menuBarController = menuBarController
        self.itemStore = itemStore

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 336, height: 320),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: true
        )

        level = .statusBar
        isFloatingPanel = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false

        let hosting = NSHostingView(
            rootView: IceBarContentView(itemStore: itemStore)
        )
        hosting.frame = NSRect(x: 0, y: 0, width: 336, height: 320)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
    }

    func showBelow(statusItem: NSStatusItem) {
        guard let button = statusItem.button,
              let buttonWindow = button.window,
              let screen = NSScreen.main else { return }

        let buttonFrame = buttonWindow.frame
        let width: CGFloat = 336
        let height: CGFloat = 320
        var x = buttonFrame.midX - width / 2
        let y = screen.frame.maxY - screen.menuBarHeight - height - 4

        x = max(8, min(x, screen.frame.maxX - width - 8))

        setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        orderFrontRegardless()
    }

    func dismiss() {
        orderOut(nil)
    }
}

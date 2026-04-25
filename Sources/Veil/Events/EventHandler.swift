import AppKit
import os

/// Handles mouse events for show-on-hover, show-on-click, and auto-rehide.
/// All event-driven — zero CPU at idle.
@MainActor
final class EventHandler {
    private let menuBarController: MenuBarController
    private var mouseMovedMonitor: EventMonitor?
    private var mouseClickMonitor: EventMonitor?
    private var scrollMonitor: EventMonitor?
    private let logger = Logger(subsystem: "com.veil.app", category: "EventHandler")

    init(menuBarController: MenuBarController) {
        self.menuBarController = menuBarController
    }

    func install() {
        installClickMonitor()
        installHoverMonitor()
        installScrollMonitor()
        logger.info("Event monitors installed")
    }

    func uninstall() {
        mouseMovedMonitor?.stop()
        mouseClickMonitor?.stop()
        scrollMonitor?.stop()
        mouseMovedMonitor = nil
        mouseClickMonitor = nil
        scrollMonitor = nil
    }

    // MARK: - Click Monitor

    private func installClickMonitor() {
        mouseClickMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleClick(event)
        }
        mouseClickMonitor?.start()
    }

    private func handleClick(_ event: NSEvent) {
        let settings = VeilSettings.shared
        guard settings.showOnClick else { return }

        let location = NSEvent.mouseLocation
        if !isInMenuBarArea(location) {
            // Clicked outside menu bar — rehide if items are currently shown
            if !menuBarController.isItemsHidden {
                menuBarController.hide()
            }
        }
    }

    // MARK: - Hover Monitor

    private func installHoverMonitor() {
        mouseMovedMonitor = EventMonitor(mask: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved(event)
        }
        mouseMovedMonitor?.start()
    }

    private func handleMouseMoved(_ event: NSEvent) {
        let settings = VeilSettings.shared
        guard settings.showOnHover else { return }

        let location = NSEvent.mouseLocation
        if isInMenuBarArea(location) {
            if menuBarController.isItemsHidden {
                menuBarController.show()
            }
        } else if !menuBarController.isItemsHidden {
            menuBarController.scheduleRehide()
        }
    }

    // MARK: - Scroll Monitor

    private func installScrollMonitor() {
        scrollMonitor = EventMonitor(mask: .scrollWheel) { [weak self] event in
            self?.handleScroll(event)
        }
        scrollMonitor?.start()
    }

    private func handleScroll(_ event: NSEvent) {
        let settings = VeilSettings.shared
        guard settings.showOnScroll else { return }

        let location = NSEvent.mouseLocation
        guard isInMenuBarArea(location) else { return }

        // Scroll up/left to show, down/right to hide
        let delta = event.scrollingDeltaY + event.scrollingDeltaX
        if delta > 0 && menuBarController.isItemsHidden {
            menuBarController.show()
        } else if delta < 0 && !menuBarController.isItemsHidden {
            menuBarController.hide()
        }
    }

    // MARK: - Helpers

    private func isInMenuBarArea(_ point: NSPoint) -> Bool {
        guard let screen = NSScreen.main else { return false }
        return screen.menuBarFrame.contains(point)
    }
}

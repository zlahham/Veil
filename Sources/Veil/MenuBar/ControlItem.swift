import AppKit
import os

/// The single NSStatusItem Veil owns — the bolt icon in the menu bar.
///
/// When `state == .hideItems`, the item grows to `pushLength` wide (with its
/// icon pinned to the right edge) which pushes any items positioned to its
/// left off the visible menu bar. When `state == .showItems`, it shrinks back
/// to its natural width and everything reappears.
///
/// Critical gotcha: `NSStatusItem.length` alone resizes the button view but
/// not its enclosing window, so the wide button gets clipped. We also have
/// to `setFrame` the button's window (`resizeWindow`) and deactivate an
/// internal width constraint (`findAndDeactivateWidthConstraint`).
@MainActor
final class ControlItem: NSObject {
    enum State {
        case showItems
        case hideItems
    }

    /// Length of the expanded item when push-mode is active. Bounded — too
    /// wide triggers the macOS overflow handler which hides arbitrary items.
    var pushLength: CGFloat = 280

    let statusItem: NSStatusItem

    /// Internal width constraint macOS places on the button. Deactivate to
    /// allow arbitrary widths.
    private var widthConstraint: NSLayoutConstraint?

    var state: State = .hideItems {
        didSet {
            guard state != oldValue else { return }
            applyState()
        }
    }

    private let logger = Logger(subsystem: "com.veil.app", category: "ControlItem")

    init(autosaveName: String) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem.autosaveName = autosaveName
        super.init()

        configureButton()
        findAndDeactivateWidthConstraint()
        applyState()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iconChanged),
            name: .veilIconChanged,
            object: nil
        )
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    @objc private func iconChanged() {
        applyState()
    }

    // MARK: - Button

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseDown, .rightMouseUp])
        // Suppress the button's bezel + highlight. Without this, when the
        // button is in its wide push state, the click/hover highlight
        // renders as a 280px translucent bar across the menu bar.
        button.isBordered = false
        if let cell = button.cell as? NSButtonCell {
            cell.highlightsBy = []
            cell.isBordered = false
            cell.bezelStyle = .inline
        }
        // Image is set by applyState.
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            NotificationCenter.default.post(name: .veilToggleHide, object: nil)
        }
    }

    private func showContextMenu() {
        // Refresh from cache; trigger a network call only if cache is stale.
        UpdateChecker.shared.checkIfStale()

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Item List...", action: #selector(openIceBar), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(updateMenuItem())
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Veil", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        for item in menu.items where item.action != nil { item.target = self }
        menu.items.last?.target = NSApp

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func updateMenuItem() -> NSMenuItem {
        let checker = UpdateChecker.shared
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        if checker.updateAvailable, let tag = checker.latestVersion {
            let item = NSMenuItem(title: "Download \(tag)…", action: #selector(downloadUpdate), keyEquivalent: "")
            return item
        }
        let item = NSMenuItem(title: "You're on the latest (v\(current))", action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func downloadUpdate() {
        NSWorkspace.shared.open(UpdateChecker.shared.downloadURL)
    }

    @objc private func openIceBar() {
        NotificationCenter.default.post(name: .veilToggleIceBar, object: self.statusItem)
    }

    @objc private func openSettings() {
        NotificationCenter.default.post(name: .veilOpenSettings, object: nil)
    }

    // MARK: - State

    private func applyState() {
        let icon = VeilSettings.shared.iconStyle
        switch state {
        case .hideItems:
            statusItem.isVisible = true
            statusItem.length = pushLength
            statusItem.button?.image = rightAnchoredImage(symbol: icon.hiddenSymbol, width: pushLength)
            resizeWindow(to: pushLength)

        case .showItems:
            statusItem.isVisible = true
            statusItem.length = NSStatusItem.variableLength
            statusItem.button?.image = NSImage(systemSymbolName: icon.shownSymbol, accessibilityDescription: "Hide items")
            resizeWindow(to: 26)
        }
    }

    // MARK: - Width hacks

    /// Locate and deactivate the internal horizontal constraint on the button's
    /// superview — without this, macOS clamps the button to its natural width
    /// and `length = pushLength` has no visible effect.
    private func findAndDeactivateWidthConstraint() {
        guard let button = statusItem.button,
              let contentView = button.window?.contentView else {
            logger.warning("Could not access status item button window for constraint hack")
            return
        }
        for constraint in contentView.constraintsAffectingLayout(for: .horizontal) {
            if let secondItem = constraint.secondItem as? NSView, secondItem == button.superview {
                widthConstraint = constraint
                constraint.isActive = false
                return
            }
        }
        logger.warning("Width constraint not found")
    }

    /// Resize the button's enclosing window. Required in addition to setting
    /// `NSStatusItem.length` — the window otherwise clips the wide button.
    /// Right edge is anchored so the item grows leftward.
    private func resizeWindow(to width: CGFloat) {
        guard let button = statusItem.button, let window = button.window else { return }
        var frame = window.frame
        let rightEdge = frame.origin.x + frame.size.width
        frame.size.width = width
        frame.origin.x = rightEdge - width
        window.setFrame(frame, display: true)
    }

    /// Re-attempt the constraint hack. First run can happen before the button
    /// window's constraints are fully established; callers schedule a retry.
    func reapplyConstraintHack() {
        if widthConstraint == nil {
            findAndDeactivateWidthConstraint()
            applyState()
        }
    }

    // MARK: - Helpers

    /// Wide transparent image with the given SF Symbol drawn near the right
    /// edge. Used when push-mode is active so the icon visually stays next to
    /// the system tray instead of floating in the middle of the wide area.
    private func rightAnchoredImage(symbol: String, width: CGFloat) -> NSImage {
        let height: CGFloat = 22
        let symbolSize: CGFloat = 14
        let rightPadding: CGFloat = 6
        guard let symbolImage = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) else {
            return NSImage()
        }
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        let rect = NSRect(
            x: width - symbolSize - rightPadding,
            y: (height - symbolSize) / 2,
            width: symbolSize,
            height: symbolSize
        )
        symbolImage.draw(in: rect)
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

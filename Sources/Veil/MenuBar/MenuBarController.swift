import AppKit
import os

/// Owns Veil's single `ControlItem` (the bolt in the menu bar) and coordinates
/// hide/show + auto-rehide.
@MainActor
final class MenuBarController {
    private(set) var control: ControlItem!
    private let itemStore: MenuBarItemStore
    private let logger = Logger(subsystem: "com.veil.app", category: "MenuBarController")

    private var rehideTimer: Timer?

    init(itemStore: MenuBarItemStore) {
        self.itemStore = itemStore
    }

    func setup() {
        control = ControlItem(autosaveName: "Veil_main")

        // Restore last-known hide state across launches.
        if VeilSettings.shared.itemsHidden {
            control.state = .hideItems
        } else {
            control.state = .showItems
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggle),
            name: .veilToggleHide,
            object: nil
        )

        // The button's window constraints aren't always established on first
        // creation; retry the width hack after a beat.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.control.reapplyConstraintHack()
        }
    }

    // MARK: - Public API

    var isItemsHidden: Bool {
        control?.state == .hideItems
    }

    func show() {
        control?.state = .showItems
        VeilSettings.shared.itemsHidden = false
        if VeilSettings.shared.autoRehide {
            scheduleRehide()
        } else {
            cancelRehideTimer()
        }
    }

    func hide() {
        control?.state = .hideItems
        VeilSettings.shared.itemsHidden = true
    }

    func toggle() {
        if isItemsHidden {
            show()
        } else {
            hide()
        }
    }

    // MARK: - Auto-rehide

    /// Schedule a re-hide after the configured interval. Honors the
    /// `autoRehide` toggle and the user's interval setting.
    func scheduleRehide() {
        guard VeilSettings.shared.autoRehide else { return }
        let interval = VeilSettings.shared.rehideInterval
        guard interval > 0 else { return }
        cancelRehideTimer()
        rehideTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hide()
            }
        }
    }

    func cancelRehideTimer() {
        rehideTimer?.invalidate()
        rehideTimer = nil
    }

    // MARK: - Private

    @objc private func handleToggle() {
        toggle()
    }
}

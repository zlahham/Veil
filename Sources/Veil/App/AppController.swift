import AppKit
import ServiceManagement

/// Central coordinator. Owns the menu bar controller, event handler, and hotkey service.
/// Ice Bar and Settings are created lazily on demand.
@MainActor
final class AppController {
    let itemStore = MenuBarItemStore()
    lazy var menuBarController = MenuBarController(itemStore: itemStore)
    private(set) lazy var eventHandler = EventHandler(menuBarController: menuBarController)
    private(set) lazy var hotkeyService = HotkeyService()
    private var iceBarPanel: IceBarPanel?

    func start() {
        menuBarController.setup()
        eventHandler.install()
        registerHotkeys()
        syncLaunchAtLogin()

        // Populate the item list once after login so the Ice Bar has data on first open.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.itemStore.refresh()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toggleIceBar(_:)),
            name: .veilToggleIceBar,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: .veilOpenSettings,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(registerHotkeys),
            name: .veilHotkeysChanged,
            object: nil
        )
    }

    /// Reconcile our persisted `launchAtLogin` preference with the actual
    /// SMAppService state. If the user flipped it in System Settings > Login
    /// Items, we honor that on next launch.
    private func syncLaunchAtLogin() {
        let registered = SMAppService.mainApp.status == .enabled
        let wanted = VeilSettings.shared.launchAtLogin

        if registered != wanted {
            // UserDefaults is the source of truth for our UI; align OS to it.
            do {
                if wanted {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // If registration fails (unsigned builds, etc.), trust OS state.
                VeilSettings.shared.launchAtLogin = registered
            }
        }
    }

    /// Read the persisted combo and (re)register it with HotkeyService.
    /// Called at startup and whenever `.veilHotkeysChanged` fires.
    @objc private func registerHotkeys() {
        hotkeyService.unregisterAll()

        guard let data = UserDefaults.standard.data(forKey: "hotkey.toggleHide"),
              let combo = try? JSONDecoder().decode(KeyCombination.self, from: data) else {
            return
        }
        hotkeyService.register(combo) { [weak self] in
            self?.menuBarController.toggle()
        }
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show(itemStore: itemStore)
    }

    @objc private func toggleIceBar(_ notification: Notification) {
        guard let statusItem = notification.object as? NSStatusItem else { return }

        if iceBarPanel == nil {
            iceBarPanel = IceBarPanel(
                menuBarController: menuBarController,
                itemStore: itemStore
            )
        }
        guard let panel = iceBarPanel else { return }

        if panel.isVisible {
            panel.dismiss()
        } else {
            panel.showBelow(statusItem: statusItem)
        }
    }
}

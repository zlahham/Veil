import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appController = AppController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let needsFirstRun = !VeilSettings.shared.firstRunCompleted || !Permissions.isAccessibilityGranted
        if needsFirstRun {
            FirstRunWindow.shared.show { [weak self] in
                self?.appController.start()
                // Land the user in Veil's Settings so they can configure
                // hotkey, icon, launch-at-login, etc. right after onboarding.
                NotificationCenter.default.post(name: .veilOpenSettings, object: nil)
            }
        } else {
            appController.start()
        }
    }
}

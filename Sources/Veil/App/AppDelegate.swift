import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appController = AppController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let needsFirstRun = !VeilSettings.shared.firstRunCompleted || !Permissions.isAccessibilityGranted
        if needsFirstRun {
            FirstRunWindow.shared.show { [weak self] in
                self?.appController.start()
            }
        } else {
            appController.start()
        }
    }
}

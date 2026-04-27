import AppKit
import SwiftUI

/// Welcome window shown on first launch, or any launch where Accessibility
/// hasn't been granted. Explains why Veil wants the permission and gives a
/// one-click path to grant it, then lets the user continue once it's live.
@MainActor
final class FirstRunWindow {
    static let shared = FirstRunWindow()

    private var window: NSWindow?
    private var onContinue: (() -> Void)?

    private init() {}

    /// Show the window and call `onContinue` once the user dismisses it.
    /// Returns immediately — the caller should defer any work that depends
    /// on Accessibility until the continuation fires.
    func show(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue

        if window == nil {
            let controller = NSHostingController(
                rootView: FirstRunContentView(onContinue: { [weak self] in
                    self?.dismiss()
                })
            )
            let w = NSWindow(contentViewController: controller)
            w.title = "Welcome to Veil"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.setContentSize(NSSize(width: 440, height: 340))
            w.center()
            window = w
        }
        NSApp.setActivationPolicy(.regular) // show in dock briefly so window gets focus
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func dismiss() {
        window?.orderOut(nil)
        // Restore menu-bar-only mode.
        NSApp.setActivationPolicy(.accessory)
        VeilSettings.shared.firstRunCompleted = true
        onContinue?()
        onContinue = nil
    }
}

private struct FirstRunContentView: View {
    let onContinue: () -> Void

    @State private var granted: Bool = Permissions.isAccessibilityGranted
    private let pollTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("Welcome to Veil")
                .font(.title)
                .fontWeight(.semibold)

            Text("Click the bolt in the menu bar to hide cluttering icons. Click again to reveal them.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.callout)
                .padding(.horizontal, 24)

            Divider().padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("Veil needs **Accessibility** to read the titles of your menu bar items so it can list them. It does not click, modify, or send events on your behalf.")
                        .font(.caption)
                } icon: {
                    Image(systemName: "lock.shield")
                }
            }
            .padding(.horizontal, 24)

            HStack(spacing: 12) {
                if granted {
                    Label("Granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Grant Accessibility") {
                        Permissions.promptForAccessibility()
                    }
                }
                Button("Continue") { onContinue() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!granted)
            }
            .padding(.bottom, 4)
        }
        .padding(24)
        .frame(width: 440, height: 340)
        .onReceive(pollTimer) { _ in
            granted = Permissions.isAccessibilityGranted
        }
    }
}

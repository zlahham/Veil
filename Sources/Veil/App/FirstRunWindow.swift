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
            // Keep the welcome window above other apps and visible across
            // spaces — including when System Settings is fullscreen — so
            // the user doesn't lose it after clicking "Grant Accessibility".
            w.level = .floating
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            // NSScreen.screens.first is the primary display (the one with the
            // menu bar); NSScreen.main follows the key window which on a
            // multi-monitor setup with a fullscreen app might land elsewhere.
            let screen = NSScreen.screens.first ?? NSScreen.main
            if let visible = screen?.visibleFrame {
                let size = w.frame.size
                let origin = NSPoint(
                    x: visible.midX - size.width / 2,
                    y: visible.midY - size.height / 2
                )
                w.setFrameOrigin(origin)
            } else {
                w.center()
            }
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func dismiss() {
        window?.orderOut(nil)
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
            // Load the raw .icns instead of NSApp.applicationIconImage —
            // the latter triggers macOS Tahoe's Liquid Glass treatment which
            // adds a glossy bevel around the icon.
            if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let raw = NSImage(contentsOf: url) {
                Image(nsImage: raw)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
            }

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

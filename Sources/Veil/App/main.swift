import AppKit

// Plain AppKit entry. We skip SwiftUI's `App` + `Settings` scene because
// the latter auto-presents an empty window when activation policy flips.
//
// Top-level code is nonisolated; AppDelegate is @MainActor. Wrap the
// initialization in `MainActor.assumeIsolated` since we already run on
// the main thread.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}

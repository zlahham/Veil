import AppKit
import Combine

/// Live list of menu bar items, refreshed on demand.
///
/// With the divider-push hiding strategy we no longer persist per-item
/// assignments; sections are positional (everything left of a given divider
/// belongs to that section). This store exists purely so the Ice Bar can
/// list items.
@MainActor
final class MenuBarItemStore: ObservableObject {
    @Published private(set) var items: [MenuBarItem] = []

    func refresh() {
        items = MenuBarItem.enumerateAll()
    }
}

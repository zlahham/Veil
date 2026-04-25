import AppKit
import ApplicationServices

/// One menu bar extra owned by a third-party process.
///
/// Wraps the AXUIElement plus enough metadata to identify the item across
/// launches (`storageKey`) and restore its original position after hiding.
@MainActor
final class MenuBarItem: Identifiable {
    let pid: pid_t
    let bundleID: String
    let title: String

    /// Item position when last enumerated. Used by the Ice Bar to sort and
    /// to compute which section an item falls into (relative to dividers).
    let position: CGPoint

    nonisolated var id: String { storageKey }
    let storageKey: String

    init(pid: pid_t, bundleID: String, title: String, index: Int, position: CGPoint) {
        self.pid = pid
        self.bundleID = bundleID
        self.title = title
        self.position = position
        self.storageKey = title.isEmpty
            ? "\(bundleID):#\(index)"
            : "\(bundleID):\(title)"
    }

    // MARK: - Enumeration

    /// Enumerate all menu bar extras for every running app the user can see.
    /// Requires AX permission; returns [] otherwise.
    static func enumerateAll() -> [MenuBarItem] {
        guard AXIsProcessTrusted() else { return [] }
        let ourBundleID = Bundle.main.bundleIdentifier
        var items: [MenuBarItem] = []

        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy != .prohibited || app.bundleIdentifier == "com.apple.controlcenter" else {
                // Most third-party apps are .regular or .accessory; ControlCenter is .prohibited.
                // Allow ControlCenter through explicitly.
                continue
            }
            if app.bundleIdentifier == ourBundleID { continue }
            items.append(contentsOf: enumerate(app: app))
        }

        return items.sorted { $0.position.x < $1.position.x }
    }

    private static func enumerate(app: NSRunningApplication) -> [MenuBarItem] {
        let pid = app.processIdentifier
        guard pid > 0 else { return [] }
        let bundleID = app.bundleIdentifier ?? app.localizedName ?? "pid:\(pid)"

        let appElement = AXUIElementCreateApplication(pid)

        var extras: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, "AXExtrasMenuBar" as CFString, &extras) == .success,
              let extrasMenuBar = extras else {
            return []
        }

        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(
            extrasMenuBar as! AXUIElement,
            kAXChildrenAttribute as CFString,
            &children
        ) == .success, let elements = children as? [AXUIElement] else {
            return []
        }

        return elements.enumerated().compactMap { (index, element) in
            let title = readTitle(element, bundleID: bundleID)
            let position = readPosition(element) ?? .zero
            // Skip items with no valid position (off-screen ghosts).
            guard position != .zero, position.y < 100 else { return nil }
            return MenuBarItem(
                pid: pid,
                bundleID: bundleID,
                title: title,
                index: index,
                position: position
            )
        }
    }

    private static func readTitle(_ element: AXUIElement, bundleID: String) -> String {
        let parentTag = bundleID.split(separator: ".").last.map(String.init)?.lowercased()
        return searchTitle(element, depth: 3, parentTag: parentTag) ?? ""
    }

    /// Depth-first search for a non-empty string attribute on the element or
    /// its descendants, up to `depth` levels. ControlCenter items often hide
    /// the human-readable name on a grandchild AXButton/AXImage.
    private static func searchTitle(_ element: AXUIElement, depth: Int, parentTag: String?) -> String? {
        if let s = stringAttribute(element, parentTag: parentTag) { return s }
        guard depth > 0 else { return nil }

        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
              let array = children as? [AXUIElement] else {
            return nil
        }
        for child in array {
            if let s = searchTitle(child, depth: depth - 1, parentTag: parentTag) { return s }
        }
        return nil
    }

    /// Probe several string-bearing attributes; return the first non-empty.
    private static func stringAttribute(_ element: AXUIElement, parentTag: String?) -> String? {
        // Order matters: identifier ("com.apple.menuextra.battery") is more
        // specific than RoleDescription ("menu extra") so try it first.
        for attr in [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute, kAXValueAttribute, kAXIdentifierAttribute, kAXRoleDescriptionAttribute] {
            var value: AnyObject?
            AXUIElementCopyAttributeValue(element, attr as CFString, &value)
            guard let s = value as? String, !s.isEmpty else { continue }
            // Skip generic role descriptions that aren't useful labels.
            let lc = s.lowercased()
            if lc == "menu extra" || lc == "button" || lc == "status menu" || lc == "image" { continue }
            if attr == kAXIdentifierAttribute {
                let last = s.split(separator: ".").last.map(String.init) ?? s
                // Reject identifiers whose last component is just the parent
                // process name ("controlcenter") — that's no better than bundleID.
                if let parentTag, last.lowercased() == parentTag { continue }
                return last.prefix(1).capitalized + last.dropFirst()
            }
            return s
        }
        return nil
    }

    private static func readPosition(_ element: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success,
              let axValue = value, CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }
        var point = CGPoint.zero
        AXValueGetValue(axValue as! AXValue, .cgPoint, &point)
        return point
    }
}

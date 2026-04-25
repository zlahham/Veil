import Foundation

/// Centralized settings backed by UserDefaults. No Combine, no publishers.
/// SwiftUI views use @AppStorage for the same keys to stay in sync automatically.
@MainActor
final class VeilSettings {
    static let shared = VeilSettings()

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Keys

    private enum Key: String {
        case showOnHover
        case showOnClick
        case showOnScroll
        case autoRehide
        case rehideInterval
        case useIceBar
        case launchAtLogin
        case itemsHidden
        case iconStyle
        case firstRunCompleted
    }

    // MARK: - Properties

    var showOnHover: Bool {
        get { defaults.bool(forKey: Key.showOnHover.rawValue) }
        set { defaults.set(newValue, forKey: Key.showOnHover.rawValue) }
    }

    var showOnClick: Bool {
        get { defaults.object(forKey: Key.showOnClick.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.showOnClick.rawValue) }
    }

    var showOnScroll: Bool {
        get { defaults.bool(forKey: Key.showOnScroll.rawValue) }
        set { defaults.set(newValue, forKey: Key.showOnScroll.rawValue) }
    }

    var autoRehide: Bool {
        get { defaults.object(forKey: Key.autoRehide.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.autoRehide.rawValue) }
    }

    /// Rehide interval in seconds. 0 means no auto-rehide.
    var rehideInterval: TimeInterval {
        get {
            let val = defaults.double(forKey: Key.rehideInterval.rawValue)
            return val > 0 ? val : 3.0
        }
        set { defaults.set(newValue, forKey: Key.rehideInterval.rawValue) }
    }

    var useIceBar: Bool {
        get { defaults.bool(forKey: Key.useIceBar.rawValue) }
        set { defaults.set(newValue, forKey: Key.useIceBar.rawValue) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin.rawValue) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin.rawValue) }
    }

    /// True when Veil's chevron is in push mode (items to its left are hidden).
    var itemsHidden: Bool {
        get { defaults.bool(forKey: Key.itemsHidden.rawValue) }
        set { defaults.set(newValue, forKey: Key.itemsHidden.rawValue) }
    }

    /// Set to true after the first-run welcome window is dismissed.
    var firstRunCompleted: Bool {
        get { defaults.bool(forKey: Key.firstRunCompleted.rawValue) }
        set { defaults.set(newValue, forKey: Key.firstRunCompleted.rawValue) }
    }

    /// User-selected menu bar icon style. Defaults to `.bolt`.
    var iconStyle: VeilIcon {
        get {
            guard let raw = defaults.string(forKey: Key.iconStyle.rawValue),
                  let icon = VeilIcon(rawValue: raw) else {
                return .bolt
            }
            return icon
        }
        set { defaults.set(newValue.rawValue, forKey: Key.iconStyle.rawValue) }
    }

}

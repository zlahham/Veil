import Foundation

/// User-selectable menu bar icon styles.
/// Each case maps to a pair of SF Symbol names: one for the "items shown"
/// state, one for the "items hidden / push mode" state.
enum VeilIcon: String, CaseIterable, Identifiable {
    case bolt
    case sparkles
    case moon
    case eye
    case cloud

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bolt: return "Bolt"
        case .sparkles: return "Sparkles"
        case .moon: return "Moon"
        case .eye: return "Eye"
        case .cloud: return "Cloud"
        }
    }

    /// Symbol shown when items are visible (normal chevron-equivalent).
    var shownSymbol: String {
        switch self {
        case .bolt: return "bolt.fill"
        case .sparkles: return "sparkles"
        case .moon: return "moon.fill"
        case .eye: return "eye"
        case .cloud: return "cloud"
        }
    }

    /// Symbol shown when items are pushed off-screen.
    var hiddenSymbol: String {
        switch self {
        case .bolt: return "bolt.slash.fill"
        case .sparkles: return "sparkle"
        case .moon: return "moon.stars.fill"
        case .eye: return "eye.slash"
        case .cloud: return "cloud.fog.fill"
        }
    }

    /// Used for the picker preview and any non-state-aware display.
    var previewSymbol: String { shownSymbol }
}

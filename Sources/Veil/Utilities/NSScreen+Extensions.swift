import AppKit

extension NSScreen {
    /// The height of the menu bar on this screen.
    var menuBarHeight: CGFloat {
        frame.height - visibleFrame.height - visibleFrame.origin.y + frame.origin.y
    }

    /// Whether this screen has a notch (camera housing).
    var hasNotch: Bool {
        guard let auxiliaryTopLeftArea = auxiliaryTopLeftArea,
              let auxiliaryTopRightArea = auxiliaryTopRightArea else {
            return false
        }
        // If there are auxiliary areas on both sides of the top, there's a notch between them
        return auxiliaryTopLeftArea.width > 0 && auxiliaryTopRightArea.width > 0
    }

    /// The frame of the menu bar area on this screen.
    var menuBarFrame: NSRect {
        NSRect(
            x: frame.origin.x,
            y: frame.maxY - menuBarHeight,
            width: frame.width,
            height: menuBarHeight
        )
    }
}

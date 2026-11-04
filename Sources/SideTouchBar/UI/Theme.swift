import SwiftUI

enum BarMetrics {
    /// Width of the visible bar.
    static let width: CGFloat = 58
    /// Circular touch targets, at least 44pt for fingers.
    static let buttonSize: CGFloat = 44
    static let spacing: CGFloat = 4
    /// Padding between the glass edge and the buttons; the corner radius is
    /// half the width so buttons sit concentric inside the capsule ends.
    static let innerPadding: CGFloat = (width - buttonSize) / 2
    static let cornerRadius: CGFloat = width / 2
    /// Gap between the screen edge and the floating glass bar.
    static let edgeInset: CGFloat = 6
    /// Transparent room around the bar for the glass shadow.
    static let shadowMargin: CGFloat = 18

    /// How close to the screen edge the pointer must be to reveal the bar.
    static let triggerWidth: CGFloat = 2
    static let hoverSlack: CGFloat = 24
    static let leaveDelay: TimeInterval = 0.7
}

enum BarAnimation {
    static let slide = Animation.spring(response: 0.38, dampingFraction: 0.78)
    static let morph = Animation.spring(response: 0.34, dampingFraction: 0.82)
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.6)
}

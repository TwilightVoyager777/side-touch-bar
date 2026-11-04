import SwiftUI

/// All bar dimensions, derived from one scale factor. Scale 1 is the design
/// size for a 14"/16" MacBook Pro at its default resolution (44pt ≈ 8.8mm buttons).
struct BarMetrics: Equatable {
    var scale: CGFloat

    static let standard = BarMetrics(scale: 1)

    /// Circular touch target.
    var buttonSize: CGFloat { (44 * scale).rounded() }
    /// Padding between the glass edge and the buttons; the corner radius is
    /// half the width so buttons sit concentric inside the capsule ends.
    var innerPadding: CGFloat { (7 * scale).rounded() }
    var width: CGFloat { buttonSize + innerPadding * 2 }
    var cornerRadius: CGFloat { width / 2 }
    var spacing: CGFloat { (4 * scale).rounded() }

    var symbolSize: CGFloat { 17 * scale }
    var textSize: CGFloat { 13 * scale }
    var captionSize: CGFloat { 11 * scale }
    var dividerWidth: CGFloat { (24 * scale).rounded() }
    var appIconSize: CGFloat { (32 * scale).rounded() }
    var sliderHeight: CGFloat { (220 * scale).rounded() }
    var knobSize: CGFloat { (26 * scale).rounded() }
    var trackWidth: CGFloat { (8 * scale).rounded() }
    var handleHeight: CGFloat { (64 * scale).rounded() }
    /// Fixed height of scrolling lists (emoji, quick actions, spaces): seven buttons.
    var scrollPageHeight: CGFloat { buttonSize * 7 + spacing * 6 }

    /// Gap between the screen edge and the floating glass bar.
    static let edgeInset: CGFloat = 6
    /// Transparent room around the bar for the glass shadow.
    static let shadowMargin: CGFloat = 18
    /// How close to the screen edge the pointer must be to reveal the bar.
    static let triggerWidth: CGFloat = 2
    static let hoverSlack: CGFloat = 24
    static let leaveDelay: TimeInterval = 0.7
}

private struct BarMetricsKey: EnvironmentKey {
    static let defaultValue = BarMetrics.standard
}

extension EnvironmentValues {
    var barMetrics: BarMetrics {
        get { self[BarMetricsKey.self] }
        set { self[BarMetricsKey.self] = newValue }
    }
}

enum BarAnimation {
    static let slide = Animation.spring(response: 0.38, dampingFraction: 0.78)
    static let morph = Animation.spring(response: 0.34, dampingFraction: 0.82)
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.6)
}

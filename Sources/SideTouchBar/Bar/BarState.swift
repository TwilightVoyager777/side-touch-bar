import SwiftUI

enum BarSide: String {
    case left, right
}

enum BarContent {
    /// System controls: brightness, volume, media, Mission Control…
    case controlStrip
    /// Buttons that follow the frontmost app, like the Touch Bar app region.
    case appRegion
    /// Both in one bar (single-side layout), like the original Touch Bar.
    case combined
}

enum ControlStripMode: Equatable {
    case compact
    case full
    case slider(LevelKind)
}

@MainActor
final class BarState: ObservableObject {
    let side: BarSide

    @Published var isExpanded = false
    @Published var content: BarContent
    /// True while the user is dragging a slider, so the bar must not auto-hide.
    @Published var isInteracting = false
    /// Sizes for the current screen, chosen by `BarSizer`.
    @Published var metrics = BarMetrics.standard
    /// Forces a preset instead of the frontmost app's; used for measuring.
    var presetOverride: AppPreset?

    // View state lives here instead of SwiftUI `@State`, whose macro plugin
    // ships only with full Xcode, not the Command Line Tools.
    @Published var stripMode: ControlStripMode = .compact
    @Published var showFunctionKeys = false
    @Published var levelValue: Double = 0.5
    @Published var isLevelAvailable = true

    init(side: BarSide, content: BarContent) {
        self.side = side
        self.content = content
    }

    func resetTransientState() {
        stripMode = .compact
        showFunctionKeys = false
        isInteracting = false
    }
}

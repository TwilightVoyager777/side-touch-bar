import SwiftUI

enum BarSide: String {
    case left, right
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
    /// True while the user is dragging a slider, so the bar must not auto-hide.
    @Published var isInteracting = false
    /// Sizes for the current screen, chosen by `BarSizer`.
    @Published var metrics = BarMetrics.standard

    // View state lives here instead of SwiftUI `@State`, whose macro plugin
    // ships only with full Xcode, not the Command Line Tools.
    @Published var stripMode: ControlStripMode = .compact
    @Published var showEmojiPicker = false
    /// The keyboard fn/Globe key is held down.
    @Published var isFnHeld = false
    @Published var levelValue: Double = 0.5
    @Published var isLevelAvailable = true

    /// nil: show playback controls automatically; true/false: the user opened or closed them.
    @Published var nowPlayingOverride: Bool?
    @Published var isScrubbing = false
    @Published var scrubValue: Double = 0

    /// Forces a page / preset / Now Playing info instead of the live ones; used for measuring.
    var pageOverride: BarPage?
    var presetOverride: AppPreset?
    var nowPlayingSample: NowPlayingInfo?

    init(side: BarSide) {
        self.side = side
    }

    /// The page to show, following the Touch Bar rules: apps listed in settings
    /// always show F-keys, and holding fn switches to the fn page (or back to
    /// app controls in those F-key apps).
    func currentPage(settings: Settings, frontmostBundleID: String?) -> BarPage {
        if let pageOverride { return pageOverride }
        let prefersFunctionKeys = frontmostBundleID.map(settings.functionKeyApps.contains) ?? false
        if isFnHeld {
            return prefersFunctionKeys ? .appControlsWithStrip : settings.fnHoldPage
        }
        return prefersFunctionKeys ? .functionKeys : settings.barPage
    }

    func resetTransientState() {
        stripMode = .compact
        showEmojiPicker = false
        nowPlayingOverride = nil
        isScrubbing = false
        isInteracting = false
    }
}

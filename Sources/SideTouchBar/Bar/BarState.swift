import SwiftUI

enum BarSide: String {
    case left, right
}

enum NowPlayingPage: Equatable {
    case main, more, outputs
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

    @Published var nowPlayingPage: NowPlayingPage = .main
    @Published var presetPageIndex = 0
    @Published var showSessions = false
    /// Drag distance already turned into scroll steps by the scroll pad.
    var scrollPadOffset: CGFloat = 0
    /// Drag distance already turned into cursor moves by the cursor pad.
    var cursorPadOffset: CGSize = .zero
    @Published var textSelecting = false
    @Published var textByWord = false

    /// Press-and-slide on a level button in the control strip.
    @Published var slidingLevel: LevelKind?
    @Published var slideValue: Double = 0
    var slideStart: Float = 0
    /// A permission request the user chose to handle later.
    @Published var dismissedAttentionKey: AttentionKey?

    /// Forces a page / preset / sample data instead of the live ones; used for measuring.
    var pageOverride: BarPage?
    var presetOverride: AppPreset?
    var nowPlayingSample: NowPlayingInfo?
    var agentSessionSample: AgentSession?

    func handle(_ command: ViewCommand) {
        switch command {
        case .emojiPicker: showEmojiPicker = true
        case .nextPresetPage: presetPageIndex += 1
        case .mediaMore: nowPlayingPage = .more
        case .audioOutputs: nowPlayingPage = .outputs
        }
    }

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
        nowPlayingPage = .main
        showSessions = false
        isScrubbing = false
        isInteracting = false
    }
}

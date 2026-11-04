import AppKit

/// Picks the buttons for the frontmost app: the agent page when a coding
/// agent runs in the terminal, otherwise the app's preset plus the user's
/// custom buttons.
@MainActor
enum PresetResolver {
    static let maxCustomButtons = 8

    static func preset(for app: NSRunningApplication?, context: AIContext) -> AppPreset {
        if case .terminal(let agent, _) = context {
            return AIPresets.terminalAgent(agent)
        }
        return withCustomButtons(AppPresets.preset(for: app?.bundleIdentifier), bundleID: app?.bundleIdentifier)
    }

    static func withCustomButtons(_ base: AppPreset, bundleID: String?) -> AppPreset {
        guard let bundleID, let custom = Settings.shared.customButtons[bundleID], !custom.buttons.isEmpty else { return base }
        let page = customPage(custom.buttons)
        if custom.replacesBuiltIn {
            return AppPreset(id: "custom-\(bundleID)", bundleIDs: [bundleID], pages: [page])
        }
        return AppPreset(id: "\(base.id)+custom", bundleIDs: base.bundleIDs, pages: base.pages + [page])
    }

    static func customPage(_ buttons: [CustomButton]) -> PresetPage {
        let items = buttons.prefix(maxCustomButtons).map(\.barItem)
        let groups = stride(from: 0, to: items.count, by: 4).map { Array(items[$0..<min($0 + 4, items.count)]) }
        return PresetPage(id: "custom", title: "自定义", symbol: "star", groups: groups)
    }
}

/// Watches the enabled state of menu items that preset pages probe, so a
/// debugger page appears on its own while debugging.
@MainActor
final class MenuStateMonitor: ObservableObject {
    static let shared = MenuStateMonitor()

    /// IDs of probed pages whose menu item is currently enabled.
    @Published private(set) var activePageIDs: Set<String> = []

    private var timer: Timer?

    private init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    func poll() {
        let app = FrontmostAppMonitor.shared.app
        let preset = PresetResolver.preset(for: app, context: AIContextMonitor.shared.context)
        var active = Set<String>()
        if preset.hasProbes, Permissions.shared.isTrusted {
            for page in preset.pages {
                if let probe = page.probe, MenuInvoker.isEnabled(probe.path, in: app) == true {
                    active.insert(page.id)
                }
            }
        }
        if active != activePageIDs { activePageIDs = active }
    }
}

/// What the app controls area shows, in priority order.
@MainActor
enum AppControlsContent {
    case emoji
    case attention(AgentSession)
    case sessions
    case nowPlaying(NowPlayingInfo)
    case preset(AppPreset)

    static func resolve(state: BarState) -> AppControlsContent {
        if state.showEmojiPicker { return .emoji }
        if let session = attentionSession(state: state) { return .attention(session) }
        if state.showSessions { return .sessions }
        let frontmost = FrontmostAppMonitor.shared.app
        if NowPlayingPresentation.isShown(state: state, frontmost: frontmost),
           let info = NowPlayingPresentation.info(for: state) {
            return .nowPlaying(info)
        }
        let preset = state.presetOverride
            ?? PresetResolver.preset(for: frontmost, context: AIContextMonitor.shared.context)
        return .preset(preset)
    }

    /// A session waiting for permission, unless the user put it off or its
    /// own agent page (with the answer buttons) is already in front.
    static func attentionSession(state: BarState) -> AgentSession? {
        if let sample = state.agentSessionSample {
            return sample.status == .needsPermission ? sample : nil
        }
        guard Settings.shared.aiEnabled, let session = AgentMonitor.shared.sessionNeedingPermission else { return nil }
        if state.dismissedAttentionKey == AttentionKey(session) { return nil }
        if AIContextMonitor.shared.context.isTerminalAgent,
           FrontmostAppMonitor.shared.app?.processIdentifier == session.terminalPID {
            return nil
        }
        return session
    }

    var isAgentRelated: Bool {
        switch self {
        case .attention, .sessions: true
        default: false
        }
    }
}

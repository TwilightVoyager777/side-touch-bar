import Carbon.HIToolbox
import AppKit
import Combine

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
        let base = withTextPage(AppPresets.preset(for: app?.bundleIdentifier))
        return withCustomButtons(base, bundleID: app?.bundleIdentifier)
    }

    /// Presets where typing is the main activity get a text page that comes
    /// forward on its own; editors and AI apps get one to open by hand.
    private static let automaticTextPresets: Set<String> = ["fallback", "notes", "textEditing", "mail", "messages"]
    private static let manualTextPresets: Set<String> = [
        "vscode", "cursor", "jetbrains", "xcode", "claudeDesktop", "opencodeDesktop", "chatgpt", "browser",
    ]

    static func withTextPage(_ base: AppPreset) -> AppPreset {
        let automatic = automaticTextPresets.contains(base.id)
        guard automatic || manualTextPresets.contains(base.id) else { return base }
        return AppPreset(id: base.id, bundleIDs: base.bundleIDs, pages: base.pages + [textPage(automatic: automatic)])
    }

    static func textPage(automatic: Bool) -> PresetPage {
        PresetPage(
            id: "text",
            title: "文字",
            symbol: "character.cursor.ibeam",
            groups: [
                [
                    .key("全选", "selection.pin.in.out", KeyCombo(kVK_ANSI_A, .maskCommand)),
                    BarItem.key("删除一个词", "delete.left", KeyCombo(kVK_Delete, .maskAlternate)).repeating(),
                ],
                [
                    .key("拷贝", "doc.on.doc", KeyCombo(kVK_ANSI_C, .maskCommand)),
                    .key("粘贴", "doc.on.clipboard", KeyCombo(kVK_ANSI_V, .maskCommand)),
                    BarItem.key("撤销", "arrow.uturn.backward", KeyCombo(kVK_ANSI_Z, .maskCommand)).repeating(),
                ],
            ],
            extras: [.cursorPad],
            activatesOnTextFocus: automatic
        )
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
    private var cancellable: AnyCancellable?

    /// Polls only while the bar is out.
    private init() {
        cancellable = BarActivity.shared.$isExpanded
            .removeDuplicates()
            .sink { [weak self] expanded in
                MainActor.assumeIsolated { self?.setActive(expanded) }
            }
    }

    private func setActive(_ active: Bool) {
        timer?.invalidate()
        timer = nil
        guard active else { return }
        poll()
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

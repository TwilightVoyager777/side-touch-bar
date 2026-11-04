import AppKit
import Combine

enum AgentKind: String, Codable, CaseIterable {
    case claude, codex, opencode, gemini

    var title: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .opencode: "OpenCode"
        case .gemini: "Gemini"
        }
    }

    /// Recognizes an agent from a process name and its arguments (agents
    /// started through node or bun show up under the runtime's name).
    static func detect(name: String, arguments: () -> [String]) -> AgentKind? {
        if let kind = match(name) { return kind }
        guard ["node", "bun", "deno", "python", "python3"].contains(name.lowercased()) else { return nil }
        return arguments().prefix(3).lazy.compactMap { match(($0 as NSString).lastPathComponent) }.first
    }

    private static func match(_ token: String) -> AgentKind? {
        let token = token.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return allCases.first { token == $0.rawValue || token.hasPrefix($0.rawValue + "-") }
    }
}

enum AIDesktopApp: String, CaseIterable {
    case claude, opencode, chatgpt

    var bundleID: String {
        switch self {
        case .claude: "com.anthropic.claudefordesktop"
        case .opencode: "ai.opencode.desktop"
        case .chatgpt: "com.openai.chat"
        }
    }

    init?(bundleID: String?) {
        guard let match = Self.allCases.first(where: { $0.bundleID == bundleID }) else { return nil }
        self = match
    }
}

enum AIContext: Equatable {
    case none
    /// A coding agent running inside the frontmost terminal.
    case terminal(AgentKind, agentPID: pid_t)
    case desktop(AIDesktopApp)

    var isTerminalAgent: Bool {
        if case .terminal = self { true } else { false }
    }
}

/// Tracks whether the frontmost app is an AI tool, and remembers the last one
/// used so "send to AI" knows where to deliver.
@MainActor
final class AIContextMonitor: ObservableObject {
    static let shared = AIContextMonitor()

    static let terminals: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.Warp-Stable",
        "net.kovidgoyal.kitty", "com.github.wez.wezterm", "org.alacritty", "co.zeit.hyper",
    ]

    @Published private(set) var context: AIContext = .none

    struct Target {
        let app: NSRunningApplication
        let context: AIContext
    }

    private(set) var lastTarget: Target?
    private var cancellables: Set<AnyCancellable> = []
    private var timer: Timer?

    private init() {
        FrontmostAppMonitor.shared.$app
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        // Agents start and quit inside terminals without any app switch, so
        // re-check the terminal while the bar is out (and once when it comes out).
        BarActivity.shared.$isExpanded
            .removeDuplicates()
            .sink { [weak self] expanded in
                MainActor.assumeIsolated { self?.setPolling(expanded) }
            }
            .store(in: &cancellables)
    }

    private func setPolling(_ active: Bool) {
        timer?.invalidate()
        timer = nil
        guard active else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let id = FrontmostAppMonitor.shared.app?.bundleIdentifier,
                      Self.terminals.contains(id) else { return }
                self.refresh()
            }
        }
    }

    func refresh() {
        guard Settings.shared.aiEnabled, let app = FrontmostAppMonitor.shared.app else {
            if context != .none { context = .none }
            return
        }
        let newContext = Self.context(for: app)
        if newContext != context { context = newContext }
        if newContext != .none { lastTarget = Target(app: app, context: newContext) }
    }

    static func context(for app: NSRunningApplication) -> AIContext {
        if let desktop = AIDesktopApp(bundleID: app.bundleIdentifier) { return .desktop(desktop) }
        guard let id = app.bundleIdentifier, terminals.contains(id),
              let (kind, pid) = agent(in: app.processIdentifier) else { return .none }
        return .terminal(kind, agentPID: pid)
    }

    /// The first coding agent among a process's descendants.
    static func agent(in root: pid_t) -> (AgentKind, pid_t)? {
        let entries = ProcessTree.snapshot()
        for entry in ProcessTree.descendants(of: root, in: entries) {
            if let kind = AgentKind.detect(name: entry.name, arguments: { ProcessTree.arguments(of: entry.pid) }) {
                return (kind, entry.pid)
            }
        }
        return nil
    }

    /// A running terminal hosting the given agent, if any.
    static func terminal(running kind: AgentKind) -> NSRunningApplication? {
        for app in NSWorkspace.shared.runningApplications where terminals.contains(app.bundleIdentifier ?? "") {
            if let (found, _) = agent(in: app.processIdentifier), found == kind { return app }
        }
        return nil
    }
}

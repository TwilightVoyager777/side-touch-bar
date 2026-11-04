import AppKit
import SwiftUI

enum AgentStatus: String {
    case idle, running, needsPermission, needsInput, done, failed

    /// Higher wins when several sessions want attention.
    var priority: Int {
        switch self {
        case .needsPermission: 5
        case .needsInput: 4
        case .failed: 3
        case .done: 2
        case .running: 1
        case .idle: 0
        }
    }

    var title: String {
        switch self {
        case .idle: "空闲"
        case .running: "运行中"
        case .needsPermission: "等你确认"
        case .needsInput: "等你输入"
        case .done: "已完成"
        case .failed: "出错了"
        }
    }

    var color: Color {
        switch self {
        case .idle: .secondary
        case .running: .blue
        case .needsPermission, .needsInput: .orange
        case .done: .green
        case .failed: .red
        }
    }

    var wantsAttention: Bool { priority >= AgentStatus.done.priority }
}

struct AgentSession: Identifiable, Equatable {
    let id: String
    var agent: AgentKind
    var status: AgentStatus = .idle
    var cwd: String?
    /// What it waits for, e.g. the command needing permission.
    var detail: String?
    /// Identifies the tool call awaiting permission, to notice when it ran.
    var pendingToolKey: String?
    var updated = Date()
    var agentPID: pid_t?
    var terminalPID: pid_t?
    /// The user has seen the done/failed result.
    var acknowledged = true
    var contextPercent: Double?
    var model: String?
    var cost: Double?

    var title: String {
        cwd.map { ($0 as NSString).lastPathComponent } ?? agent.title
    }

    var shortLabel: String {
        String(title.prefix(2)).uppercased()
    }

    var needsAttention: Bool {
        status == .needsPermission || status == .needsInput || (!acknowledged && status.wantsAttention)
    }
}

/// Follows coding agent sessions from events their hooks and plugins drop into
/// `~/Library/Application Support/SideTouchBar/agents/inbox` (see AgentIntegration),
/// plus Claude Code status line snapshots in `agents/status`.
@MainActor
final class AgentMonitor: ObservableObject {
    static let shared = AgentMonitor()

    @Published private(set) var sessions: [AgentSession] = []
    /// Bumped when a session starts needing a permission decision.
    @Published private(set) var revealToken = 0

    nonisolated static let baseURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/SideTouchBar", isDirectory: true)
    nonisolated static let inboxURL = baseURL.appendingPathComponent("agents/inbox", isDirectory: true)
    nonisolated static let statusURL = baseURL.appendingPathComponent("agents/status", isDirectory: true)
    nonisolated static let pidURL = baseURL.appendingPathComponent("app.pid")

    private var sources: [DispatchSourceFileSystemObject] = []
    private var timer: Timer?

    /// The most urgent status among sessions that want attention, for the edge handle.
    var attention: AgentStatus? {
        let urgent = sessions.filter(\.needsAttention).max { $0.status.priority < $1.status.priority }
        if let urgent { return urgent.status }
        return sessions.contains { $0.status == .running } ? .running : nil
    }

    var sessionNeedingPermission: AgentSession? {
        sessions.first { $0.status == .needsPermission }
    }

    // MARK: - Lifecycle

    func start() {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: Self.inboxURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: Self.statusURL, withIntermediateDirectories: true)
        // Hooks only write events while this file names a live process.
        try? "\(ProcessInfo.processInfo.processIdentifier)".write(to: Self.pidURL, atomically: true, encoding: .utf8)

        removeStaleFiles()
        processInbox()
        readStatusFiles()
        watch(Self.inboxURL) { [weak self] in self?.processInbox() }
        watch(Self.statusURL) { [weak self] in self?.readStatusFiles() }

        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.processInbox()
                self?.pruneEndedSessions()
            }
        }
    }

    func stop() {
        try? FileManager.default.removeItem(at: Self.pidURL)
    }

    // MARK: - User actions

    func acknowledge(_ id: String) {
        update(id) { $0.acknowledged = true }
    }

    /// After answering a prompt from the bar; hooks confirm it shortly after.
    func markRunning(_ id: String) {
        update(id) {
            $0.status = .running
            $0.pendingToolKey = nil
            $0.detail = nil
        }
    }

    /// The user switched to an app: results shown in it count as seen.
    func appActivated(_ app: NSRunningApplication) {
        for session in sessions where session.terminalPID == app.processIdentifier && !session.acknowledged {
            acknowledge(session.id)
        }
    }

    func session(inTerminal app: NSRunningApplication?) -> AgentSession? {
        guard let app else { return nil }
        return sessions.first { $0.terminalPID == app.processIdentifier }
    }

    /// The app to bring forward for a session: its terminal, or OpenCode's desktop app.
    func app(for session: AgentSession) -> NSRunningApplication? {
        if let pid = session.terminalPID, let app = NSRunningApplication(processIdentifier: pid) { return app }
        if session.agent == .opencode,
           let desktop = NSRunningApplication.runningApplications(withBundleIdentifier: AIDesktopApp.opencode.bundleID).first {
            return desktop
        }
        return AIContextMonitor.terminal(running: session.agent)
    }

    // MARK: - Events

    private func processInbox() {
        let fileManager = FileManager.default
        guard let names = try? fileManager.contentsOfDirectory(atPath: Self.inboxURL.path) else { return }
        // Names start with a microsecond timestamp, so sorting replays events in order.
        for name in names.sorted() where name.hasSuffix(".json") && !name.hasPrefix(".") {
            let url = Self.inboxURL.appendingPathComponent(name)
            defer { try? fileManager.removeItem(at: url) }
            guard let data = try? Data(contentsOf: url),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let agentName = event["agent"] as? String, let agent = AgentKind(rawValue: agentName),
                  let name = event["event"] as? String
            else { continue }
            let payload = event["payload"] as? [String: Any] ?? [:]
            let pids = (event["pids"] as? [Int] ?? []).map { pid_t($0) }
            apply(agent: agent, event: name, payload: payload, pids: pids)
        }
    }

    private func apply(agent: AgentKind, event: String, payload: [String: Any], pids: [pid_t]) {
        let id = (payload["session_id"] as? String) ?? (payload["thread-id"] as? String) ?? "\(agent.rawValue)-\(pids.first ?? 0)"

        if AgentEventReducer.endsSession(event) {
            sessions.removeAll { $0.id == id }
            return
        }

        var session = sessions.first { $0.id == id } ?? AgentSession(id: id, agent: agent)
        let previous = session.status
        session.updated = Date()
        if let cwd = payload["cwd"] as? String, !cwd.isEmpty { session.cwd = cwd }
        if session.agentPID == nil || !ProcessTree.isAlive(session.agentPID!) {
            resolveProcesses(for: &session, pids: pids)
        }

        session = AgentEventReducer.apply(event: event, payload: payload, to: session)

        if session.status != previous {
            if session.status == .done || session.status == .failed {
                let isFrontmost = session.terminalPID != nil
                    && FrontmostAppMonitor.shared.app?.processIdentifier == session.terminalPID
                session.acknowledged = isFrontmost
                if !isFrontmost, Settings.shared.aiSoundOnDone { NSSound(named: "Glass")?.play() }
            }
            if session.status == .needsPermission { revealToken += 1 }
        }

        store(session)
    }

    /// Picks the agent process (for liveness) and the terminal app hosting it.
    private func resolveProcesses(for session: inout AgentSession, pids: [pid_t]) {
        let entries = ProcessTree.snapshot()
        let byPID = Dictionary(entries.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        let shells: Set<String> = ["sh", "bash", "zsh", "dash", "fish"]
        guard let agentPID = pids.first(where: { pid in
            guard let entry = byPID[pid] else { return false }
            return !shells.contains(entry.name)
        }) else { return }
        session.agentPID = agentPID

        var ancestors: [pid_t] = []
        var current = byPID[agentPID]?.parent
        while let pid = current, pid > 1, ancestors.count < 16 {
            ancestors.append(pid)
            current = byPID[pid]?.parent
        }
        session.terminalPID = ProcessTree.app(among: ancestors)?.processIdentifier
    }

    // MARK: - Status line snapshots

    private func readStatusFiles() {
        let fileManager = FileManager.default
        guard let names = try? fileManager.contentsOfDirectory(atPath: Self.statusURL.path) else { return }
        for name in names where name.hasSuffix(".json") && !name.hasPrefix(".") {
            let url = Self.statusURL.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = json["session_id"] as? String,
                  let index = sessions.firstIndex(where: { $0.id == id })
            else { continue }
            var session = sessions[index]
            session.contextPercent = (json["context_window"] as? [String: Any])?["used_percentage"] as? Double
            session.model = (json["model"] as? [String: Any])?["display_name"] as? String
            session.cost = (json["cost"] as? [String: Any])?["total_cost_usd"] as? Double
            if session != sessions[index] { sessions[index] = session }
        }
    }

    // MARK: - Housekeeping

    private func pruneEndedSessions() {
        let now = Date()
        let alive = sessions.filter { session in
            if let pid = session.agentPID { return ProcessTree.isAlive(pid) }
            return now.timeIntervalSince(session.updated) < 12 * 3600
        }
        if alive.count != sessions.count { sessions = alive }
    }

    private func removeStaleFiles() {
        let fileManager = FileManager.default
        let cutoff = Date().addingTimeInterval(-6 * 3600)
        for directory in [Self.inboxURL, Self.statusURL] {
            let urls = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for url in urls {
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                if modified < cutoff { try? fileManager.removeItem(at: url) }
            }
        }
    }

    private func watch(_ directory: URL, onChange: @escaping @MainActor () -> Void) {
        let descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source.setEventHandler { MainActor.assumeIsolated { onChange() } }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        sources.append(source)
    }

    private func store(_ session: AgentSession) {
        var list = sessions.filter { $0.id != session.id }
        list.append(session)
        list.sort {
            ($0.needsAttention ? 1 : 0, $0.status.priority, $0.updated) > ($1.needsAttention ? 1 : 0, $1.status.priority, $1.updated)
        }
        sessions = list
    }

    private func update(_ id: String, _ change: (inout AgentSession) -> Void) {
        guard var session = sessions.first(where: { $0.id == id }) else { return }
        change(&session)
        store(session)
    }
}

/// How agent events change a session's status. Pure, so it can be tested;
/// AgentMonitor adds process lookup, sounds and revealing the bar.
enum AgentEventReducer {
    static func endsSession(_ event: String) -> Bool {
        event == "SessionEnd" || event == "session.deleted"
    }

    static func apply(event: String, payload: [String: Any], to session: AgentSession) -> AgentSession {
        var session = session
        let agent = session.agent
        switch (agent, event) {
        case (.claude, "SessionStart"):
            session.status = .idle
        case (.claude, "UserPromptSubmit"), (.opencode, "session.execution.started"), (.opencode, "permission.replied"):
            session.status = .running
            session.pendingToolKey = nil
            session.detail = nil
        case (.claude, "PermissionRequest"):
            session.status = .needsPermission
            session.pendingToolKey = toolKey(payload)
            session.detail = toolSummary(payload)
        case (.claude, "PostToolUse"), (.claude, "PostToolUseFailure"):
            // Parallel tool calls can finish while another waits for permission.
            if session.status != .needsPermission || session.pendingToolKey == toolKey(payload) {
                session.status = .running
                session.pendingToolKey = nil
                session.detail = nil
            }
        case (.claude, "Notification"):
            switch payload["notification_type"] as? String {
            case "permission_prompt":
                if session.status != .needsPermission {
                    session.status = .needsPermission
                    session.detail = payload["message"] as? String
                }
            case "agent_needs_input", "elicitation_dialog", "elicitation_url_dialog":
                session.status = .needsInput
                session.detail = payload["message"] as? String
            default:
                break
            }
        case (.claude, "Stop"), (.opencode, "session.execution.succeeded"), (.codex, "turn-complete"):
            session.status = .done
            session.pendingToolKey = nil
            session.detail = (payload["last_assistant_message"] as? String ?? payload["last-assistant-message"] as? String)
                .map { String($0.prefix(80)) }
        case (.claude, "StopFailure"), (.opencode, "session.execution.failed"):
            session.status = .failed
        case (.opencode, "session.execution.interrupted"):
            session.status = .idle
        case (.opencode, "permission.asked"):
            session.status = .needsPermission
            let resources = (payload["resources"] as? [String])?.joined(separator: " ")
            session.detail = (payload["message"] as? String) ?? [payload["action"] as? String, resources].compactMap { $0 }.joined(separator: " ")
        default:
            break
        }

        return session
    }

    static func toolKey(_ payload: [String: Any]) -> String {
        let input = (payload["tool_input"]).flatMap {
            try? JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys])
        }.map { String(decoding: $0, as: UTF8.self) } ?? ""
        return "\(payload["tool_name"] as? String ?? "")|\(input)"
    }

    static func toolSummary(_ payload: [String: Any]) -> String? {
        let tool = payload["tool_name"] as? String
        let input = payload["tool_input"] as? [String: Any] ?? [:]
        if let command = input["command"] as? String { return command }
        if let path = input["file_path"] as? String { return "\(tool ?? "") \((path as NSString).lastPathComponent)" }
        if let url = input["url"] as? String { return "\(tool ?? "") \(url)" }
        return tool
    }
}

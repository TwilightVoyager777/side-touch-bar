import AppKit

/// Installs and removes the small integrations that tell the bar what coding
/// agents are doing. Nothing is installed until the user asks in settings.
///
/// - Claude Code: async command hooks in `~/.claude/settings.json`, plus an
///   optional status line wrapper for context usage. A timestamped backup of
///   the settings file is written before every change.
/// - OpenCode: a global plugin file in `~/.config/opencode/plugins/`.
/// - Codex: a `notify` entry in `~/.codex/config.toml`.
///
/// All of them drop JSON events into `AgentMonitor.inboxURL`, and only while
/// the app is running.
@MainActor
final class AgentIntegration: ObservableObject {
    static let shared = AgentIntegration()

    @Published private(set) var claudeHooksInstalled = false
    @Published private(set) var claudeStatusLineInstalled = false
    @Published private(set) var openCodeInstalled = false
    @Published private(set) var codexInstalled = false

    private let fileManager = FileManager.default
    private let home: URL
    /// The app's support directory: scripts, saved status line, event inbox.
    private let supportURL: URL

    private var binURL: URL { supportURL.appendingPathComponent("bin", isDirectory: true) }
    private var inboxURL: URL { supportURL.appendingPathComponent("agents/inbox", isDirectory: true) }
    private var statusURL: URL { supportURL.appendingPathComponent("agents/status", isDirectory: true) }
    var eventScriptURL: URL { binURL.appendingPathComponent("agent-event") }
    var statusScriptURL: URL { binURL.appendingPathComponent("agent-statusline") }
    private var originalStatusLineURL: URL { supportURL.appendingPathComponent("statusline-original") }

    var claudeSettingsURL: URL { home.appendingPathComponent(".claude/settings.json") }
    var openCodePluginURL: URL { home.appendingPathComponent(".config/opencode/plugins/sidetouchbar.js") }
    var codexConfigURL: URL { home.appendingPathComponent(".codex/config.toml") }

    var isClaudeAvailable: Bool { fileManager.fileExists(atPath: home.appendingPathComponent(".claude").path) }
    var isOpenCodeAvailable: Bool {
        fileManager.fileExists(atPath: home.appendingPathComponent(".config/opencode").path)
            || NSWorkspaceAppLookup.isInstalled("ai.opencode.desktop")
    }
    var isCodexAvailable: Bool { fileManager.fileExists(atPath: home.appendingPathComponent(".codex").path) }

    static let claudeEvents = [
        "SessionStart", "UserPromptSubmit", "PermissionRequest", "PostToolUse", "PostToolUseFailure",
        "Notification", "Stop", "StopFailure", "SessionEnd",
    ]

    /// Tests pass temporary directories; the app uses the real home and support folders.
    init(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        supportURL: URL = AgentMonitor.baseURL
    ) {
        self.home = home
        self.supportURL = supportURL
        refresh()
    }

    func refresh() {
        let settings = (try? readClaudeSettings()) ?? [:]
        let hooks = settings["hooks"] as? [String: Any] ?? [:]
        claudeHooksInstalled = hooks.values.contains { groups in
            (groups as? [[String: Any]] ?? []).contains(where: containsOurHandler)
        }
        let statusCommand = (settings["statusLine"] as? [String: Any])?["command"] as? String
        claudeStatusLineInstalled = statusCommand?.contains(statusScriptURL.path) ?? false
        openCodeInstalled = fileManager.fileExists(atPath: openCodePluginURL.path)
        let codex = (try? String(contentsOf: codexConfigURL, encoding: .utf8)) ?? ""
        codexInstalled = codex.contains(eventScriptURL.path)
    }

    // MARK: - Claude Code hooks

    func installClaudeHooks() throws {
        try writeScripts()
        var settings = try readClaudeSettings()
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for event in Self.claudeEvents {
            var groups = hooks[event] as? [[String: Any]] ?? []
            guard !groups.contains(where: containsOurHandler) else { continue }
            groups.append([
                "hooks": [[
                    "type": "command",
                    "command": "\(Self.shellQuote(eventScriptURL.path)) claude \(event)",
                    "async": true,
                ]],
            ])
            hooks[event] = groups
        }
        settings["hooks"] = hooks
        try writeClaudeSettings(settings)
        refresh()
    }

    func uninstallClaudeHooks() throws {
        var settings = try readClaudeSettings()
        guard var hooks = settings["hooks"] as? [String: Any] else { return }
        for (event, value) in hooks {
            let groups = (value as? [[String: Any]] ?? []).compactMap { group -> [String: Any]? in
                var group = group
                let handlers = (group["hooks"] as? [[String: Any]] ?? []).filter { !isOurHandler($0) }
                if handlers.isEmpty { return nil }
                group["hooks"] = handlers
                return group
            }
            hooks[event] = groups.isEmpty ? nil : groups
        }
        settings["hooks"] = hooks.isEmpty ? nil : hooks
        try writeClaudeSettings(settings)
        refresh()
    }

    // MARK: - Claude Code status line

    /// Wraps any existing status line: the wrapper records session data and
    /// still prints the original status line.
    func installClaudeStatusLine() throws {
        try writeScripts()
        var settings = try readClaudeSettings()
        var statusLine = settings["statusLine"] as? [String: Any] ?? ["type": "command"]
        let current = statusLine["command"] as? String ?? ""
        if !current.contains(statusScriptURL.path) {
            try current.write(to: originalStatusLineURL, atomically: true, encoding: .utf8)
        }
        statusLine["type"] = "command"
        statusLine["command"] = Self.shellQuote(statusScriptURL.path)
        settings["statusLine"] = statusLine
        try writeClaudeSettings(settings)
        refresh()
    }

    func uninstallClaudeStatusLine() throws {
        var settings = try readClaudeSettings()
        guard var statusLine = settings["statusLine"] as? [String: Any],
              (statusLine["command"] as? String)?.contains(statusScriptURL.path) == true else { return }
        let original = (try? String(contentsOf: originalStatusLineURL, encoding: .utf8)) ?? ""
        if original.isEmpty {
            settings["statusLine"] = nil
        } else {
            statusLine["command"] = original
            settings["statusLine"] = statusLine
        }
        try writeClaudeSettings(settings)
        try? fileManager.removeItem(at: originalStatusLineURL)
        refresh()
    }

    // MARK: - OpenCode

    func installOpenCode() throws {
        try fileManager.createDirectory(at: openCodePluginURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.openCodePlugin.write(to: openCodePluginURL, atomically: true, encoding: .utf8)
        refresh()
    }

    func uninstallOpenCode() throws {
        if fileManager.fileExists(atPath: openCodePluginURL.path) {
            try fileManager.removeItem(at: openCodePluginURL)
        }
        refresh()
    }

    // MARK: - Codex

    enum IntegrationError: LocalizedError {
        case codexNotifyInUse
        case unreadableSettings(String)

        var errorDescription: String? {
            switch self {
            case .codexNotifyInUse:
                tr("~/.codex/config.toml 里已经有 notify 设置，为避免覆盖没有修改。")
            case .unreadableSettings(let path):
                tr("无法读取 %@，为避免损坏没有修改。", path)
            }
        }
    }

    func installCodex() throws {
        try writeScripts()
        var text = (try? String(contentsOf: codexConfigURL, encoding: .utf8)) ?? ""
        guard !text.contains(eventScriptURL.path) else { return }
        let hasNotify = text.split(separator: "\n").contains {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("notify")
        }
        if hasNotify { throw IntegrationError.codexNotifyInUse }
        // Top-level keys must come before the first [table].
        let line = "notify = [\"\(eventScriptURL.path)\", \"codex\", \"turn-complete\"]\n"
        text = line + text
        try backup(codexConfigURL)
        try fileManager.createDirectory(at: codexConfigURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: codexConfigURL, atomically: true, encoding: .utf8)
        refresh()
    }

    func uninstallCodex() throws {
        guard let text = try? String(contentsOf: codexConfigURL, encoding: .utf8) else { return }
        let kept = text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.contains(eventScriptURL.path) }
            .joined(separator: "\n")
        try backup(codexConfigURL)
        try kept.write(to: codexConfigURL, atomically: true, encoding: .utf8)
        refresh()
    }

    // MARK: - Files

    private func readClaudeSettings() throws -> [String: Any] {
        guard fileManager.fileExists(atPath: claudeSettingsURL.path) else { return [:] }
        let data = try Data(contentsOf: claudeSettingsURL)
        if data.isEmpty { return [:] }
        guard let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IntegrationError.unreadableSettings(claudeSettingsURL.path)
        }
        return settings
    }

    private func writeClaudeSettings(_ settings: [String: Any]) throws {
        try backup(claudeSettingsURL)
        try fileManager.createDirectory(at: claudeSettingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: claudeSettingsURL, options: .atomic)
    }

    private func backup(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let backupURL = url.appendingPathExtension("sidetouchbar-backup-\(formatter.string(from: Date()))")
        if !fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.copyItem(at: url, to: backupURL)
        }
    }

    private func writeScripts() throws {
        try fileManager.createDirectory(at: binURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: statusURL, withIntermediateDirectories: true)
        for (url, script) in [(eventScriptURL, Self.eventScript), (statusScriptURL, Self.statusScript)] {
            try script.write(to: url, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }

    private func isOurHandler(_ handler: [String: Any]) -> Bool {
        (handler["command"] as? String)?.contains(eventScriptURL.path) ?? false
    }

    private func containsOurHandler(_ group: [String: Any]) -> Bool {
        (group["hooks"] as? [[String: Any]] ?? []).contains(where: isOurHandler)
    }

    static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - Scripts

    /// Hook handler. Usage: `agent-event <agent> <event> [json]`; the JSON
    /// comes on stdin (Claude Code) or as the last argument (Codex).
    static let eventScript = #"""
    #!/bin/sh
    # Side Touch Bar: forwards coding agent events to the app. Safe to delete;
    # remove the integration from Side Touch Bar settings first.
    base="$HOME/Library/Application Support/SideTouchBar"
    app_pid=$(/bin/cat "$base/app.pid" 2>/dev/null) || exit 0
    kill -0 "$app_pid" 2>/dev/null || exit 0
    if [ -n "$3" ]; then input="$3"; else input=$(/bin/cat); fi
    case "$input" in *[![:space:]]*) ;; *) input="null" ;; esac
    parent=$(/bin/ps -o ppid= -p "$PPID" 2>/dev/null | /usr/bin/tr -d ' ')
    time=$(/usr/bin/perl -MTime::HiRes=time -e 'printf "%.6f", time' 2>/dev/null || /bin/date +%s)
    inbox="$base/agents/inbox"
    /bin/mkdir -p "$inbox" || exit 0
    name="$time-$$"
    printf '{"agent":"%s","event":"%s","time":%s,"pids":[%s%s],"payload":%s}\n' \
      "$1" "$2" "$time" "$PPID" "${parent:+,$parent}" "$input" > "$inbox/.$name" \
      && /bin/mv -f "$inbox/.$name" "$inbox/$name.json"
    exit 0
    """#

    /// Claude Code status line wrapper: saves the session snapshot for the bar,
    /// then prints the user's previous status line, or a short default.
    static let statusScript = #"""
    #!/bin/sh
    # Side Touch Bar status line wrapper. Remove it from Side Touch Bar settings
    # to restore your previous status line.
    base="$HOME/Library/Application Support/SideTouchBar"
    input=$(/bin/cat)
    session=$(printf '%s' "$input" | /usr/bin/sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([A-Za-z0-9_-]*\)".*/\1/p' | /usr/bin/head -n 1)
    if [ -n "$session" ]; then
      dir="$base/agents/status"
      /bin/mkdir -p "$dir" && printf '%s' "$input" > "$dir/.$session" && /bin/mv -f "$dir/.$session" "$dir/$session.json"
    fi
    original=$(/bin/cat "$base/statusline-original" 2>/dev/null)
    if [ -n "$original" ]; then
      printf '%s' "$input" | /bin/sh -c "$original"
    else
      model=$(printf '%s' "$input" | /usr/bin/sed -n 's/.*"display_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | /usr/bin/head -n 1)
      pct=$(printf '%s' "$input" | /usr/bin/sed -n 's/.*"context_window"\(.*\)/\1/p' | /usr/bin/sed -n 's/^[^}]*"used_percentage"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | /usr/bin/head -n 1)
      printf '%s%s\n' "${model:-Claude}" "${pct:+ · ctx $pct%}"
    fi
    """#

    /// OpenCode V2 server plugin, auto-loaded from the global plugins directory.
    static let openCodePlugin = #"""
    // Side Touch Bar: forwards OpenCode session events to the app.
    // Remove it from Side Touch Bar settings, or delete this file.
    import { Plugin } from "@opencode/plugin"
    import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs"
    import { homedir } from "node:os"
    import { join } from "node:path"

    const base = join(homedir(), "Library", "Application Support", "SideTouchBar")
    const inbox = join(base, "agents", "inbox")
    const types = [
      "session.execution.started",
      "session.execution.succeeded",
      "session.execution.failed",
      "session.execution.interrupted",
      "permission.asked",
      "permission.replied",
      "session.deleted",
    ]

    function appRunning() {
      try {
        process.kill(Number(readFileSync(join(base, "app.pid"), "utf8")), 0)
        return true
      } catch {
        return false
      }
    }

    function forward(event) {
      if (!appRunning()) return
      try {
        mkdirSync(inbox, { recursive: true })
        const time = (Date.now() / 1000).toFixed(6)
        const name = `${time}-${process.pid}-${Math.random().toString(36).slice(2, 8)}.json`
        const data = event.data ?? {}
        const payload = {
          session_id: data.sessionID,
          cwd: event.location?.directory,
          message: data.message,
          action: data.action,
          resources: data.resources,
        }
        writeFileSync(join(inbox, "." + name), JSON.stringify({ agent: "opencode", event: event.type, time, pids: [], payload }))
        renameSync(join(inbox, "." + name), join(inbox, name))
      } catch {}
    }

    export default Plugin.define({
      id: "sidetouchbar",
      setup(ctx) {
        const controller = new AbortController()
        void (async () => {
          try {
            for await (const event of ctx.event.subscribe({ types, signal: controller.signal })) forward(event)
          } catch {}
        })()
        return () => controller.abort()
      },
    })
    """#
}

enum NSWorkspaceAppLookup {
    static func isInstalled(_ bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }
}

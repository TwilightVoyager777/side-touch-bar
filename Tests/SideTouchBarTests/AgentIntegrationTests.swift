import Foundation
import Testing
@testable import SideTouchBar

/// Installs and removes integrations against a throwaway home directory.
/// Nothing here reads or writes the real ~/.claude, ~/.codex or ~/.config.
@MainActor
@Suite(.serialized)
final class AgentIntegrationTests {
    let root: URL
    let home: URL
    let support: URL
    let integration: AgentIntegration

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SideTouchBarTests-\(UUID().uuidString)", isDirectory: true)
        home = root.appendingPathComponent("home", isDirectory: true)
        support = root.appendingPathComponent("support", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        // Guard against ever touching the real home directory.
        precondition(home.path.hasPrefix(FileManager.default.temporaryDirectory.path))
        integration = AgentIntegration(home: home, supportURL: support)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Helpers

    private var settingsURL: URL { home.appendingPathComponent(".claude/settings.json") }

    private func writeSettings(_ json: String) throws {
        try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try json.write(to: settingsURL, atomically: true, encoding: .utf8)
    }

    private func readSettings() throws -> [String: Any] {
        let data = try Data(contentsOf: settingsURL)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func ourHandlers(in settings: [String: Any], event: String) -> [[String: Any]] {
        let groups = (settings["hooks"] as? [String: Any])?[event] as? [[String: Any]] ?? []
        return groups.flatMap { $0["hooks"] as? [[String: Any]] ?? [] }
            .filter { ($0["command"] as? String)?.contains(integration.eventScriptURL.path) == true }
    }

    private func backups() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: settingsURL.deletingLastPathComponent().path)
            .filter { $0.contains("sidetouchbar-backup") }
    }

    // MARK: - Claude Code hooks

    @Test func installsHooksIntoMissingSettings() throws {
        try integration.installClaudeHooks()

        let settings = try readSettings()
        for event in AgentIntegration.claudeEvents {
            let handlers = ourHandlers(in: settings, event: event)
            #expect(handlers.count == 1, "\(event)")
            #expect(handlers.first?["async"] as? Bool == true)
            #expect((handlers.first?["command"] as? String)?.hasSuffix(" claude \(event)") == true)
        }
        #expect(integration.claudeHooksInstalled)
    }

    @Test func keepsExistingSettingsAndHooks() throws {
        try writeSettings("""
        {"model": "opus", "permissions": {"allow": ["Bash(ls)"]},
         "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "say done"}]}]}}
        """)

        try integration.installClaudeHooks()

        let settings = try readSettings()
        #expect(settings["model"] as? String == "opus")
        #expect(((settings["permissions"] as? [String: Any])?["allow"] as? [String]) == ["Bash(ls)"])
        let stopGroups = (settings["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]] ?? []
        let commands = stopGroups.flatMap { $0["hooks"] as? [[String: Any]] ?? [] }.compactMap { $0["command"] as? String }
        #expect(commands.contains("say done"))
        #expect(ourHandlers(in: settings, event: "Stop").count == 1)
        #expect(try backups().count == 1)
    }

    @Test func installingTwiceAddsNoDuplicates() throws {
        try integration.installClaudeHooks()
        try integration.installClaudeHooks()

        let settings = try readSettings()
        for event in AgentIntegration.claudeEvents {
            #expect(ourHandlers(in: settings, event: event).count == 1, "\(event)")
        }
    }

    @Test func uninstallRemovesOnlyOurHooks() throws {
        try writeSettings("""
        {"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "say done"}]}]}}
        """)
        try integration.installClaudeHooks()

        try integration.uninstallClaudeHooks()

        let settings = try readSettings()
        let hooks = settings["hooks"] as? [String: Any] ?? [:]
        #expect(Array(hooks.keys) == ["Stop"])
        let commands = (hooks["Stop"] as? [[String: Any]] ?? []).flatMap { $0["hooks"] as? [[String: Any]] ?? [] }
            .compactMap { $0["command"] as? String }
        #expect(commands == ["say done"])
        #expect(!integration.claudeHooksInstalled)
    }

    @Test func uninstallLeavesNoEmptyHooksObject() throws {
        try integration.installClaudeHooks()
        try integration.uninstallClaudeHooks()

        #expect(try readSettings()["hooks"] == nil)
    }

    @Test func refusesUnreadableSettings() throws {
        try writeSettings("{ this is not json")
        let before = try String(contentsOf: settingsURL, encoding: .utf8)

        #expect(throws: (any Error).self) { try self.integration.installClaudeHooks() }
        #expect(try String(contentsOf: settingsURL, encoding: .utf8) == before)
    }

    @Test func writesExecutableScripts() throws {
        try integration.installClaudeHooks()

        for url in [integration.eventScriptURL, integration.statusScriptURL] {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            #expect((attributes[.posixPermissions] as? Int) == 0o755)
            #expect(try String(contentsOf: url, encoding: .utf8).hasPrefix("#!/bin/sh"))
        }
    }

    // MARK: - Status line

    @Test func wrapsAndRestoresExistingStatusLine() throws {
        try writeSettings("""
        {"statusLine": {"type": "command", "command": "~/.claude/statusline.sh", "padding": 2}}
        """)

        try integration.installClaudeStatusLine()
        var statusLine = try #require(try readSettings()["statusLine"] as? [String: Any])
        #expect((statusLine["command"] as? String)?.contains(integration.statusScriptURL.path) == true)
        #expect(statusLine["padding"] as? Int == 2)
        #expect(integration.claudeStatusLineInstalled)

        try integration.uninstallClaudeStatusLine()
        statusLine = try #require(try readSettings()["statusLine"] as? [String: Any])
        #expect(statusLine["command"] as? String == "~/.claude/statusline.sh")
        #expect(statusLine["padding"] as? Int == 2)
    }

    @Test func removesStatusLineThatDidNotExistBefore() throws {
        try integration.installClaudeStatusLine()
        try integration.uninstallClaudeStatusLine()

        #expect(try readSettings()["statusLine"] == nil)
    }

    // MARK: - OpenCode and Codex

    @Test func installsAndRemovesOpenCodePlugin() throws {
        try integration.installOpenCode()
        #expect(FileManager.default.fileExists(atPath: integration.openCodePluginURL.path))
        #expect(integration.openCodePluginURL.path.hasPrefix(home.path))

        try integration.uninstallOpenCode()
        #expect(!FileManager.default.fileExists(atPath: integration.openCodePluginURL.path))
    }

    @Test func addsAndRemovesCodexNotify() throws {
        try FileManager.default.createDirectory(at: integration.codexConfigURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "model = \"o4\"\n\n[profiles.fast]\nmodel = \"mini\"\n".write(to: integration.codexConfigURL, atomically: true, encoding: .utf8)

        try integration.installCodex()
        let installed = try String(contentsOf: integration.codexConfigURL, encoding: .utf8)
        #expect(installed.hasPrefix("notify = ["))
        #expect(installed.contains("[profiles.fast]"))

        try integration.uninstallCodex()
        let removed = try String(contentsOf: integration.codexConfigURL, encoding: .utf8)
        #expect(!removed.contains("notify"))
        #expect(removed.contains("model = \"o4\""))
    }

    @Test func keepsExistingCodexNotify() throws {
        try FileManager.default.createDirectory(at: integration.codexConfigURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "notify = [\"my-notifier\"]\n".write(to: integration.codexConfigURL, atomically: true, encoding: .utf8)

        #expect(throws: AgentIntegration.IntegrationError.self) { try self.integration.installCodex() }
        #expect(try String(contentsOf: integration.codexConfigURL, encoding: .utf8) == "notify = [\"my-notifier\"]\n")
    }
}

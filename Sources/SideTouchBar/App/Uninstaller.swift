import Foundation
import ServiceManagement

/// `SideTouchBar --prepare-uninstall`, used by scripts/uninstall.sh: removes
/// every agent integration (restoring the user's own settings) and the login
/// item, so nothing points at the app after it's deleted.
@MainActor
enum Uninstaller {
    static func run() -> Bool {
        let integration = AgentIntegration.shared
        var succeeded = true

        let steps: [(String, Bool, () throws -> Void)] = [
            ("Claude Code hooks", integration.claudeHooksInstalled, integration.uninstallClaudeHooks),
            ("Claude Code status line", integration.claudeStatusLineInstalled, integration.uninstallClaudeStatusLine),
            ("OpenCode plugin", integration.openCodeInstalled, integration.uninstallOpenCode),
            ("Codex notify", integration.codexInstalled, integration.uninstallCodex),
        ]
        for (name, installed, remove) in steps where installed {
            do {
                try remove()
                print("Removed \(name).")
            } catch {
                print("Couldn't remove \(name): \(error.localizedDescription)")
                succeeded = false
            }
        }

        if SMAppService.mainApp.status == .enabled {
            try? SMAppService.mainApp.unregister()
            print("Removed the login item.")
        }
        return succeeded
    }
}

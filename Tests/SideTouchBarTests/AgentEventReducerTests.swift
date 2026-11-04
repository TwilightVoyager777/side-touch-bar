import Testing
@testable import SideTouchBar

/// Session status as hook and plugin events arrive.
struct AgentEventReducerTests {
    private func apply(_ events: [(String, [String: Any])], agent: AgentKind = .claude) -> AgentSession {
        events.reduce(AgentSession(id: "s", agent: agent)) { session, event in
            AgentEventReducer.apply(event: event.0, payload: event.1, to: session)
        }
    }

    private let bash: [String: Any] = ["tool_name": "Bash", "tool_input": ["command": "npm test"]]
    private let edit: [String: Any] = ["tool_name": "Edit", "tool_input": ["file_path": "/p/src/app.swift"]]

    @Test func promptStartsRunning() {
        #expect(apply([("UserPromptSubmit", [:])]).status == .running)
    }

    @Test func permissionRequestWaitsWithCommand() {
        let session = apply([("UserPromptSubmit", [:]), ("PermissionRequest", bash)])
        #expect(session.status == .needsPermission)
        #expect(session.detail == "npm test")
    }

    @Test func permissionRequestForFileShowsFileName() {
        #expect(apply([("PermissionRequest", edit)]).detail == "Edit app.swift")
    }

    @Test func otherParallelToolDoesNotClearPermission() {
        let session = apply([("PermissionRequest", bash), ("PostToolUse", edit)])
        #expect(session.status == .needsPermission)
    }

    @Test func approvedToolResumesRunning() {
        let session = apply([("PermissionRequest", bash), ("PostToolUse", bash)])
        #expect(session.status == .running)
        #expect(session.detail == nil)
    }

    @Test func failedApprovedToolAlsoResumes() {
        #expect(apply([("PermissionRequest", bash), ("PostToolUseFailure", bash)]).status == .running)
    }

    @Test func stopIsDoneWithSummary() {
        let session = apply([("UserPromptSubmit", [:]), ("Stop", ["last_assistant_message": "All tests pass."])])
        #expect(session.status == .done)
        #expect(session.detail == "All tests pass.")
    }

    @Test func stopFailureIsFailed() {
        #expect(apply([("UserPromptSubmit", [:]), ("StopFailure", [:])]).status == .failed)
    }

    @Test func permissionNotificationWaits() {
        let session = apply([("UserPromptSubmit", [:]), ("Notification", ["notification_type": "permission_prompt", "message": "Claude needs your permission"])])
        #expect(session.status == .needsPermission)
    }

    @Test func idleNotificationKeepsDone() {
        let session = apply([("Stop", [:]), ("Notification", ["notification_type": "idle_prompt"])])
        #expect(session.status == .done)
    }

    @Test func sessionEndRemovesSession() {
        #expect(AgentEventReducer.endsSession("SessionEnd"))
        #expect(AgentEventReducer.endsSession("session.deleted"))
        #expect(!AgentEventReducer.endsSession("Stop"))
    }

    @Test func openCodeEvents() {
        #expect(apply([("session.execution.started", [:])], agent: .opencode).status == .running)
        let asked = apply([("session.execution.started", [:]), ("permission.asked", ["action": "bash", "resources": ["rm -rf build"]])], agent: .opencode)
        #expect(asked.status == .needsPermission)
        #expect(asked.detail == "bash rm -rf build")
        #expect(apply([("permission.asked", [:]), ("permission.replied", [:])], agent: .opencode).status == .running)
        #expect(apply([("session.execution.succeeded", [:])], agent: .opencode).status == .done)
        #expect(apply([("session.execution.failed", [:])], agent: .opencode).status == .failed)
    }

    @Test func codexTurnCompleteIsDone() {
        #expect(apply([("turn-complete", ["last-assistant-message": "Done"])], agent: .codex).status == .done)
    }

    @Test func eventsFromOtherAgentsAreIgnored() {
        #expect(apply([("permission.asked", [:])], agent: .claude).status == .idle)
    }
}

/// Recognizing coding agents among a terminal's processes.
struct AgentKindTests {
    @Test func recognizesNativeBinaries() {
        #expect(AgentKind.detect(name: "claude", arguments: { [] }) == .claude)
        #expect(AgentKind.detect(name: "codex", arguments: { [] }) == .codex)
        #expect(AgentKind.detect(name: "opencode-cli", arguments: { [] }) == .opencode)
    }

    @Test func recognizesAgentsStartedByNode() {
        #expect(AgentKind.detect(name: "node", arguments: { ["node", "/usr/local/bin/claude"] }) == .claude)
        #expect(AgentKind.detect(name: "bun", arguments: { ["bun", "/x/gemini"] }) == .gemini)
    }

    @Test func ignoresOtherProcesses() {
        #expect(AgentKind.detect(name: "zsh", arguments: { ["zsh"] }) == nil)
        #expect(AgentKind.detect(name: "claudette", arguments: { [] }) == nil)
        #expect(AgentKind.detect(name: "node", arguments: { ["node", "server.js"] }) == nil)
    }
}

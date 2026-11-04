import AppKit

/// Acting on an agent session from the bar: jump to its window, answer its prompt.
@MainActor
enum AgentSessionActions {
    static func jump(to session: AgentSession) {
        guard let app = AgentMonitor.shared.app(for: session) else {
            NSSound.beep()
            return
        }
        app.activate()
        raiseWindow(of: app, matching: session.title)
        AgentMonitor.shared.acknowledge(session.id)
    }

    /// Brings the session's terminal forward, then presses the answer key there.
    static func answer(_ answer: AgentAnswer, for session: AgentSession) {
        guard Permissions.shared.requestIfNeeded(),
              let combo = AIPresets.keys(for: answer, agent: session.agent) else { return }
        let alreadyFront = FrontmostAppMonitor.shared.app?.processIdentifier == AgentMonitor.shared.app(for: session)?.processIdentifier
        if !alreadyFront { jump(to: session) }
        Task { @MainActor in
            if !alreadyFront { try? await Task.sleep(for: .milliseconds(300)) }
            KeySender.send(combo)
            AgentMonitor.shared.markRunning(session.id)
        }
    }

    /// Raises the window whose title mentions the session's folder, if any.
    private static func raiseWindow(of app: NSRunningApplication, matching title: String) {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return }
        for window in windows {
            var windowTitle: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &windowTitle)
            if let text = windowTitle as? String, text.localizedCaseInsensitiveContains(title) {
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                return
            }
        }
    }
}

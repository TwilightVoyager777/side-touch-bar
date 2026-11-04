import AppKit
import Carbon.HIToolbox

/// Moving context into AI tools: selected code, the current web page, and screenshots.
@MainActor
enum AIActions {
    static func run(_ command: AICommand) {
        switch command {
        case .sendSelection: sendSelection()
        case .sendPage: sendPage()
        case .screenshot: screenshot()
        }
    }

    // MARK: - Send selected code

    /// Copies the selection in the frontmost app and pastes it, with its file
    /// path and a code fence, into the AI target (without sending it).
    static func sendSelection() {
        guard Permissions.shared.requestIfNeeded(), let source = FrontmostAppMonitor.shared.app else { return }
        let location = documentLocation(of: source)
        copyFromFrontmost { text in
            guard let text, !text.isEmpty else { return }
            deliver(format(code: text, location: location), excluding: source)
        }
    }

    // MARK: - Send the current web page

    static func sendPage() {
        guard Permissions.shared.requestIfNeeded(), let source = FrontmostAppMonitor.shared.app else { return }
        let title = windowTitle(of: source)
        // Focus the address bar, copy the URL, then leave the address bar.
        KeySender.send(KeyCombo(kVK_ANSI_L, .maskCommand))
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            copyFromFrontmost { url in
                KeySender.send(KeyCombo(kVK_Escape))
                guard let url, !url.isEmpty else { return }
                let text = [title, url].compactMap { $0 }.joined(separator: "\n") + "\n"
                deliver(text, excluding: source)
            }
        }
    }

    // MARK: - Screenshot

    /// Lets the user select a screen region, then pastes the image into the
    /// frontmost app (Claude Code in a terminal pastes images with ⌃V).
    static func screenshot() {
        guard Permissions.shared.requestIfNeeded() else { return }
        let target = FrontmostAppMonitor.shared.app
        let context = AIContextMonitor.shared.context
        let before = NSPasteboard.general.changeCount

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-c"]
        process.terminationHandler = { finished in
            let succeeded = finished.terminationStatus == 0
            Task { @MainActor in
                guard succeeded, NSPasteboard.general.changeCount != before else { return }
                target?.activate()
                try? await Task.sleep(for: .milliseconds(250))
                let combo = context.isTerminalAgent
                    ? KeyCombo(kVK_ANSI_V, .maskControl)
                    : KeyCombo(kVK_ANSI_V, .maskCommand)
                KeySender.send(combo)
            }
        }
        try? process.run()
    }

    // MARK: - Delivery

    struct Delivery {
        let app: NSRunningApplication
        let isTerminal: Bool
    }

    /// Where to send context, following the setting.
    static func deliveryTarget(excluding source: NSRunningApplication?) -> Delivery? {
        func desktop(_ app: AIDesktopApp) -> Delivery? {
            NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).first
                .map { Delivery(app: $0, isTerminal: false) }
        }

        switch Settings.shared.aiSendTarget {
        case .automatic:
            if let last = AIContextMonitor.shared.lastTarget, last.app != source, !last.app.isTerminated {
                return Delivery(app: last.app, isTerminal: last.context.isTerminalAgent)
            }
            return AIDesktopApp.allCases.lazy.compactMap(desktop).first
        case .terminalAgent:
            if let last = AIContextMonitor.shared.lastTarget, last.context.isTerminalAgent, !last.app.isTerminated {
                return Delivery(app: last.app, isTerminal: true)
            }
            return AgentKind.allCases.lazy.compactMap(AIContextMonitor.terminal(running:)).first
                .map { Delivery(app: $0, isTerminal: true) }
        case .claudeDesktop: return desktop(.claude)
        case .opencodeDesktop: return desktop(.opencode)
        case .chatgpt: return desktop(.chatgpt)
        }
    }

    static func deliver(_ text: String, excluding source: NSRunningApplication?) {
        guard let target = deliveryTarget(excluding: source) else {
            NSSound.beep()
            return
        }
        target.app.activate()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            TextInserter.paste(text)
        }
    }

    // MARK: - Helpers

    /// Sends ⌘C to the frontmost app and hands over the copied text, then
    /// puts the previous clipboard back.
    private static func copyFromFrontmost(_ completion: @escaping @MainActor (String?) -> Void) {
        let pasteboard = NSPasteboard.general
        let saved = ClipboardSnapshot.take()
        KeySender.send(KeyCombo(kVK_ANSI_C, .maskCommand))
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            let copied = pasteboard.changeCount != saved.changeCount ? pasteboard.string(forType: .string) : nil
            saved.restore()
            completion(copied)
        }
    }

    private static func focusedWindow(of app: NSRunningApplication) -> AXUIElement? {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &window) == .success else { return nil }
        return (window as! AXUIElement)
    }

    static func windowTitle(of app: NSRunningApplication) -> String? {
        guard let window = focusedWindow(of: app) else { return nil }
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
        return (title as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The edited file's path when the app reports it, otherwise the window title.
    private static func documentLocation(of app: NSRunningApplication) -> String? {
        if let window = focusedWindow(of: app) {
            var document: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXDocumentAttribute as CFString, &document) == .success,
               let string = document as? String, let url = URL(string: string), url.isFileURL {
                return (url.path as NSString).abbreviatingWithTildeInPath
            }
        }
        return windowTitle(of: app)
    }

    private static func format(code: String, location: String?) -> String {
        let language = location.map { languages[($0 as NSString).pathExtension.lowercased()] ?? "" } ?? ""
        var text = ""
        if let location { text += "`\(location)`\n" }
        text += "```\(language)\n\(code.trimmingCharacters(in: .newlines))\n```\n"
        return text
    }

    private static let languages: [String: String] = [
        "swift": "swift", "m": "objc", "h": "c", "c": "c", "cpp": "cpp", "cc": "cpp", "hpp": "cpp",
        "java": "java", "kt": "kotlin", "kts": "kotlin", "scala": "scala", "go": "go", "rs": "rust",
        "py": "python", "rb": "ruby", "php": "php", "js": "javascript", "jsx": "jsx", "ts": "typescript",
        "tsx": "tsx", "vue": "vue", "svelte": "svelte", "css": "css", "scss": "scss", "html": "html",
        "json": "json", "yaml": "yaml", "yml": "yaml", "toml": "toml", "xml": "xml", "sql": "sql",
        "sh": "bash", "zsh": "bash", "md": "markdown", "dart": "dart", "lua": "lua", "cs": "csharp",
    ]
}

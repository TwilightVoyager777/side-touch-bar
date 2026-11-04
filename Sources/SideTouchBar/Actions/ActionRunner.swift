import AppKit
import Carbon.HIToolbox

@MainActor
enum ActionRunner {
    static func run(_ action: BarAction) {
        let app = FrontmostAppMonitor.shared.app
        switch action {
        case .keys(let combo):
            sendKeys(combo)
        case .keySequence(let combos):
            guard Permissions.shared.requestIfNeeded() else { return }
            Task { @MainActor in
                for (index, combo) in combos.enumerated() {
                    if index > 0 { try? await Task.sleep(for: .milliseconds(70)) }
                    KeySender.send(combo)
                }
            }
        case .system(let command):
            run(command)
        case .menu(let command):
            guard Permissions.shared.requestIfNeeded() else { return }
            if command.paths.contains(where: { MenuInvoker.press($0, in: app) }) { return }
            if let fallback = command.fallback { KeySender.send(fallback) }
        case .menuSearch(let keywords, let fallback):
            guard Permissions.shared.requestIfNeeded() else { return }
            if !MenuInvoker.pressFirst(matching: keywords, in: app), let fallback {
                KeySender.send(fallback)
            }
        case .ai(let command):
            AIActions.run(command)
        case .openURL(let string):
            openURL(string, preferring: app)
        case .text(let text, let submit):
            TextInserter.insert(text, submit: submit)
        case .view:
            // Handled by the views, which own the bar state.
            break
        }
    }

    /// Opens a link in the frontmost app when it is a browser, otherwise in the default browser.
    private static func openURL(_ string: String, preferring app: NSRunningApplication?) {
        guard let url = URL(string: string) else { return }
        if let app, let bundleURL = app.bundleURL, AppPresets.browser.bundleIDs.contains(app.bundleIdentifier ?? "") {
            NSWorkspace.shared.open([url], withApplicationAt: bundleURL, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    static func run(_ command: SystemCommand) {
        switch command {
        case .escape:
            sendKeys(KeyCombo(kVK_Escape))

        case .playPause:
            sendMedia(.play)
        case .next:
            sendMedia(.next)
        case .previous:
            sendMedia(.previous)

        // Prefer the real media keys (system HUD + feedback sound); fall back to CoreAudio.
        case .volumeUp:
            isTrusted ? MediaKeySender.send(.soundUp) : Volume.step(1 / 16)
        case .volumeDown:
            isTrusted ? MediaKeySender.send(.soundDown) : Volume.step(-1 / 16)
        case .mute:
            isTrusted ? MediaKeySender.send(.mute) : Volume.toggleMute()

        case .brightnessUp:
            Brightness.get() != nil ? Brightness.step(1 / 16) : sendMedia(.brightnessUp)
        case .brightnessDown:
            Brightness.get() != nil ? Brightness.step(-1 / 16) : sendMedia(.brightnessDown)

        case .keyboardBrightnessUp:
            if !KeyboardBrightness.step(1 / 16) { sendMedia(.illuminationUp) }
        case .keyboardBrightnessDown:
            if !KeyboardBrightness.step(-1 / 16) { sendMedia(.illuminationDown) }

        case .missionControl:
            openApp(["/System/Applications/Mission Control.app"])
        case .apps:
            openApp(["/System/Applications/Apps.app", "/System/Applications/Launchpad.app"])
        case .siri:
            openApp(["/System/Applications/Siri.app"])
        case .screenshot:
            openApp(["/System/Applications/Utilities/Screenshot.app"])
        case .shortcuts:
            openApp(["/System/Applications/Shortcuts.app"])
        case .screenSaver:
            openApp(["/System/Library/CoreServices/ScreenSaverEngine.app"])

        case .lockScreen:
            sendKeys(KeyCombo(kVK_ANSI_Q, [.maskControl, .maskCommand]))
        case .showDesktop:
            sendKeys(KeyCombo(kVK_F11))
        case .spotlight:
            sendKeys(KeyCombo(kVK_Space, .maskCommand))
        case .inputSource:
            sendKeys(KeyCombo(kVK_Space, .maskControl))
        case .emoji:
            sendKeys(KeyCombo(kVK_Space, [.maskControl, .maskCommand]))

        case .nightShift:
            NightShift.toggle()
        case .darkMode:
            DarkMode.toggle()
        case .sleep:
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["sleepnow"]
            try? process.run()
        }
    }

    private static var isTrusted: Bool {
        Permissions.shared.refresh()
        return Permissions.shared.isTrusted
    }

    static func sendKeys(_ combo: KeyCombo) {
        guard Permissions.shared.requestIfNeeded() else { return }
        KeySender.send(combo)
    }

    private static func sendMedia(_ key: MediaKey) {
        guard Permissions.shared.requestIfNeeded() else { return }
        MediaKeySender.send(key)
    }

    /// Types text into the focused app, e.g. an emoji.
    static func type(_ text: String) {
        guard Permissions.shared.requestIfNeeded() else { return }
        KeySender.type(text)
    }

    private static func openApp(_ candidates: [String]) {
        guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: .init())
    }
}

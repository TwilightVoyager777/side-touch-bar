import AppKit
import Carbon.HIToolbox

@MainActor
enum ActionRunner {
    static func run(_ action: BarAction) {
        switch action {
        case .keys(let combo):
            sendKeys(combo)
        case .system(let command):
            run(command)
        case .emojiPicker:
            // Handled by the view, which owns the bar state.
            break
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

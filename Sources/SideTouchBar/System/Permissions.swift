import AppKit
import ApplicationServices

@MainActor
final class Permissions: ObservableObject {
    static let shared = Permissions()

    @Published private(set) var isTrusted = AXIsProcessTrusted()

    private var timer: Timer?
    private var didPromptThisLaunch = false

    private init() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted { isTrusted = trusted }
    }

    /// Returns whether Accessibility is granted; shows the system prompt at most once per launch.
    func requestIfNeeded() -> Bool {
        refresh()
        if isTrusted { return true }
        if !didPromptThisLaunch {
            didPromptThisLaunch = true
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        return false
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

import AppKit
import ApplicationServices

@MainActor
final class Permissions: ObservableObject {
    static let shared = Permissions()

    @Published private(set) var isTrusted = AXIsProcessTrusted()

    private var timer: Timer?
    private var didPromptThisLaunch = false

    private init() {
        schedule()
    }

    /// Checks every 2 seconds while waiting for the grant, then every 10 to notice a revoke.
    private func schedule() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: isTrusted ? 10 : 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted {
            isTrusted = trusted
            schedule()
        }
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

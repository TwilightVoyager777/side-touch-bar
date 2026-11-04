import AppKit

@MainActor
final class FrontmostAppMonitor: ObservableObject {
    static let shared = FrontmostAppMonitor()

    @Published private(set) var app: NSRunningApplication?
    @Published private(set) var preset: AppPreset = AppPresets.fallback

    private init() {
        update(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.update(app) }
        }
    }

    private func update(_ app: NSRunningApplication?) {
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        self.app = app
        let newPreset = AppPresets.preset(for: app.bundleIdentifier)
        if newPreset.id != preset.id { preset = newPreset }
    }
}

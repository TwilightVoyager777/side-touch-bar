import AppKit

/// The user's Shortcuts, listed and run through the `shortcuts` command line
/// tool, for the Touch Bar "Quick Actions" page.
@MainActor
final class QuickActionsStore: ObservableObject {
    static let shared = QuickActionsStore()

    @Published private(set) var names: [String] = []
    @Published private(set) var isLoading = false

    private var lastLoaded: Date?

    /// Reloads the list at most every 30 seconds.
    func reloadIfNeeded() {
        if isLoading { return }
        if let lastLoaded, Date().timeIntervalSince(lastLoaded) < 30 { return }
        isLoading = true
        Task {
            let output = await Self.runShortcuts(["list"])
            let names = output
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            self.names = names
            self.isLoading = false
            self.lastLoaded = Date()
        }
    }

    func run(_ name: String) {
        Task { _ = await Self.runShortcuts(["run", name]) }
    }

    private nonisolated static func runShortcuts(_ arguments: [String]) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    continuation.resume(returning: String(decoding: data, as: UTF8.self))
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }
}

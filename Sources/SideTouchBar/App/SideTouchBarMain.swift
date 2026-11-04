import AppKit

@main
enum SideTouchBarMain {
    static func main() {
        MainActor.assumeIsolated {
            if CommandLine.arguments.contains("--sizing-report") {
                SizingReport.run()
                return
            }
            if let index = CommandLine.arguments.firstIndex(of: "--render-previews"),
               CommandLine.arguments.indices.contains(index + 1) {
                PreviewRenderer.run(to: CommandLine.arguments[index + 1])
                return
            }
            if CommandLine.arguments.contains("--prepare-uninstall") {
                exit(Uninstaller.run() ? 0 : 1)
            }
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.setActivationPolicy(.accessory)
            app.run()
        }
    }
}

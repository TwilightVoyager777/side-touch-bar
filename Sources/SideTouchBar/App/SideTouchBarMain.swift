import AppKit

@main
enum SideTouchBarMain {
    static func main() {
        MainActor.assumeIsolated {
            if CommandLine.arguments.contains("--sizing-report") {
                SizingReport.run()
                return
            }
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.setActivationPolicy(.accessory)
            app.run()
        }
    }
}

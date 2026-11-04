import AppKit

@MainActor
enum SizingReport {
    static func run() {
        NSApplication.shared.setActivationPolicy(.accessory)
        // name, width pt, height pt, menu bar pt, glass width mm
        let screens: [(String, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            ("14in default 1512x982", 1512, 982, 38, 302.5),
            ("14in larger text 1352x878", 1352, 878, 38, 302.5),
            ("14in more space 1800x1169", 1800, 1169, 38, 302.5),
            ("16in default 1728x1117", 1728, 1117, 38, 345.6),
            ("16in larger text 1496x967", 1496, 967, 38, 345.6),
            ("16in more space 2056x1329", 2056, 1329, 38, 345.6),
            ("13in Air 1470x956", 1470, 956, 38, 286.0),
            ("27in 1440p @1x", 2560, 1440, 30, 602.0),
            ("27in 5K @2x 2560x1440", 2560, 1440, 30, 596.0),
        ]
        print("tallest @1x", BarSizer.tallestHeight(metrics: .standard))
        for (name, width, height, menuBar, mm) in screens {
            let pointsPerMillimeter = width / mm
            let preferred = BarSizer.physicalScale(pointsPerMillimeter: pointsPerMillimeter)
            let available = height - menuBar - BarMetrics.shadowMargin * 2
            let result = BarSizer.fit(preferredScale: preferred, availableHeight: available)
            let tallest = BarSizer.tallestHeight(metrics: result.metrics)
            let button = result.metrics.buttonSize
            print(String(
                format: "%@: button %.0fpt %.1fmm, tallest %.0f of %.0f%@",
                name, button, button / pointsPerMillimeter, tallest, available, result.isShrunkToFit ? " (shrunk)" : ""
            ))
        }
    }
}

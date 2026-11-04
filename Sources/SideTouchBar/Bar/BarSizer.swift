import AppKit
import SwiftUI

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    var isBuiltIn: Bool {
        displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false
    }

    /// Points per millimetre of glass, or nil if the display doesn't report its size.
    var pointsPerMillimeter: CGFloat? {
        guard let displayID else { return nil }
        let size = CGDisplayScreenSize(displayID)
        guard size.width > 0 else { return nil }
        return frame.width / size.width
    }

    /// Vertical range the bars may use: below the menu bar, down to the bottom
    /// edge (a bottom Dock only covers the middle of the screen, not the sides).
    var barBand: ClosedRange<CGFloat> {
        frame.minY...visibleFrame.maxY
    }
}

/// What the settings window shows about the current display and bar size.
@MainActor
final class DisplayStatus: ObservableObject {
    static let shared = DisplayStatus()

    @Published var screenName = ""
    @Published var buttonPoints: CGFloat = 44
    @Published var buttonMillimeters: CGFloat?
    @Published var isShrunkToFit = false

    func update(screen: NSScreen, result: BarSizer.Result) {
        screenName = screen.localizedName
        buttonPoints = result.metrics.buttonSize
        buttonMillimeters = screen.pointsPerMillimeter.map { result.metrics.buttonSize / $0 }
        isShrunkToFit = result.isShrunkToFit
    }
}

/// Chooses bar metrics for a screen: keep buttons the same physical size as on
/// a 14"/16" MacBook Pro, then shrink if the tallest bar state wouldn't fit.
@MainActor
enum BarSizer {
    /// 44pt on a 14"/16" MacBook Pro at default resolution (5.0 pt/mm).
    static let targetButtonMillimeters: CGFloat = 8.8
    static let physicalScaleRange: ClosedRange<CGFloat> = 0.8...1.3
    static let minimumScale: CGFloat = 0.6

    struct Result: Equatable {
        let metrics: BarMetrics
        let isShrunkToFit: Bool
    }

    private static var cache: [String: Result] = [:]

    static func physicalScale(for screen: NSScreen) -> CGFloat {
        screen.pointsPerMillimeter.map(physicalScale(pointsPerMillimeter:)) ?? 1
    }

    static func availableHeight(on screen: NSScreen) -> CGFloat {
        let band = screen.barBand
        return band.upperBound - band.lowerBound - BarMetrics.shadowMargin * 2
    }

    static func metrics(for screen: NSScreen, content: BarContent) -> Result {
        let settings = Settings.shared
        let key = [
            "\(screen.displayID ?? 0)", "\(screen.frame)", "\(screen.visibleFrame)", "\(content)",
            settings.sizePreference.rawValue, settings.compactItems.map(\.rawValue).joined(separator: ","),
            "\(Permissions.shared.isTrusted)",
        ].joined(separator: "|")
        if let cached = cache[key] { return cached }

        let preferred = physicalScale(for: screen) * settings.sizePreference.multiplier
        let result = fit(preferredScale: preferred, availableHeight: availableHeight(on: screen), content: content)
        cache[key] = result
        return result
    }

    static func physicalScale(pointsPerMillimeter: CGFloat) -> CGFloat {
        let scale = targetButtonMillimeters * pointsPerMillimeter / BarMetrics.standard.buttonSize
        return min(max(scale, physicalScaleRange.lowerBound), physicalScaleRange.upperBound)
    }

    static func fit(preferredScale: CGFloat, availableHeight: CGFloat, content: BarContent) -> Result {
        var scale = preferredScale
        // Heights are close to linear in scale; refine a few times to absorb rounding.
        for _ in 0..<4 {
            let tallest = tallestHeight(content: content, metrics: BarMetrics(scale: scale))
            guard tallest > availableHeight else { break }
            scale = max(minimumScale, scale * availableHeight / tallest - 0.01)
            if scale <= minimumScale { break }
        }
        return Result(metrics: BarMetrics(scale: scale), isShrunkToFit: scale < preferredScale - 0.001)
    }

    /// Height of the tallest state this bar can be in (every preset shape,
    /// expanded control strip, slider, fn keys).
    static func tallestHeight(content: BarContent, metrics: BarMetrics) -> CGFloat {
        variants(for: content).map { state in
            let view = BarBody(state: state)
                .environment(\.barMetrics, metrics)
                .fixedSize()
            return NSHostingView(rootView: view).fittingSize.height
        }.max() ?? 0
    }

    private static func variants(for content: BarContent) -> [BarState] {
        func make(_ configure: (BarState) -> Void) -> BarState {
            let state = BarState(side: .left, content: content)
            configure(state)
            return state
        }

        // Presets with the same group shape have the same height.
        var seen = Set<[Int]>()
        let presets = ([AppPresets.fallback] + AppPresets.all).filter { seen.insert($0.groups.map(\.count)).inserted }

        let stripModes: [ControlStripMode] = [.compact, .full, .slider(.volume)]
        switch content {
        case .controlStrip:
            return stripModes.map { mode in make { $0.stripMode = mode } }
        case .appRegion:
            return presets.map { preset in make { $0.presetOverride = preset } }
                + [make { $0.showFunctionKeys = true }]
        case .combined:
            return presets.map { preset in make { $0.presetOverride = preset } }
                + stripModes.dropFirst().map { mode in make { $0.stripMode = mode } }
                + [make { $0.showFunctionKeys = true }]
        }
    }
}

import SwiftUI

enum BarLayout: String, CaseIterable, Identifiable {
    case left, both, right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: "仅左侧"
        case .both: "左右两侧"
        case .right: "仅右侧"
        }
    }
}

enum GlassStyle: String, CaseIterable, Identifiable {
    case regular, clear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .regular: "常规"
        case .clear: "清透"
        }
    }

    var glass: Glass {
        switch self {
        case .regular: .regular
        case .clear: .clear
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
final class Settings: ObservableObject {
    static let shared = Settings()

    static let maxCompactItems = 6
    static let idleDelayOptions: [Double] = [5, 8, 15, 30, 0]

    private let defaults = UserDefaults.standard

    /// Which screen edges show a bar. With a single side, app buttons and the
    /// control strip share one bar, like the original Touch Bar.
    @Published var layout: BarLayout {
        didSet { defaults.set(layout.rawValue, forKey: Keys.layout) }
    }

    /// In two-sided layout: the side that shows the system control strip.
    @Published var controlStripSide: BarSide {
        didSet { defaults.set(controlStripSide.rawValue, forKey: Keys.controlStripSide) }
    }

    @Published var autoHide: Bool {
        didSet { defaults.set(autoHide, forKey: Keys.autoHide) }
    }

    /// Seconds without input before the bar hides; 0 means never.
    @Published var idleDelay: Double {
        didSet { defaults.set(idleDelay, forKey: Keys.idleDelay) }
    }

    @Published var glassStyle: GlassStyle {
        didSet { defaults.set(glassStyle.rawValue, forKey: Keys.glassStyle) }
    }

    @Published var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    /// Buttons of the collapsed control strip, in display order.
    @Published var compactItems: [ControlItem] {
        didSet { defaults.set(compactItems.map(\.rawValue), forKey: Keys.compactItems) }
    }

    var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Keys.hasLaunched) }
        set { defaults.set(newValue, forKey: Keys.hasLaunched) }
    }

    private init() {
        layout = defaults.string(forKey: Keys.layout).flatMap(BarLayout.init) ?? .both
        controlStripSide = defaults.string(forKey: Keys.controlStripSide).flatMap(BarSide.init) ?? .left
        autoHide = defaults.object(forKey: Keys.autoHide) as? Bool ?? true
        idleDelay = defaults.object(forKey: Keys.idleDelay) as? Double ?? 8
        glassStyle = defaults.string(forKey: Keys.glassStyle).flatMap(GlassStyle.init) ?? .regular
        appearance = defaults.string(forKey: Keys.appearance).flatMap(AppearanceMode.init) ?? .system
        compactItems = (defaults.stringArray(forKey: Keys.compactItems)?.compactMap(ControlItem.init))
            ?? ControlItem.defaultCompact
    }

    private enum Keys {
        static let layout = "layout"
        static let controlStripSide = "controlStripSide"
        static let autoHide = "autoHide"
        static let idleDelay = "idleDelay"
        static let glassStyle = "glassStyle"
        static let appearance = "appearance"
        static let compactItems = "compactItems"
        static let hasLaunched = "hasLaunched"
    }
}

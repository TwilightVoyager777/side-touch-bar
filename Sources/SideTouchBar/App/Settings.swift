import SwiftUI

/// What the bar shows, matching the Touch Bar's "Touch Bar shows" options.
enum BarPage: String, CaseIterable, Identifiable {
    case appControlsWithStrip, expandedStrip, appControls, functionKeys, quickActions, spaces

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appControlsWithStrip: tr("应用控件与控制条")
        case .expandedStrip: tr("展开的控制条")
        case .appControls: tr("应用控件")
        case .functionKeys: tr("F1、F2 等键")
        case .quickActions: tr("快速操作")
        case .spaces: tr("空间")
        }
    }

    /// Choices for "Press and hold fn key to", as on the Touch Bar.
    static let fnHoldChoices: [BarPage] = [.functionKeys, .expandedStrip, .appControls, .quickActions, .spaces]
}

enum DisplayTarget: String, CaseIterable, Identifiable {
    case main, builtIn, followMouse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .main: tr("主显示器")
        case .builtIn: tr("内建显示器")
        case .followMouse: tr("跟随鼠标")
        }
    }
}

enum SizePreference: String, CaseIterable, Identifiable {
    case small, standard, large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: tr("小")
        case .standard: tr("标准")
        case .large: tr("大")
        }
    }

    var multiplier: CGFloat {
        switch self {
        case .small: 0.88
        case .standard: 1
        case .large: 1.15
        }
    }
}

enum GlassStyle: String, CaseIterable, Identifiable {
    case regular, clear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .regular: tr("常规")
        case .clear: tr("清透")
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
        case .system: tr("跟随系统")
        case .light: tr("浅色")
        case .dark: tr("深色")
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

    @Published var barPage: BarPage {
        didSet { defaults.set(barPage.rawValue, forKey: Keys.barPage) }
    }

    /// Shown while the keyboard fn/Globe key is held.
    @Published var fnHoldPage: BarPage {
        didSet { defaults.set(fnHoldPage.rawValue, forKey: Keys.fnHoldPage) }
    }

    /// Bundle IDs of apps that always show F1–F12.
    @Published var functionKeyApps: [String] {
        didSet { defaults.set(functionKeyApps, forKey: Keys.functionKeyApps) }
    }

    @Published var displayTarget: DisplayTarget {
        didSet { defaults.set(displayTarget.rawValue, forKey: Keys.displayTarget) }
    }

    /// Applied on top of the automatic, physical-size based scale.
    @Published var sizePreference: SizePreference {
        didSet { defaults.set(sizePreference.rawValue, forKey: Keys.sizePreference) }
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

    // MARK: Touch

    /// Dangerous buttons need a hold.
    @Published var touchConfirm: Bool {
        didSet { defaults.set(touchConfirm, forKey: Keys.touchConfirm) }
    }

    /// Volume, zoom, skip… repeat while held.
    @Published var touchRepeat: Bool {
        didSet { defaults.set(touchRepeat, forKey: Keys.touchRepeat) }
    }

    /// Swipe in from the edge to reveal, swipe out on the bar to hide.
    @Published var touchEdgeSwipe: Bool {
        didSet { defaults.set(touchEdgeSwipe, forKey: Keys.touchEdgeSwipe) }
    }

    /// Show the text editing page while typing in a text field.
    @Published var touchAutoTextPage: Bool {
        didSet { defaults.set(touchAutoTextPage, forKey: Keys.touchAutoTextPage) }
    }

    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: L10n.languageKey) }
    }

    // MARK: AI coding

    @Published var aiEnabled: Bool {
        didSet { defaults.set(aiEnabled, forKey: Keys.aiEnabled) }
    }

    /// Slide the bar out when a coding agent needs a permission decision.
    @Published var aiAutoReveal: Bool {
        didSet { defaults.set(aiAutoReveal, forKey: Keys.aiAutoReveal) }
    }

    @Published var aiSoundOnDone: Bool {
        didSet { defaults.set(aiSoundOnDone, forKey: Keys.aiSoundOnDone) }
    }

    @Published var aiSnippets: [AISnippet] {
        didSet { saveJSON(aiSnippets, forKey: Keys.aiSnippets) }
    }

    @Published var aiSendTarget: AISendTarget {
        didSet { defaults.set(aiSendTarget.rawValue, forKey: Keys.aiSendTarget) }
    }

    @Published var voiceLanguage: VoiceLanguage {
        didSet { defaults.set(voiceLanguage.rawValue, forKey: Keys.voiceLanguage) }
    }

    // MARK: Custom buttons, browsers, media

    /// Keyed by bundle ID.
    @Published var customButtons: [String: CustomButtonSet] {
        didSet { saveJSON(customButtons, forKey: Keys.customButtons) }
    }

    @Published var favoriteSites: [FavoriteSite] {
        didSet { saveJSON(favoriteSites, forKey: Keys.favoriteSites) }
    }

    /// Seconds for the skip back/forward buttons of video playback controls.
    @Published var mediaSkipSeconds: Double {
        didSet { defaults.set(mediaSkipSeconds, forKey: Keys.mediaSkipSeconds) }
    }

    static let mediaSkipOptions: [Double] = [5, 10, 15, 30]

    var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Keys.hasLaunched) }
        set { defaults.set(newValue, forKey: Keys.hasLaunched) }
    }

    private init() {
        barPage = defaults.string(forKey: Keys.barPage).flatMap(BarPage.init) ?? .appControlsWithStrip
        fnHoldPage = defaults.string(forKey: Keys.fnHoldPage).flatMap(BarPage.init) ?? .functionKeys
        functionKeyApps = defaults.stringArray(forKey: Keys.functionKeyApps) ?? []
        displayTarget = defaults.string(forKey: Keys.displayTarget).flatMap(DisplayTarget.init) ?? .main
        sizePreference = defaults.string(forKey: Keys.sizePreference).flatMap(SizePreference.init) ?? .standard
        autoHide = defaults.object(forKey: Keys.autoHide) as? Bool ?? true
        idleDelay = defaults.object(forKey: Keys.idleDelay) as? Double ?? 8
        glassStyle = defaults.string(forKey: Keys.glassStyle).flatMap(GlassStyle.init) ?? .regular
        appearance = defaults.string(forKey: Keys.appearance).flatMap(AppearanceMode.init) ?? .system
        compactItems = (defaults.stringArray(forKey: Keys.compactItems)?.compactMap(ControlItem.init))
            ?? ControlItem.defaultCompact
        touchConfirm = defaults.object(forKey: Keys.touchConfirm) as? Bool ?? true
        touchRepeat = defaults.object(forKey: Keys.touchRepeat) as? Bool ?? true
        touchEdgeSwipe = defaults.object(forKey: Keys.touchEdgeSwipe) as? Bool ?? true
        touchAutoTextPage = defaults.object(forKey: Keys.touchAutoTextPage) as? Bool ?? true
        // Earlier versions were Chinese only: keep existing users in Chinese,
        // new installs follow the system language.
        if defaults.string(forKey: L10n.languageKey) == nil, defaults.bool(forKey: Keys.hasLaunched) {
            defaults.set(AppLanguage.chinese.rawValue, forKey: L10n.languageKey)
        }
        language = L10n.language
        aiEnabled = defaults.object(forKey: Keys.aiEnabled) as? Bool ?? true
        aiAutoReveal = defaults.object(forKey: Keys.aiAutoReveal) as? Bool ?? true
        aiSoundOnDone = defaults.object(forKey: Keys.aiSoundOnDone) as? Bool ?? false
        aiSnippets = Self.loadJSON([AISnippet].self, from: defaults, forKey: Keys.aiSnippets) ?? AISnippet.defaults
        aiSendTarget = defaults.string(forKey: Keys.aiSendTarget).flatMap(AISendTarget.init) ?? .automatic
        voiceLanguage = defaults.string(forKey: Keys.voiceLanguage).flatMap(VoiceLanguage.init) ?? .system
        customButtons = Self.loadJSON([String: CustomButtonSet].self, from: defaults, forKey: Keys.customButtons) ?? [:]
        favoriteSites = Self.loadJSON([FavoriteSite].self, from: defaults, forKey: Keys.favoriteSites) ?? []
        mediaSkipSeconds = defaults.object(forKey: Keys.mediaSkipSeconds) as? Double ?? 10
    }

    private func saveJSON<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    private static func loadJSON<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, forKey key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private enum Keys {
        static let barPage = "barPage"
        static let fnHoldPage = "fnHoldPage"
        static let functionKeyApps = "functionKeyApps"
        static let displayTarget = "displayTarget"
        static let sizePreference = "sizePreference"
        static let autoHide = "autoHide"
        static let idleDelay = "idleDelay"
        static let glassStyle = "glassStyle"
        static let appearance = "appearance"
        static let compactItems = "compactItems"
        static let hasLaunched = "hasLaunched"
        static let touchConfirm = "touchConfirm"
        static let touchRepeat = "touchRepeat"
        static let touchEdgeSwipe = "touchEdgeSwipe"
        static let touchAutoTextPage = "touchAutoTextPage"
        static let aiEnabled = "aiEnabled"
        static let aiAutoReveal = "aiAutoReveal"
        static let aiSoundOnDone = "aiSoundOnDone"
        static let aiSnippets = "aiSnippets"
        static let aiSendTarget = "aiSendTarget"
        static let voiceLanguage = "voiceLanguage"
        static let customButtons = "customButtons"
        static let favoriteSites = "favoriteSites"
        static let mediaSkipSeconds = "mediaSkipSeconds"
    }
}

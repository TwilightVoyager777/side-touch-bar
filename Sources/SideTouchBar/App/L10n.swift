import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, chinese, english

    var id: String { rawValue }

    /// Each option is shown in its own language.
    var title: String {
        switch self {
        case .system: L10n.isEnglish ? "System" : "跟随系统"
        case .chinese: "中文"
        case .english: "English"
        }
    }
}

/// Chinese is the source language: user-facing strings are written in
/// Chinese and looked up in `L10n.english` when the interface is English.
enum L10n {
    static let languageKey = "language"

    static var language: AppLanguage {
        UserDefaults.standard.string(forKey: languageKey).flatMap(AppLanguage.init) ?? .system
    }

    static var isEnglish: Bool {
        switch language {
        case .english: true
        case .chinese: false
        case .system: !(Locale.preferredLanguages.first ?? "en").hasPrefix("zh")
        }
    }
}

/// Translates a Chinese source string for the current interface language.
/// Unknown strings (such as user content) are returned unchanged.
func tr(_ text: String) -> String {
    guard L10n.isEnglish else { return text }
    return L10n.english[text] ?? text
}

/// Translates a format string with `%@` / `%d` placeholders, then fills them in.
func tr(_ format: String, _ arguments: CVarArg...) -> String {
    String(format: tr(format), arguments: arguments)
}

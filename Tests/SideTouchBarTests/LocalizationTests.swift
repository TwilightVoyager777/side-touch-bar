import Foundation
import Testing
@testable import SideTouchBar

/// The English table must keep format placeholders intact, or `String(format:)`
/// would read the wrong arguments.
struct LocalizationTests {
    private static let placeholder = try! NSRegularExpression(pattern: "%(?:\\.\\d+)?[@dfs%]")

    private func placeholders(_ text: String) -> [String] {
        Self.placeholder.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
            String(text[Range($0.range, in: text)!])
        }
    }

    @Test func translationsKeepPlaceholders() {
        for (chinese, english) in L10n.english {
            #expect(placeholders(chinese) == placeholders(english), "\(chinese) → \(english)")
        }
    }

    @Test func translationsAreNotEmpty() {
        for (chinese, english) in L10n.english {
            #expect(!english.trimmingCharacters(in: .whitespaces).isEmpty, "\(chinese)")
        }
    }

    @Test func englishInterfaceTranslatesAndFormats() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: L10n.languageKey)
        defer { defaults.set(previous, forKey: L10n.languageKey) }

        defaults.set(AppLanguage.english.rawValue, forKey: L10n.languageKey)
        #expect(tr("自动隐藏") == "Hide Automatically")
        #expect(tr("桌面 %d", 3) == "Desktop 3")
        #expect(tr("我的快捷输入") == "我的快捷输入")

        defaults.set(AppLanguage.chinese.rawValue, forKey: L10n.languageKey)
        #expect(tr("自动隐藏") == "自动隐藏")
        #expect(tr("桌面 %d", 3) == "桌面 3")
    }
}

import Foundation

/// Emoji for the Touch Bar–style emoji scrubber: recently used first, then a
/// set of common ones.
@MainActor
final class EmojiStore: ObservableObject {
    static let shared = EmojiStore()

    static let common: [String] = [
        "😀", "😂", "🥹", "😊", "😍", "🥰", "😘", "😎",
        "🤔", "😅", "😭", "😡", "😴", "🥳", "🤯", "😱",
        "👍", "👎", "👏", "🙏", "💪", "👌", "✌️", "🤝",
        "❤️", "🧡", "💛", "💚", "💙", "💜", "💔", "✨",
        "🔥", "🎉", "💯", "✅", "❌", "⭐️", "🌈", "☀️",
        "🐶", "🐱", "🐼", "🦊", "🍎", "🍕", "☕️", "🍺",
        "⚽️", "🎵", "📷", "💻", "📱", "🚀", "💡", "📌",
    ]

    private static let maxRecent = 12
    private let key = "recentEmoji"

    @Published private(set) var recent: [String]

    var all: [String] {
        recent + Self.common.filter { !recent.contains($0) }
    }

    private init() {
        recent = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func use(_ emoji: String) {
        ActionRunner.type(emoji)
        recent = Array(([emoji] + recent.filter { $0 != emoji }).prefix(Self.maxRecent))
        UserDefaults.standard.set(recent, forKey: key)
    }
}

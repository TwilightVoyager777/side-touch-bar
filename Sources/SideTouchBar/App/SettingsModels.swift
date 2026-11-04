import SwiftUI

/// Where "send to AI" delivers selected code, pages and screenshots.
enum AISendTarget: String, CaseIterable, Identifiable {
    case automatic, terminalAgent, claudeDesktop, opencodeDesktop, chatgpt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "最近使用的 AI"
        case .terminalAgent: "终端里的 AI 会话"
        case .claudeDesktop: "Claude"
        case .opencodeDesktop: "OpenCode"
        case .chatgpt: "ChatGPT"
        }
    }
}

enum VoiceLanguage: String, CaseIterable, Identifiable {
    case system, chinese, english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .chinese: "中文"
        case .english: "English"
        }
    }

    var locale: Locale {
        switch self {
        case .system: .current
        case .chinese: Locale(identifier: "zh-CN")
        case .english: Locale(identifier: "en-US")
        }
    }
}

/// A one-tap prompt or slash command for coding agents.
struct AISnippet: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var text: String
    var submit: Bool

    static let defaults: [AISnippet] = [
        AISnippet(title: "继续", text: "继续", submit: true),
        AISnippet(title: "解释改动", text: "解释一下刚才的改动", submit: true),
        AISnippet(title: "写测试", text: "为刚才的改动补充测试", submit: true),
        AISnippet(title: "检查改动", text: "检查一下这次的改动有没有问题", submit: true),
        AISnippet(title: "中文回答", text: "请用中文回答", submit: true),
        AISnippet(title: "/compact", text: "/compact", submit: true),
        AISnippet(title: "/clear", text: "/clear", submit: true),
        AISnippet(title: "/context", text: "/context", submit: true),
        AISnippet(title: "/model", text: "/model", submit: true),
        AISnippet(title: "/resume", text: "/resume", submit: true),
    ]
}

/// A button the user added for an app, from its menus or a recorded shortcut.
struct CustomButton: Codable, Identifiable, Hashable {
    enum Kind: Codable, Hashable {
        case menu([String])
        case keys(KeyCombo)
        case text(String, submit: Bool)
    }

    var id = UUID()
    var title: String
    /// SF Symbol name; empty shows the first characters of the title.
    var symbol: String
    var kind: Kind

    var barItem: BarItem {
        let icon: BarIcon = symbol.isEmpty ? .text(String(title.prefix(2))) : .symbol(symbol)
        let action: BarAction = switch kind {
        case .menu(let path): .menu(MenuCommand(paths: [path]))
        case .keys(let combo): .keys(combo)
        case .text(let text, let submit): .text(text, submit: submit)
        }
        return BarItem(title: title, icon: icon, action: action)
    }
}

struct CustomButtonSet: Codable, Hashable {
    /// Show only these buttons instead of adding them as an extra page.
    var replacesBuiltIn = false
    var buttons: [CustomButton] = []
}

struct FavoriteSite: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var url: String
}

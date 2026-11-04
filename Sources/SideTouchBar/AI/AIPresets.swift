import Carbon.HIToolbox
import CoreGraphics

/// How to answer a permission prompt in each agent's terminal UI.
enum AgentAnswer {
    case yes, always, no
}

enum AIPresets {
    // MARK: - Terminal agents

    static func keys(for answer: AgentAnswer, agent: AgentKind) -> KeyCombo? {
        switch (agent, answer) {
        // Claude Code numbers its options; the first is always "Yes", and Esc declines.
        case (.claude, .yes): KeyCombo(kVK_ANSI_1)
        case (.claude, .always): KeyCombo(kVK_ANSI_2)
        case (.codex, .yes): KeyCombo(kVK_ANSI_Y)
        case (.codex, .always): KeyCombo(kVK_ANSI_A)
        case (.opencode, .yes), (.gemini, .yes): KeyCombo(kVK_Return)
        case (_, .no): KeyCombo(kVK_Escape)
        default: nil
        }
    }

    static func answerItems(for agent: AgentKind) -> [BarItem] {
        var items = [BarItem.key("是", "checkmark", keys(for: .yes, agent: agent)!)]
        if let always = keys(for: .always, agent: agent) {
            items.append(BarItem.key("总是允许（这一项不存在时等于否）", "checkmark.seal", always).confirming())
        }
        items.append(.key("否 / 中断", "xmark", keys(for: .no, agent: agent)!))
        return items
    }

    static func controlItems(for agent: AgentKind) -> [BarItem] {
        switch agent {
        case .claude:
            [
                .key("切换权限模式（⇧⇥）", "arrow.triangle.2.circlepath", KeyCombo(kVK_Tab, .maskShift)),
            ]
        case .opencode:
            [
                .key("切换智能体（⇧⇥）", "arrow.triangle.2.circlepath", KeyCombo(kVK_Tab, .maskShift)),
            ]
        case .codex, .gemini:
            [
                .key("中断（⌃C）", "stop.circle", KeyCombo(kVK_ANSI_C, .maskControl)),
            ]
        }
    }

    static func terminalAgent(_ agent: AgentKind) -> AppPreset {
        let morePage: [[BarItem]] = switch agent {
        case .claude:
            [
                [
                    .sequence("回退（双击 esc）", "arrow.uturn.backward.circle", [KeyCombo(kVK_Escape), KeyCombo(kVK_Escape)]),
                    .key("切换模型（⌥P）", "cpu", KeyCombo(kVK_ANSI_P, .maskAlternate)),
                    .key("转到后台（⌃B）", "arrow.down.right.and.arrow.up.left", KeyCombo(kVK_ANSI_B, .maskControl)),
                    .key("任务清单（⌃T）", "list.bullet.rectangle", KeyCombo(kVK_ANSI_T, .maskControl)),
                    .key("详细记录（⌃O）", "doc.text", KeyCombo(kVK_ANSI_O, .maskControl)),
                ],
                [
                    .key("在编辑器里写提示词（⌃G）", "square.and.pencil", KeyCombo(kVK_ANSI_G, .maskControl)),
                    .key("中断（⌃C）", "stop.circle", KeyCombo(kVK_ANSI_C, .maskControl)),
                ],
            ]
        case .opencode:
            [[.key("转到后台（⌃B）", "arrow.down.right.and.arrow.up.left", KeyCombo(kVK_ANSI_B, .maskControl))]]
                + AppPresets.terminal.pages[0].groups
        default:
            AppPresets.terminal.pages[0].groups
        }
        return AppPreset(id: "agent-\(agent.rawValue)", bundleIDs: [], pages: [
            PresetPage(
                id: "agent",
                title: agent.title,
                symbol: "sparkles",
                groups: [answerItems(for: agent), controlItems(for: agent)],
                extras: [.agentStatus, .voiceAndScreenshot, .quickInputs]
            ),
            PresetPage(id: "more", title: "更多", symbol: "ellipsis", groups: morePage),
        ])
    }

    // MARK: - Desktop apps

    private static let cmd: CGEventFlags = .maskCommand
    private static let cmdShift: CGEventFlags = [.maskCommand, .maskShift]

    static let claudeDesktop = AppPreset(id: "claudeDesktop", bundleIDs: [AIDesktopApp.claude.bundleID], pages: [
        PresetPage(
            id: "chat",
            title: "对话",
            symbol: "text.bubble",
            groups: [[
                .menu("新会话", "square.and.pencil", ["File", "New Session"], fallback: KeyCombo(kVK_ANSI_N, cmd)),
                .menu("搜索", "magnifyingglass", ["Go", "Search"], fallback: KeyCombo(kVK_ANSI_K, cmdShift)),
                .menu("上一个会话", "chevron.up", ["Go", "Previous Session"], fallback: KeyCombo(kVK_ANSI_LeftBracket, cmdShift)),
                .menu("下一个会话", "chevron.down", ["Go", "Next Session"], fallback: KeyCombo(kVK_ANSI_RightBracket, cmdShift)),
            ]],
            extras: [.voiceAndScreenshot, .quickInputs]
        ),
        PresetPage(id: "view", title: "视图", symbol: "sidebar.left", groups: [
            [
                .menu("命令面板", "command", ["View", "Command Palette"], fallback: KeyCombo(kVK_ANSI_K, cmd)),
                .menu("侧边栏", "sidebar.left", ["View", "Hide Sidebar|Show Sidebar"], fallback: KeyCombo(kVK_ANSI_B, cmd)),
            ],
            [
                .menu("终端", "terminal", ["View", "Show Terminal|Hide Terminal"], fallback: KeyCombo(kVK_ANSI_J, cmd)),
                .menu("改动", "plus.forwardslash.minus", ["View", "Show Changes|Hide Changes"], fallback: KeyCombo(kVK_ANSI_D, cmdShift)),
                .menu("文件", "doc.text", ["View", "Show Files|Hide Files"], fallback: KeyCombo(kVK_ANSI_F, cmdShift)),
            ],
            [
                .menu("新建侧边对话", "rectangle.split.2x1", ["File", "New Side Chat"]),
            ],
        ]),
    ])

    static let opencodeDesktop = AppPreset(id: "opencodeDesktop", bundleIDs: [AIDesktopApp.opencode.bundleID], pages: [
        PresetPage(
            id: "chat",
            title: "对话",
            symbol: "text.bubble",
            groups: [[
                .menu("新会话", "square.and.pencil", ["File", "New Session"], fallback: KeyCombo(kVK_ANSI_N, cmd)),
                .menu("上一个会话", "chevron.up", ["Go", "Previous Session"]),
                .menu("下一个会话", "chevron.down", ["Go", "Next Session"]),
                .key("中断（esc）", "stop.circle", KeyCombo(kVK_Escape)),
            ]],
            extras: [.voiceAndScreenshot, .quickInputs]
        ),
        PresetPage(id: "view", title: "视图", symbol: "sidebar.left", groups: [[
            .menu("侧边栏", "sidebar.left", ["View", "Toggle Sidebar"], fallback: KeyCombo(kVK_ANSI_B, cmdShift)),
            .menu("终端", "terminal", ["View", "Toggle Terminal"], fallback: KeyCombo(kVK_ANSI_Grave, .maskControl)),
            .menu("新窗口", "macwindow.badge.plus", ["File", "New Window"], fallback: KeyCombo(kVK_ANSI_N, cmdShift)),
        ]]),
    ])

    /// Not verified: ChatGPT isn't installed on the development machine, so
    /// buttons search the menus by keyword and fall back to common shortcuts.
    static let chatGPT = AppPreset(id: "chatgpt", bundleIDs: [AIDesktopApp.chatgpt.bundleID], pages: [
        PresetPage(
            id: "chat",
            title: "对话",
            symbol: "text.bubble",
            groups: [[
                BarItem(title: "新对话", icon: .symbol("square.and.pencil"), action: .menuSearch(["New Chat", "新聊天", "新对话"], fallback: KeyCombo(kVK_ANSI_N, cmd))),
                BarItem(title: "搜索", icon: .symbol("magnifyingglass"), action: .menuSearch(["Search", "搜索"], fallback: KeyCombo(kVK_ANSI_K, cmd))),
                BarItem(title: "侧边栏", icon: .symbol("sidebar.left"), action: .menuSearch(["Sidebar", "边栏"], fallback: nil)),
            ]],
            extras: [.voiceAndScreenshot, .quickInputs]
        ),
    ])

    static let desktopApps: [AppPreset] = [claudeDesktop, opencodeDesktop, chatGPT]
}

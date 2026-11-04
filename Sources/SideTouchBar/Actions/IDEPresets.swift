import Carbon.HIToolbox
import CoreGraphics

private let cmd: CGEventFlags = .maskCommand
private let shift: CGEventFlags = .maskShift
private let ctrl: CGEventFlags = .maskControl
private let opt: CGEventFlags = .maskAlternate
private let cmdShift: CGEventFlags = [.maskCommand, .maskShift]
private let cmdOpt: CGEventFlags = [.maskCommand, .maskAlternate]
private let cmdCtrl: CGEventFlags = [.maskCommand, .maskControl]
private let ctrlShift: CGEventFlags = [.maskControl, .maskShift]
private let optShift: CGEventFlags = [.maskAlternate, .maskShift]

private let sendToAI = BarItem.ai("把选中代码发给 AI", "paperplane.fill", .sendSelection)

/// Programming tools, with pages for running, navigating, editing, Git and a
/// debugger page that comes forward while debugging (when the app's menus
/// report it). Shortcuts are the defaults of each tool's macOS keymap.
///
/// Not verified on a real install: none of these IDEs are on the development
/// machine. Debugger probes rely on menu enablement, which some apps only
/// refresh when a menu opens; the page switcher works either way.
enum IDEPresets {
    // MARK: - VS Code family

    private static func vscodeFamily(id: String, bundleIDs: Set<String>, aiItems: [BarItem]) -> AppPreset {
        AppPreset(id: id, bundleIDs: bundleIDs, pages: [
            PresetPage(id: "run", title: "运行", symbol: "play.fill", groups: [
                [
                    .key("运行（不调试）⌃F5", "play.fill", KeyCombo(kVK_F5, ctrl)),
                    .key("开始调试 F5", "ant.fill", KeyCombo(kVK_F5)),
                    .key("停止 ⇧F5", "stop.fill", KeyCombo(kVK_F5, shift)),
                    .key("重启 ⇧⌘F5", "arrow.clockwise", KeyCombo(kVK_F5, cmdShift)),
                ],
                [
                    .key("切换断点 F9", "smallcircle.filled.circle", KeyCombo(kVK_F9)),
                    .key("终端 ⌃`", "terminal", KeyCombo(kVK_ANSI_Grave, ctrl)),
                    sendToAI,
                ],
            ]),
            PresetPage(id: "navigate", title: "导航", symbol: "arrow.triangle.branch", groups: [
                [
                    .key("快速打开 ⌘P", "doc.text.magnifyingglass", KeyCombo(kVK_ANSI_P, cmd)),
                    .key("命令面板 ⇧⌘P", "command", KeyCombo(kVK_ANSI_P, cmdShift)),
                    .key("转到符号 ⇧⌘O", "text.magnifyingglass", KeyCombo(kVK_ANSI_O, cmdShift)),
                ],
                [
                    .key("转到定义 F12", "arrow.right.to.line", KeyCombo(kVK_F12)),
                    .key("查找引用 ⇧F12", "point.3.connected.trianglepath.dotted", KeyCombo(kVK_F12, shift)),
                    .key("返回 ⌃-", "chevron.left", KeyCombo(kVK_ANSI_Minus, ctrl)),
                    .key("前进 ⌃⇧-", "chevron.right", KeyCombo(kVK_ANSI_Minus, ctrlShift)),
                ],
                [
                    .key("下一个问题 F8", "exclamationmark.bubble", KeyCombo(kVK_F8)),
                ],
            ]),
            PresetPage(id: "edit", title: "编辑", symbol: "textformat.alt", groups: [
                [
                    .key("注释 ⌘/", "chevron.left.forwardslash.chevron.right", KeyCombo(kVK_ANSI_Slash, cmd)),
                    .key("格式化 ⌥⇧F", "wand.and.rays", KeyCombo(kVK_ANSI_F, optShift)),
                    .key("重命名 F2", "character.cursor.ibeam", KeyCombo(kVK_F2)),
                    .key("快速修复 ⌘.", "lightbulb", KeyCombo(kVK_ANSI_Period, cmd)),
                ],
                [
                    .key("侧边栏 ⌘B", "sidebar.left", KeyCombo(kVK_ANSI_B, cmd)),
                    .key("问题面板 ⇧⌘M", "exclamationmark.triangle", KeyCombo(kVK_ANSI_M, cmdShift)),
                    .key("源代码管理 ⌃⇧G", "arrow.triangle.branch", KeyCombo(kVK_ANSI_G, ctrlShift)),
                ],
            ]),
            PresetPage(id: "ai", title: "AI", symbol: "sparkles", groups: [aiItems + [sendToAI]], extras: [.voiceAndScreenshot]),
            PresetPage(
                id: "debug",
                title: "调试",
                symbol: "ant.fill",
                groups: [
                    [
                        .key("继续 F5", "play.fill", KeyCombo(kVK_F5)),
                        .key("单步跳过 F10", "arrow.turn.down.right", KeyCombo(kVK_F10)),
                        .key("单步进入 F11", "arrow.down.to.line", KeyCombo(kVK_F11)),
                        .key("单步跳出 ⇧F11", "arrow.up.to.line", KeyCombo(kVK_F11, shift)),
                    ],
                    [
                        .key("重启 ⇧⌘F5", "arrow.clockwise", KeyCombo(kVK_F5, cmdShift)),
                        .key("停止 ⇧F5", "stop.fill", KeyCombo(kVK_F5, shift)),
                        .key("切换断点 F9", "smallcircle.filled.circle", KeyCombo(kVK_F9)),
                    ],
                ],
                probe: MenuProbe(path: ["Run|运行", "Stop Debugging|停止调试"])
            ),
        ])
    }

    static let vscode = vscodeFamily(
        id: "vscode",
        bundleIDs: ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.vscodium", "com.exafunction.windsurf", "dev.zed.Zed"],
        aiItems: [
            .key("聊天 ⌃⌘I", "text.bubble", KeyCombo(kVK_ANSI_I, cmdCtrl)),
            .key("行内聊天 ⌘I", "sparkles", KeyCombo(kVK_ANSI_I, cmd)),
        ]
    )

    static let cursor = vscodeFamily(
        id: "cursor",
        bundleIDs: ["com.todesktop.230313mzl4w4u92"],
        aiItems: [
            .key("聊天 ⌘L", "text.bubble", KeyCombo(kVK_ANSI_L, cmd)),
            .key("行内编辑 ⌘K", "sparkles", KeyCombo(kVK_ANSI_K, cmd)),
        ]
    )

    // MARK: - JetBrains (macOS keymap)

    static let jetbrains = AppPreset(
        id: "jetbrains",
        bundleIDs: [
            "com.jetbrains.intellij", "com.jetbrains.intellij.ce", "com.jetbrains.WebStorm",
            "com.jetbrains.pycharm", "com.jetbrains.pycharm.ce", "com.jetbrains.goland", "com.jetbrains.CLion",
            "com.jetbrains.rider", "com.jetbrains.rubymine", "com.jetbrains.PhpStorm", "com.jetbrains.datagrip",
            "com.jetbrains.rustrover", "com.google.android.studio",
        ],
        pages: [
            PresetPage(id: "run", title: "运行", symbol: "play.fill", groups: [
                [
                    .key("运行 ⌃R", "play.fill", KeyCombo(kVK_ANSI_R, ctrl)),
                    .key("调试 ⌃D", "ant.fill", KeyCombo(kVK_ANSI_D, ctrl)),
                    .key("停止 ⌘F2", "stop.fill", KeyCombo(kVK_F2, cmd)),
                    .key("构建 ⌘F9", "hammer", KeyCombo(kVK_F9, cmd)),
                ],
                [
                    .key("切换断点 ⌘F8", "smallcircle.filled.circle", KeyCombo(kVK_F8, cmd)),
                    .key("终端 ⌥F12", "terminal", KeyCombo(kVK_F12, opt)),
                    sendToAI,
                ],
            ]),
            PresetPage(id: "navigate", title: "导航", symbol: "arrow.triangle.branch", groups: [
                [
                    .key("转到文件 ⇧⌘O", "doc.text.magnifyingglass", KeyCombo(kVK_ANSI_O, cmdShift)),
                    .key("查找操作 ⇧⌘A", "command", KeyCombo(kVK_ANSI_A, cmdShift)),
                    .key("最近文件 ⌘E", "clock.arrow.circlepath", KeyCombo(kVK_ANSI_E, cmd)),
                ],
                [
                    .key("转到声明 ⌘B", "arrow.right.to.line", KeyCombo(kVK_ANSI_B, cmd)),
                    .key("查找用法 ⌥F7", "point.3.connected.trianglepath.dotted", KeyCombo(kVK_F7, opt)),
                    .key("返回 ⌘[", "chevron.left", KeyCombo(kVK_ANSI_LeftBracket, cmd)),
                    .key("前进 ⌘]", "chevron.right", KeyCombo(kVK_ANSI_RightBracket, cmd)),
                ],
                [
                    .key("下一个错误 F2", "exclamationmark.bubble", KeyCombo(kVK_F2)),
                ],
            ]),
            PresetPage(id: "edit", title: "编辑", symbol: "textformat.alt", groups: [
                [
                    .key("注释 ⌘/", "chevron.left.forwardslash.chevron.right", KeyCombo(kVK_ANSI_Slash, cmd)),
                    .key("格式化 ⌥⌘L", "wand.and.rays", KeyCombo(kVK_ANSI_L, cmdOpt)),
                    .key("重命名 ⇧F6", "character.cursor.ibeam", KeyCombo(kVK_F6, shift)),
                    .key("意图操作 ⌥↩", "lightbulb", KeyCombo(kVK_Return, opt)),
                ],
                [
                    .key("项目 ⌘1", "sidebar.left", KeyCombo(kVK_ANSI_1, cmd)),
                    .key("问题 ⌘6", "exclamationmark.triangle", KeyCombo(kVK_ANSI_6, cmd)),
                    .key("文件结构 ⌘F12", "list.bullet.rectangle", KeyCombo(kVK_F12, cmd)),
                ],
            ]),
            PresetPage(id: "git", title: "Git", symbol: "arrow.triangle.branch", groups: [
                [
                    .key("提交 ⌘K", "checkmark.circle", KeyCombo(kVK_ANSI_K, cmd)),
                    .key("推送 ⇧⌘K", "arrow.up.circle", KeyCombo(kVK_ANSI_K, cmdShift)),
                    .key("更新项目 ⌘T", "arrow.down.circle", KeyCombo(kVK_ANSI_T, cmd)),
                ],
                [
                    .key("查看改动 ⌘D", "plus.forwardslash.minus", KeyCombo(kVK_ANSI_D, cmd)),
                    .key("回滚 ⌥⌘Z", "arrow.uturn.backward", KeyCombo(kVK_ANSI_Z, cmdOpt)),
                    .key("Git 窗口 ⌘9", "arrow.triangle.branch", KeyCombo(kVK_ANSI_9, cmd)),
                ],
            ]),
            PresetPage(
                id: "debug",
                title: "调试",
                symbol: "ant.fill",
                groups: [
                    [
                        .key("继续 ⌥⌘R", "play.fill", KeyCombo(kVK_ANSI_R, cmdOpt)),
                        .key("步过 F8", "arrow.turn.down.right", KeyCombo(kVK_F8)),
                        .key("步入 F7", "arrow.down.to.line", KeyCombo(kVK_F7)),
                        .key("步出 ⇧F8", "arrow.up.to.line", KeyCombo(kVK_F8, shift)),
                    ],
                    [
                        .key("求值 ⌥F8", "function", KeyCombo(kVK_F8, opt)),
                        .key("停止 ⌘F2", "stop.fill", KeyCombo(kVK_F2, cmd)),
                        .key("切换断点 ⌘F8", "smallcircle.filled.circle", KeyCombo(kVK_F8, cmd)),
                    ],
                ],
                probe: MenuProbe(path: ["Run|运行", "Debugging Actions|调试操作", "Step Over|步过"])
            ),
        ]
    )

    // MARK: - Xcode

    static let xcode = AppPreset(id: "xcode", bundleIDs: ["com.apple.dt.Xcode"], pages: [
        PresetPage(id: "run", title: "运行", symbol: "play.fill", groups: [
            [
                .key("运行 ⌘R", "play.fill", KeyCombo(kVK_ANSI_R, cmd)),
                .key("停止 ⌘.", "stop.fill", KeyCombo(kVK_ANSI_Period, cmd)),
                .key("构建 ⌘B", "hammer", KeyCombo(kVK_ANSI_B, cmd)),
                .key("测试 ⌘U", "checkmark.diamond", KeyCombo(kVK_ANSI_U, cmd)),
            ],
            [
                .key("清理 ⇧⌘K", "trash", KeyCombo(kVK_ANSI_K, cmdShift)),
                .key("切换断点 ⌘\\", "smallcircle.filled.circle", KeyCombo(kVK_ANSI_Backslash, cmd)),
                sendToAI,
            ],
        ]),
        PresetPage(id: "navigate", title: "导航", symbol: "arrow.triangle.branch", groups: [
            [
                .key("快速打开 ⇧⌘O", "doc.text.magnifyingglass", KeyCombo(kVK_ANSI_O, cmdShift)),
                .key("跳到定义 ⌃⌘J", "arrow.right.to.line", KeyCombo(kVK_ANSI_J, cmdCtrl)),
                .key("返回 ⌃⌘←", "chevron.left", KeyCombo(kVK_LeftArrow, cmdCtrl)),
                .key("前进 ⌃⌘→", "chevron.right", KeyCombo(kVK_RightArrow, cmdCtrl)),
            ],
            [
                .key("全局查找 ⇧⌘F", "magnifyingglass", KeyCombo(kVK_ANSI_F, cmdShift)),
                .key("下一个问题 ⌘'", "exclamationmark.bubble", KeyCombo(kVK_ANSI_Quote, cmd)),
                .key("导航栏 ⌘0", "sidebar.left", KeyCombo(kVK_ANSI_0, cmd)),
            ],
        ]),
        PresetPage(id: "edit", title: "编辑", symbol: "textformat.alt", groups: [
            [
                .key("注释 ⌘/", "chevron.left.forwardslash.chevron.right", KeyCombo(kVK_ANSI_Slash, cmd)),
                .key("重新缩进 ⌃I", "increase.indent", KeyCombo(kVK_ANSI_I, ctrl)),
                .key("同时编辑同名 ⌃⌘E", "character.cursor.ibeam", KeyCombo(kVK_ANSI_E, cmdCtrl)),
            ],
            [
                .key("调试区 ⇧⌘Y", "rectangle.split.2x1", KeyCombo(kVK_ANSI_Y, cmdShift)),
                .key("检查器 ⌥⌘0", "sidebar.right", KeyCombo(kVK_ANSI_0, cmdOpt)),
                .key("提交 ⌥⌘C", "checkmark.circle", KeyCombo(kVK_ANSI_C, cmdOpt)),
            ],
        ]),
        PresetPage(
            id: "debug",
            title: "调试",
            symbol: "ant.fill",
            groups: [
                [
                    .key("继续 ⌃⌘Y", "play.fill", KeyCombo(kVK_ANSI_Y, cmdCtrl)),
                    .key("单步跳过 F6", "arrow.turn.down.right", KeyCombo(kVK_F6)),
                    .key("单步进入 F7", "arrow.down.to.line", KeyCombo(kVK_F7)),
                    .key("单步跳出 F8", "arrow.up.to.line", KeyCombo(kVK_F8)),
                ],
                [
                    .key("停止 ⌘.", "stop.fill", KeyCombo(kVK_ANSI_Period, cmd)),
                    .key("切换断点 ⌘\\", "smallcircle.filled.circle", KeyCombo(kVK_ANSI_Backslash, cmd)),
                ],
            ],
            probe: MenuProbe(path: ["Debug", "Step Over"])
        ),
    ])

    static let all: [AppPreset] = [vscode, cursor, jetbrains, xcode]
}

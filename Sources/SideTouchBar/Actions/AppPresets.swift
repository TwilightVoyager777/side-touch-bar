import Carbon.HIToolbox
import CoreGraphics

private let cmd: CGEventFlags = .maskCommand
private let cmdShift: CGEventFlags = [.maskCommand, .maskShift]
private let cmdOpt: CGEventFlags = [.maskCommand, .maskAlternate]
private let cmdCtrl: CGEventFlags = [.maskCommand, .maskControl]
private let ctrl: CGEventFlags = .maskControl

private let emoji = BarItem(title: "表情", icon: .symbol("face.smiling"), action: .emojiPicker)

/// Buttons for the system control strip and for each supported app.
/// Add an `AppPreset` to `all` to support another app.
enum AppPresets {
    static func preset(for bundleID: String?) -> AppPreset {
        guard let bundleID else { return fallback }
        return all.first { $0.bundleIDs.contains(bundleID) } ?? fallback
    }

    // MARK: - Control strip

    /// The Touch Bar's default expanded Control Strip, top to bottom.
    static let controlStripFull: [[BarItem]] = [
        [
            .system("亮度 +", "sun.max.fill", .brightnessUp),
            .system("亮度 -", "sun.min.fill", .brightnessDown),
        ],
        [
            .system("调度中心", "rectangle.3.group", .missionControl),
            .system("启动台", "square.grid.3x3.fill", .apps),
        ],
        [
            .system("键盘背光 +", "light.max", .keyboardBrightnessUp),
            .system("键盘背光 -", "light.min", .keyboardBrightnessDown),
        ],
        [
            .system("上一首", "backward.fill", .previous),
            .system("播放/暂停", "playpause.fill", .playPause),
            .system("下一首", "forward.fill", .next),
        ],
        [
            .system("音量 +", "speaker.wave.3.fill", .volumeUp),
            .system("音量 -", "speaker.wave.1.fill", .volumeDown),
            .system("静音", "speaker.slash.fill", .mute),
        ],
        [
            .system("Siri", "siri", .siri),
        ],
    ]

    // MARK: - Function keys

    static let functionKeys: [[BarItem]] = {
        let codes = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
                     kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12]
        let items = codes.enumerated().map { index, code in
            BarItem.text("F\(index + 1)", "F\(index + 1)", KeyCombo(code))
        }
        return [Array(items[0..<4]), Array(items[4..<8]), Array(items[8..<12])]
    }()

    // MARK: - Apps

    static let fallback = AppPreset(
        id: "fallback",
        bundleIDs: [],
        groups: [
            [
                .key("新建", "plus.square", KeyCombo(kVK_ANSI_N, cmd)),
                .key("查找", "magnifyingglass", KeyCombo(kVK_ANSI_F, cmd)),
            ],
            [
                .key("撤销", "arrow.uturn.backward", KeyCombo(kVK_ANSI_Z, cmd)),
                .key("重做", "arrow.uturn.forward", KeyCombo(kVK_ANSI_Z, cmdShift)),
            ],
            [
                .key("拷贝", "doc.on.doc", KeyCombo(kVK_ANSI_C, cmd)),
                .key("粘贴", "doc.on.clipboard", KeyCombo(kVK_ANSI_V, cmd)),
                emoji,
            ],
        ]
    )

    static let browser = AppPreset(
        id: "browser",
        bundleIDs: [
            "com.apple.Safari",
            "com.google.Chrome",
            "company.thebrowser.Browser",
            "com.microsoft.edgemac",
            "org.mozilla.firefox",
            "com.brave.Browser",
        ],
        groups: [
            [
                .key("后退", "chevron.left", KeyCombo(kVK_ANSI_LeftBracket, cmd)),
                .key("前进", "chevron.right", KeyCombo(kVK_ANSI_RightBracket, cmd)),
                .key("刷新", "arrow.clockwise", KeyCombo(kVK_ANSI_R, cmd)),
            ],
            [
                .key("地址栏", "magnifyingglass", KeyCombo(kVK_ANSI_L, cmd)),
                .key("新标签页", "plus", KeyCombo(kVK_ANSI_T, cmd)),
                .key("关闭标签页", "xmark", KeyCombo(kVK_ANSI_W, cmd)),
            ],
            [
                .key("上一个标签页", "arrow.up.square", KeyCombo(kVK_ANSI_LeftBracket, cmdShift)),
                .key("下一个标签页", "arrow.down.square", KeyCombo(kVK_ANSI_RightBracket, cmdShift)),
                .key("显示所有标签页", "square.grid.2x2", KeyCombo(kVK_ANSI_Backslash, cmdShift)),
            ],
        ]
    )

    static let finder = AppPreset(
        id: "finder",
        bundleIDs: ["com.apple.finder"],
        groups: [
            [
                .key("后退", "chevron.left", KeyCombo(kVK_ANSI_LeftBracket, cmd)),
                .key("前进", "chevron.right", KeyCombo(kVK_ANSI_RightBracket, cmd)),
                .key("上层文件夹", "arrow.up", KeyCombo(kVK_UpArrow, cmd)),
            ],
            [
                .key("新建窗口", "macwindow.badge.plus", KeyCombo(kVK_ANSI_N, cmd)),
                .key("新建文件夹", "folder.badge.plus", KeyCombo(kVK_ANSI_N, cmdShift)),
            ],
            [
                .key("快速查看", "eye", KeyCombo(kVK_Space)),
                .key("显示简介", "info.circle", KeyCombo(kVK_ANSI_I, cmd)),
                .key("移到废纸篓", "trash", KeyCombo(kVK_Delete, cmd)),
            ],
        ]
    )

    static let terminal = AppPreset(
        id: "terminal",
        bundleIDs: [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "com.mitchellh.ghostty",
            "dev.warp.Warp-Stable",
        ],
        groups: [
            [
                .key("新标签页", "plus.square.on.square", KeyCombo(kVK_ANSI_T, cmd)),
                .key("关闭标签页", "xmark.square", KeyCombo(kVK_ANSI_W, cmd)),
            ],
            [
                .key("上一个标签页", "arrow.up.square", KeyCombo(kVK_ANSI_LeftBracket, cmdShift)),
                .key("下一个标签页", "arrow.down.square", KeyCombo(kVK_ANSI_RightBracket, cmdShift)),
            ],
            [
                .key("上一条命令", "arrow.up", KeyCombo(kVK_UpArrow)),
                .key("中断 (⌃C)", "stop.circle", KeyCombo(kVK_ANSI_C, ctrl)),
                .key("清屏", "clear", KeyCombo(kVK_ANSI_K, cmd)),
            ],
        ]
    )

    static let codeEditor = AppPreset(
        id: "codeEditor",
        bundleIDs: [
            "com.microsoft.VSCode",
            "com.todesktop.230313mzl4w4u92",
            "dev.zed.Zed",
            "com.exafunction.windsurf",
        ],
        groups: [
            [
                .key("命令面板", "command", KeyCombo(kVK_ANSI_P, cmdShift)),
                .key("快速打开", "doc.text.magnifyingglass", KeyCombo(kVK_ANSI_P, cmd)),
            ],
            [
                .key("侧边栏", "sidebar.left", KeyCombo(kVK_ANSI_B, cmd)),
                .key("终端", "terminal", KeyCombo(kVK_ANSI_Grave, ctrl)),
            ],
            [
                .key("查找", "magnifyingglass", KeyCombo(kVK_ANSI_F, cmd)),
                .key("注释", "chevron.left.forwardslash.chevron.right", KeyCombo(kVK_ANSI_Slash, cmd)),
                .key("保存", "square.and.arrow.down", KeyCombo(kVK_ANSI_S, cmd)),
            ],
        ]
    )

    static let xcode = AppPreset(
        id: "xcode",
        bundleIDs: ["com.apple.dt.Xcode"],
        groups: [
            [
                .key("运行", "play.fill", KeyCombo(kVK_ANSI_R, cmd)),
                .key("停止", "stop.fill", KeyCombo(kVK_ANSI_Period, cmd)),
                .key("构建", "hammer.fill", KeyCombo(kVK_ANSI_B, cmd)),
            ],
            [
                .key("快速打开", "doc.text.magnifyingglass", KeyCombo(kVK_ANSI_O, cmdShift)),
                .key("导航栏", "sidebar.left", KeyCombo(kVK_ANSI_0, cmd)),
            ],
            [
                .key("全局查找", "magnifyingglass", KeyCombo(kVK_ANSI_F, cmdShift)),
                .key("注释", "chevron.left.forwardslash.chevron.right", KeyCombo(kVK_ANSI_Slash, cmd)),
            ],
        ]
    )

    static let media = AppPreset(
        id: "media",
        bundleIDs: [
            "com.apple.Music",
            "com.spotify.client",
            "com.apple.podcasts",
            "com.apple.TV",
            "com.apple.QuickTimePlayerX",
            "com.netease.163music",
            "com.tencent.QQMusicMac",
        ],
        groups: [
            [
                .system("上一首", "backward.fill", .previous),
                .system("播放/暂停", "playpause.fill", .playPause),
                .system("下一首", "forward.fill", .next),
            ],
            [
                .system("音量 +", "speaker.wave.3.fill", .volumeUp),
                .system("音量 -", "speaker.wave.1.fill", .volumeDown),
            ],
        ]
    )

    static let mail = AppPreset(
        id: "mail",
        bundleIDs: ["com.apple.mail"],
        groups: [
            [
                .key("新邮件", "square.and.pencil", KeyCombo(kVK_ANSI_N, cmd)),
            ],
            [
                .key("回复", "arrowshape.turn.up.left.fill", KeyCombo(kVK_ANSI_R, cmd)),
                .key("全部回复", "arrowshape.turn.up.left.2.fill", KeyCombo(kVK_ANSI_R, cmdShift)),
                .key("转发", "arrowshape.turn.up.right.fill", KeyCombo(kVK_ANSI_F, cmdShift)),
            ],
            [
                .key("归档", "archivebox.fill", KeyCombo(kVK_ANSI_A, cmdCtrl)),
                .key("删除", "trash", KeyCombo(kVK_Delete, cmd)),
                .key("旗标", "flag.fill", KeyCombo(kVK_ANSI_L, cmdShift)),
            ],
        ]
    )

    static let calendar = AppPreset(
        id: "calendar",
        bundleIDs: ["com.apple.iCal"],
        groups: [
            [
                .key("上一页", "chevron.up", KeyCombo(kVK_LeftArrow, cmd)),
                .key("今天", "calendar.badge.clock", KeyCombo(kVK_ANSI_T, cmd)),
                .key("下一页", "chevron.down", KeyCombo(kVK_RightArrow, cmd)),
            ],
            [
                .text("日", "日", KeyCombo(kVK_ANSI_1, cmd)),
                .text("周", "周", KeyCombo(kVK_ANSI_2, cmd)),
                .text("月", "月", KeyCombo(kVK_ANSI_3, cmd)),
                .text("年", "年", KeyCombo(kVK_ANSI_4, cmd)),
            ],
            [
                .key("新建日程", "plus", KeyCombo(kVK_ANSI_N, cmd)),
            ],
        ]
    )

    static let preview = AppPreset(
        id: "preview",
        bundleIDs: ["com.apple.Preview"],
        groups: [
            [
                .key("放大", "plus.magnifyingglass", KeyCombo(kVK_ANSI_Equal, cmd)),
                .key("缩小", "minus.magnifyingglass", KeyCombo(kVK_ANSI_Minus, cmd)),
                .key("实际大小", "1.magnifyingglass", KeyCombo(kVK_ANSI_0, cmd)),
            ],
            [
                .key("向左旋转", "rotate.left", KeyCombo(kVK_ANSI_L, cmd)),
                .key("向右旋转", "rotate.right", KeyCombo(kVK_ANSI_R, cmd)),
            ],
            [
                .key("标记", "pencil.tip.crop.circle", KeyCombo(kVK_ANSI_A, cmdShift)),
                .key("侧边栏", "sidebar.left", KeyCombo(kVK_ANSI_2, cmdOpt)),
            ],
        ]
    )

    static let messages = AppPreset(
        id: "messages",
        bundleIDs: ["com.apple.MobileSMS"],
        groups: [
            [
                .key("新信息", "square.and.pencil", KeyCombo(kVK_ANSI_N, cmd)),
                emoji,
            ],
            [
                .key("上一个对话", "chevron.up", KeyCombo(kVK_Tab, [.maskControl, .maskShift])),
                .key("下一个对话", "chevron.down", KeyCombo(kVK_Tab, ctrl)),
            ],
        ]
    )

    static let notes = AppPreset(
        id: "notes",
        bundleIDs: ["com.apple.Notes"],
        groups: [
            [
                .key("新建备忘录", "square.and.pencil", KeyCombo(kVK_ANSI_N, cmd)),
                .key("核对清单", "checklist", KeyCombo(kVK_ANSI_L, cmdShift)),
                .key("表格", "tablecells", KeyCombo(kVK_ANSI_T, cmdOpt)),
            ],
            [
                .key("标题", "textformat", KeyCombo(kVK_ANSI_T, cmdShift)),
                .key("粗体", "bold", KeyCombo(kVK_ANSI_B, cmd)),
                .key("斜体", "italic", KeyCombo(kVK_ANSI_I, cmd)),
                .key("下划线", "underline", KeyCombo(kVK_ANSI_U, cmd)),
            ],
            [
                emoji,
            ],
        ]
    )

    static let textEditing = AppPreset(
        id: "textEditing",
        bundleIDs: [
            "com.apple.TextEdit",
            "com.apple.iWork.Pages",
            "com.microsoft.Word",
        ],
        groups: [
            [
                .key("粗体", "bold", KeyCombo(kVK_ANSI_B, cmd)),
                .key("斜体", "italic", KeyCombo(kVK_ANSI_I, cmd)),
                .key("下划线", "underline", KeyCombo(kVK_ANSI_U, cmd)),
            ],
            [
                .key("撤销", "arrow.uturn.backward", KeyCombo(kVK_ANSI_Z, cmd)),
                .key("重做", "arrow.uturn.forward", KeyCombo(kVK_ANSI_Z, cmdShift)),
            ],
            [
                .key("查找", "magnifyingglass", KeyCombo(kVK_ANSI_F, cmd)),
                emoji,
            ],
        ]
    )

    static let keynote = AppPreset(
        id: "keynote",
        bundleIDs: ["com.apple.iWork.Keynote", "com.microsoft.Powerpoint"],
        groups: [
            [
                .key("播放", "play.rectangle.fill", KeyCombo(kVK_ANSI_P, cmdOpt)),
                .key("新幻灯片", "rectangle.badge.plus", KeyCombo(kVK_ANSI_N, cmdShift)),
            ],
            [
                .key("上一张", "chevron.up", KeyCombo(kVK_UpArrow)),
                .key("下一张", "chevron.down", KeyCombo(kVK_DownArrow)),
            ],
            [
                .key("粗体", "bold", KeyCombo(kVK_ANSI_B, cmd)),
                .key("斜体", "italic", KeyCombo(kVK_ANSI_I, cmd)),
            ],
        ]
    )

    static let calculator = AppPreset(
        id: "calculator",
        bundleIDs: ["com.apple.calculator"],
        groups: [
            [
                .text("全部清除", "AC", KeyCombo(kVK_Escape)),
                .key("正负号", "plus.forwardslash.minus", KeyCombo(kVK_ANSI_Minus, .maskAlternate)),
                .key("百分比", "percent", KeyCombo(kVK_ANSI_5, .maskShift)),
            ],
            [
                .key("除", "divide", KeyCombo(kVK_ANSI_Slash)),
                .key("乘", "multiply", KeyCombo(kVK_ANSI_8, .maskShift)),
                .key("减", "minus", KeyCombo(kVK_ANSI_Minus)),
                .key("加", "plus", KeyCombo(kVK_ANSI_Equal, .maskShift)),
                .key("等于", "equal", KeyCombo(kVK_Return)),
            ],
        ]
    )

    static let photos = AppPreset(
        id: "photos",
        bundleIDs: ["com.apple.Photos"],
        groups: [
            [
                .key("上一张", "chevron.up", KeyCombo(kVK_LeftArrow)),
                .key("下一张", "chevron.down", KeyCombo(kVK_RightArrow)),
            ],
            [
                .key("收藏", "heart.fill", KeyCombo(kVK_ANSI_Period)),
                .key("向左旋转", "rotate.left", KeyCombo(kVK_ANSI_R, cmd)),
                .key("编辑", "wand.and.stars", KeyCombo(kVK_Return)),
            ],
            [
                .key("删除", "trash", KeyCombo(kVK_Delete, cmd)),
            ],
        ]
    )

    static let all: [AppPreset] = [
        browser, finder, terminal, codeEditor, xcode, media,
        mail, calendar, preview, messages, notes, textEditing, keynote,
        calculator, photos,
    ]
}

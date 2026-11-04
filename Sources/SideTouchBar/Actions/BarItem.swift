import Foundation

enum BarIcon: Hashable {
    case symbol(String)
    case text(String)
}

enum SystemCommand {
    case escape
    case playPause, next, previous
    case volumeUp, volumeDown, mute
    case brightnessUp, brightnessDown
    case keyboardBrightnessUp, keyboardBrightnessDown
    case missionControl, apps, siri
    case screenshot, lockScreen, showDesktop, spotlight
    case nightShift, darkMode, inputSource, emoji, shortcuts, sleep
}

enum BarAction {
    case keys(KeyCombo)
    case system(SystemCommand)
}

struct BarItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: BarIcon
    let action: BarAction

    static func key(_ title: String, _ symbol: String, _ combo: KeyCombo) -> BarItem {
        BarItem(title: title, icon: .symbol(symbol), action: .keys(combo))
    }

    static func text(_ title: String, _ label: String, _ combo: KeyCombo) -> BarItem {
        BarItem(title: title, icon: .text(label), action: .keys(combo))
    }

    static func system(_ title: String, _ symbol: String, _ command: SystemCommand) -> BarItem {
        BarItem(title: title, icon: .symbol(symbol), action: .system(command))
    }
}

/// A set of button groups shown in the app region while a matching app is frontmost.
struct AppPreset {
    let id: String
    let bundleIDs: Set<String>
    let groups: [[BarItem]]
}

/// Buttons that can be placed in the collapsed control strip, like the
/// Touch Bar "Customize Control Strip" palette.
enum ControlItem: String, CaseIterable, Identifiable {
    case brightness, volume, keyboardBrightness, mute, siri, playPause
    case missionControl, apps, screenshot, lockScreen, showDesktop, spotlight
    case nightShift, darkMode, inputSource, emoji, shortcuts, sleep

    static let defaultCompact: [ControlItem] = [.brightness, .volume, .mute, .siri]

    enum Behavior {
        case slider(LevelKind)
        case command(SystemCommand)
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brightness: "亮度"
        case .volume: "音量"
        case .keyboardBrightness: "键盘背光"
        case .mute: "静音"
        case .siri: "Siri"
        case .playPause: "播放/暂停"
        case .missionControl: "调度中心"
        case .apps: "启动台"
        case .screenshot: "截屏"
        case .lockScreen: "锁定屏幕"
        case .showDesktop: "显示桌面"
        case .spotlight: "聚焦搜索"
        case .nightShift: "夜览"
        case .darkMode: "深色模式"
        case .inputSource: "切换输入法"
        case .emoji: "表情与符号"
        case .shortcuts: "快捷指令"
        case .sleep: "睡眠"
        }
    }

    var symbol: String {
        switch self {
        case .brightness: "sun.max.fill"
        case .volume: "speaker.wave.2.fill"
        case .keyboardBrightness: "light.max"
        case .mute: "speaker.slash.fill"
        case .siri: "siri"
        case .playPause: "playpause.fill"
        case .missionControl: "rectangle.3.group"
        case .apps: "square.grid.3x3.fill"
        case .screenshot: "camera.viewfinder"
        case .lockScreen: "lock.fill"
        case .showDesktop: "menubar.dock.rectangle"
        case .spotlight: "magnifyingglass"
        case .nightShift: "sun.horizon.fill"
        case .darkMode: "circle.lefthalf.filled"
        case .inputSource: "globe"
        case .emoji: "face.smiling"
        case .shortcuts: "square.stack.3d.up.fill"
        case .sleep: "moon.zzz.fill"
        }
    }

    var behavior: Behavior {
        switch self {
        case .brightness: .slider(.brightness)
        case .volume: .slider(.volume)
        case .keyboardBrightness: .slider(.keyboard)
        case .mute: .command(.mute)
        case .siri: .command(.siri)
        case .playPause: .command(.playPause)
        case .missionControl: .command(.missionControl)
        case .apps: .command(.apps)
        case .screenshot: .command(.screenshot)
        case .lockScreen: .command(.lockScreen)
        case .showDesktop: .command(.showDesktop)
        case .spotlight: .command(.spotlight)
        case .nightShift: .command(.nightShift)
        case .darkMode: .command(.darkMode)
        case .inputSource: .command(.inputSource)
        case .emoji: .command(.emoji)
        case .shortcuts: .command(.shortcuts)
        case .sleep: .command(.sleep)
        }
    }
}

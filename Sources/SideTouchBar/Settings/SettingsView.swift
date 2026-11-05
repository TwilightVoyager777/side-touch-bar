import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject private var navigation = SettingsNavigation.shared
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        TabView(selection: $navigation.tab) {
            SetupSettingsView()
                .tabItem { Label(tr("开始"), systemImage: "checklist") }
                .tag(SettingsNavigation.Tab.setup)
            GeneralSettingsView()
                .tabItem { Label(tr("通用"), systemImage: "gearshape") }
                .tag(SettingsNavigation.Tab.general)
            AISettingsView()
                .tabItem { Label(tr("AI 编程"), systemImage: "sparkles") }
                .tag(SettingsNavigation.Tab.ai)
            ButtonSettingsView()
                .tabItem { Label(tr("按钮"), systemImage: "square.grid.2x2") }
                .tag(SettingsNavigation.Tab.buttons)
            MediaSettingsView()
                .tabItem { Label(tr("播放"), systemImage: "play.circle") }
                .tag(SettingsNavigation.Tab.media)
        }
        // Rebuild every label when the interface language changes.
        .id(settings.language)
        .frame(width: 540)
        .frame(minHeight: 620)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var display = DisplayStatus.shared

    private var buttonSizeDescription: String {
        var text = tr("按钮 %d pt", Int(display.buttonPoints))
        if let millimeters = display.buttonMillimeters {
            text += String(format: tr("（约 %.1f mm）"), millimeters)
        }
        if display.isShrunkToFit {
            text += tr("，已缩小以适应屏幕高度")
        }
        return text
    }

    var body: some View {
        Form {
            Section {
                Picker(tr("触控栏显示"), selection: $settings.barPage) {
                    ForEach(BarPage.allCases) { Text($0.title).tag($0) }
                }
                Picker(tr("按住 fn 键时"), selection: $settings.fnHoldPage) {
                    ForEach(BarPage.fnHoldChoices) { Text($0.title).tag($0) }
                }
            } header: {
                Text(tr("触控栏"))
            } footer: {
                Text(tr("和原来的 Touch Bar 一样：最上面是 esc，中间是当前应用的按钮，下面是控制条。按住键盘上的 fn（🌐）键会临时切换显示。"))
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(settings.functionKeyApps, id: \.self) { bundleID in
                    HStack {
                        AppLabel(bundleID: bundleID)
                        Spacer()
                        Button {
                            settings.functionKeyApps.removeAll { $0 == bundleID }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(tr("移除"))
                    }
                }
                Button(tr("添加应用…"), action: addFunctionKeyApp)
            } header: {
                Text(tr("总是显示 F1、F2 等键的应用"))
            } footer: {
                Text(tr("在这些应用里，触控栏默认显示 F1–F12；按住 fn 键时显示应用控件。"))
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker(tr("显示在"), selection: $settings.displayTarget) {
                    ForEach(DisplayTarget.allCases) { Text($0.title).tag($0) }
                }

                Picker(tr("尺寸"), selection: $settings.sizePreference) {
                    ForEach(SizePreference.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                LabeledContent(tr("当前显示器")) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(display.screenName)
                        Text(buttonSizeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(tr("显示器"))
            } footer: {
                Text(tr("尺寸以 14/16 英寸 MacBook Pro 为基准，按钮在不同显示器上保持差不多的实际大小；放不下时会自动缩小。"))
                    .foregroundStyle(.secondary)
            }

            Section(tr("外观")) {
                Picker(tr("玻璃效果"), selection: $settings.glassStyle) {
                    ForEach(GlassStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker(tr("颜色"), selection: $settings.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle(tr("危险操作需要长按（锁屏、删除、总是允许…）"), isOn: $settings.touchConfirm)
                Toggle(tr("按住连续触发（音量、缩放、快进…）"), isOn: $settings.touchRepeat)
                Toggle(tr("从边缘滑入唤出、在栏上往外滑收起"), isOn: $settings.touchEdgeSwipe)
                Toggle(tr("在输入框里自动显示文字编辑页"), isOn: $settings.touchAutoTextPage)
            } header: {
                Text(tr("触屏"))
            } footer: {
                Text(tr("控制条上的亮度、音量、键盘背光：点一下打开滑条，按住上下拖动直接调节。文字编辑页的触控区可以像 iPhone 按住空格键那样拖动光标。"))
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker(tr("显示方式"), selection: $settings.autoHide) {
                    Text(tr("自动隐藏")).tag(true)
                    Text(tr("一直显示")).tag(false)
                }
                .pickerStyle(.segmented)
                Picker(tr("闲置后收起"), selection: $settings.idleDelay) {
                    ForEach(Settings.idleDelayOptions, id: \.self) { seconds in
                        Text(seconds == 0 ? tr("从不") : tr("%d 秒", Int(seconds))).tag(seconds)
                    }
                }
                .disabled(!settings.autoHide)
            } header: {
                Text(tr("行为"))
            } footer: {
                Text(settings.autoHide
                    ? tr("指针或手指离开后收起，只在边缘留一条把手。")
                    : tr("侧边栏不会自己收起。在栏上往外滑可以临时收起，从边缘滑入或点把手再显示。"))
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(ControlItem.allCases) { item in
                    Toggle(isOn: binding(for: item)) {
                        Label {
                            Text(item.title)
                        } icon: {
                            Image(systemName: item.symbol)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!settings.compactItems.contains(item) && settings.compactItems.count >= Settings.maxCompactItems)
                }
            } header: {
                HStack {
                    Text(tr("自定义控制条"))
                    Spacer()
                    Button(tr("恢复默认")) { settings.compactItems = ControlItem.defaultCompact }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            } footer: {
                Text(tr("最多 %d 个，原版 Touch Bar 默认是亮度、音量、静音、Siri。点控制条顶部的 ⌃ 可以展开完整控制条。", Settings.maxCompactItems))
                    .foregroundStyle(.secondary)
            }

            Section(tr("权限")) {
                LabeledContent {
                    if permissions.isTrusted {
                        Label(tr("已授权"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button(tr("去授权…")) { Permissions.openSettings() }
                    }
                } label: {
                    Text(tr("辅助功能"))
                    Text(tr("用于发送快捷键、媒体键、esc，以及识别 fn 键"))
                }
            }
        }
        .formStyle(.grouped)
    }

    private func addFunctionKeyApp() {
        let ids = chooseApps()
        settings.functionKeyApps += ids.filter { !settings.functionKeyApps.contains($0) }
    }

    private func binding(for item: ControlItem) -> Binding<Bool> {
        Binding {
            settings.compactItems.contains(item)
        } set: { isOn in
            var selected = Set(settings.compactItems)
            if isOn { selected.insert(item) } else { selected.remove(item) }
            // Keep the existing order, append new items at the end.
            var ordered = settings.compactItems.filter { selected.contains($0) }
            if isOn, !ordered.contains(item) { ordered.append(item) }
            settings.compactItems = ordered
        }
    }
}

/// Lets the user pick apps from /Applications; returns their bundle IDs.
@MainActor
func chooseApps(multiple: Bool = true) -> [String] {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.application]
    panel.directoryURL = URL(fileURLWithPath: "/Applications")
    panel.allowsMultipleSelection = multiple
    panel.prompt = tr("添加")
    guard panel.runModal() == .OK else { return [] }
    return panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
}

/// Asks before changing files outside the app.
@MainActor
func confirm(_ title: String, _ message: String, action: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: action)
    alert.addButton(withTitle: tr("取消"))
    return alert.runModal() == .alertFirstButtonReturn
}

@MainActor
func showError(_ error: Error) {
    let alert = NSAlert(error: error)
    alert.runModal()
}

/// App icon and name for a bundle ID.
struct AppLabel: View {
    let bundleID: String

    var body: some View {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        Label {
            Text(url.map { FileManager.default.displayName(atPath: $0.path) } ?? bundleID)
        } icon: {
            if let url {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.dashed")
            }
        }
    }
}

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var display = DisplayStatus.shared

    private var buttonSizeDescription: String {
        var text = "按钮 \(Int(display.buttonPoints)) pt"
        if let millimeters = display.buttonMillimeters {
            text += String(format: "（约 %.1f mm）", millimeters)
        }
        if display.isShrunkToFit {
            text += "，已缩小以适应屏幕高度"
        }
        return text
    }

    var body: some View {
        Form {
            Section {
                Picker("触控栏显示", selection: $settings.barPage) {
                    ForEach(BarPage.allCases) { Text($0.title).tag($0) }
                }
                Picker("按住 fn 键时", selection: $settings.fnHoldPage) {
                    ForEach(BarPage.fnHoldChoices) { Text($0.title).tag($0) }
                }
            } header: {
                Text("触控栏")
            } footer: {
                Text("和原来的 Touch Bar 一样：最上面是 esc，中间是当前应用的按钮，下面是控制条。按住键盘上的 fn（🌐）键会临时切换显示。")
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
                        .help("移除")
                    }
                }
                Button("添加应用…", action: addFunctionKeyApp)
            } header: {
                Text("总是显示 F1、F2 等键的应用")
            } footer: {
                Text("在这些应用里，触控栏默认显示 F1–F12；按住 fn 键时显示应用控件。")
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("显示在", selection: $settings.displayTarget) {
                    ForEach(DisplayTarget.allCases) { Text($0.title).tag($0) }
                }

                Picker("尺寸", selection: $settings.sizePreference) {
                    ForEach(SizePreference.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                LabeledContent("当前显示器") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(display.screenName)
                        Text(buttonSizeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("显示器")
            } footer: {
                Text("尺寸以 14/16 英寸 MacBook Pro 为基准，按钮在不同显示器上保持差不多的实际大小；放不下时会自动缩小。")
                    .foregroundStyle(.secondary)
            }

            Section("外观") {
                Picker("玻璃效果", selection: $settings.glassStyle) {
                    ForEach(GlassStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker("颜色", selection: $settings.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("行为") {
                Toggle("自动隐藏", isOn: $settings.autoHide)
                Picker("闲置后收起", selection: $settings.idleDelay) {
                    ForEach(Settings.idleDelayOptions, id: \.self) { seconds in
                        Text(seconds == 0 ? "从不" : "\(Int(seconds)) 秒").tag(seconds)
                    }
                }
                .disabled(!settings.autoHide)
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
                    Text("自定义控制条")
                    Spacer()
                    Button("恢复默认") { settings.compactItems = ControlItem.defaultCompact }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            } footer: {
                Text("最多 \(Settings.maxCompactItems) 个，原版 Touch Bar 默认是亮度、音量、静音、Siri。点控制条顶部的 ⌃ 可以展开完整控制条。")
                    .foregroundStyle(.secondary)
            }

            Section("权限") {
                LabeledContent {
                    if permissions.isTrusted {
                        Label("已授权", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("去授权…") { Permissions.openSettings() }
                    }
                } label: {
                    Text("辅助功能")
                    Text("用于发送快捷键、媒体键、esc，以及识别 fn 键")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .frame(minHeight: 560)
    }

    private func addFunctionKeyApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = "添加"
        guard panel.runModal() == .OK else { return }
        let ids = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
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

/// App icon and name for a bundle ID.
private struct AppLabel: View {
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

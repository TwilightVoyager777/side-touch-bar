import Carbon.HIToolbox
import SwiftUI

/// Editing state for the custom button editor (kept outside the view because
/// SwiftUI `@State` isn't available with the Command Line Tools).
@MainActor
final class ButtonEditorModel: ObservableObject {
    static let shared = ButtonEditorModel()

    @Published var bundleID: String?
    @Published var menuEntries: [MenuInvoker.Entry] = []
    @Published var menuSearch = ""
    @Published var isRecording = false
    @Published var newText = ""
    @Published var message: String?

    private var recorder: Any?

    /// Apps worth customizing: running ones plus those with buttons already.
    var apps: [String] {
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap(\.bundleIdentifier)
        return Array(Set(running).union(Settings.shared.customButtons.keys))
            .sorted { Self.name(of: $0).localizedStandardCompare(Self.name(of: $1)) == .orderedAscending }
    }

    var filteredEntries: [MenuInvoker.Entry] {
        let query = menuSearch.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return menuEntries }
        return menuEntries.filter { $0.id.localizedCaseInsensitiveContains(query) }
    }

    func loadMenus() {
        guard let bundleID,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            menuEntries = []
            message = tr("要读取菜单，请先打开这个应用。")
            return
        }
        guard Permissions.shared.requestIfNeeded() else {
            message = tr("需要辅助功能权限才能读取菜单。")
            return
        }
        menuEntries = MenuInvoker.entries(of: app)
        message = menuEntries.isEmpty ? tr("没有读到菜单。") : nil
    }

    func add(_ button: CustomButton) {
        guard let bundleID else { return }
        var set = Settings.shared.customButtons[bundleID] ?? CustomButtonSet()
        guard set.buttons.count < PresetResolver.maxCustomButtons else {
            message = tr("每个应用最多 %d 个自定义按钮。", PresetResolver.maxCustomButtons)
            return
        }
        set.buttons.append(button)
        Settings.shared.customButtons[bundleID] = set
    }

    func startRecording() {
        stopRecording()
        isRecording = true
        recorder = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let combo = KeyCombo(key: CGKeyCode(event.keyCode), flags: CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
            let title = Self.describe(event)
            MainActor.assumeIsolated {
                self?.add(CustomButton(title: title, symbol: "", kind: .keys(combo)))
                self?.stopRecording()
            }
            return nil
        }
    }

    func stopRecording() {
        if let recorder { NSEvent.removeMonitor(recorder) }
        recorder = nil
        isRecording = false
    }

    static func name(of bundleID: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { FileManager.default.displayName(atPath: $0.path) } ?? bundleID
    }

    private nonisolated static func describe(_ event: NSEvent) -> String {
        var text = ""
        let flags = event.modifierFlags
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        let special: [Int: String] = [
            kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: tr("空格"), kVK_Delete: "⌫", kVK_Escape: "esc",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        text += special[Int(event.keyCode)] ?? (event.charactersIgnoringModifiers ?? "?").uppercased()
        return text
    }
}

struct ButtonSettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var model = ButtonEditorModel.shared

    var body: some View {
        Form {
            Section {
                Picker(tr("应用"), selection: $model.bundleID) {
                    Text(tr("选择应用")).tag(String?.none)
                    ForEach(model.apps, id: \.self) { id in
                        Text(ButtonEditorModel.name(of: id)).tag(String?.some(id))
                    }
                }
                .onChange(of: model.bundleID) {
                    model.menuEntries = []
                    model.menuSearch = ""
                    model.message = nil
                }

                if let bundleID = model.bundleID {
                    customButtons(for: bundleID)
                }
            } header: {
                Text(tr("自定义按钮"))
            } footer: {
                Text(tr("自定义按钮显示在这个应用按钮的“自定义”页；勾选“只显示自定义按钮”则替换内置按钮。点菜单项不受快捷键变化影响，推荐优先使用。"))
                    .foregroundStyle(.secondary)
            }

            if model.bundleID != nil {
                Section(tr("从菜单添加")) {
                    HStack {
                        TextField(tr("搜索菜单"), text: $model.menuSearch)
                        Button(tr("读取菜单")) { model.loadMenus() }
                    }
                    if let message = model.message {
                        Text(message).foregroundStyle(.secondary)
                    }
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(model.filteredEntries) { entry in
                                HStack {
                                    Text(entry.id).lineLimit(1)
                                    Spacer()
                                    if let shortcut = entry.shortcut {
                                        Text(shortcut).foregroundStyle(.secondary).font(.caption.monospaced())
                                    }
                                    Button {
                                        model.add(CustomButton(title: entry.title, symbol: "", kind: .menu(entry.path)))
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(height: model.menuEntries.isEmpty ? 0 : 180)
                }

                Section(tr("其他方式")) {
                    HStack {
                        Text(model.isRecording ? tr("请按下要录制的快捷键…") : tr("录制一个快捷键"))
                        Spacer()
                        Button(model.isRecording ? tr("取消") : tr("录制")) {
                            model.isRecording ? model.stopRecording() : model.startRecording()
                        }
                    }
                    HStack {
                        TextField(tr("输入一段文字"), text: $model.newText)
                        Button(tr("添加")) {
                            let text = model.newText.trimmingCharacters(in: .whitespaces)
                            guard !text.isEmpty else { return }
                            model.add(CustomButton(title: String(text.prefix(6)), symbol: "", kind: .text(text, submit: false)))
                            model.newText = ""
                        }
                    }
                }
            }

            Section {
                ForEach($settings.favoriteSites) { $site in
                    HStack(spacing: 8) {
                        TextField(tr("名称"), text: $site.title)
                            .frame(width: 90)
                        TextField("https://", text: $site.url)
                        Button {
                            settings.favoriteSites.removeAll { $0.id == site.id }
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button(tr("添加网站")) {
                    settings.favoriteSites.append(FavoriteSite(title: "", url: "https://"))
                }
            } header: {
                Text(tr("常用网站"))
            } footer: {
                Text(tr("显示在浏览器按钮的“网站”页，点一下在当前浏览器里打开。"))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onDisappear { model.stopRecording() }
    }

    @ViewBuilder
    private func customButtons(for bundleID: String) -> some View {
        let binding = Binding<CustomButtonSet> {
            settings.customButtons[bundleID] ?? CustomButtonSet()
        } set: {
            settings.customButtons[bundleID] = $0.buttons.isEmpty && !$0.replacesBuiltIn ? nil : $0
        }

        Toggle(tr("只显示自定义按钮"), isOn: binding.replacesBuiltIn)

        ForEach(Array(binding.wrappedValue.buttons.enumerated()), id: \.element.id) { index, button in
            HStack(spacing: 8) {
                Group {
                    if button.symbol.isEmpty {
                        Text(String(button.title.prefix(2))).font(.caption.bold())
                    } else {
                        Image(systemName: button.symbol)
                    }
                }
                .frame(width: 24)
                TextField(tr("名称"), text: binding.buttons[index].title)
                TextField(tr("图标（SF Symbol）"), text: binding.buttons[index].symbol)
                    .frame(width: 130)
                Text(kindDescription(button.kind))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 80, alignment: .leading)
                Button {
                    var set = binding.wrappedValue
                    set.buttons.remove(at: index)
                    binding.wrappedValue = set
                } label: {
                    Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func kindDescription(_ kind: CustomButton.Kind) -> String {
        switch kind {
        case .menu(let path): tr("菜单 ") + path.joined(separator: "›")
        case .keys: tr("快捷键")
        case .text(let text, _): tr("文字 ") + text
        }
    }
}

struct MediaSettingsView: View {
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        Form {
            Section {
                Picker(tr("视频快进 / 快退"), selection: $settings.mediaSkipSeconds) {
                    ForEach(Settings.mediaSkipOptions, id: \.self) { Text(tr("%d 秒", Int($0))).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text(tr("播放控件"))
            } footer: {
                Text(tr("播放视频或音乐时，应用控件会换成统一的播放控件。点“更多”可以调倍速、全屏、画中画、字幕、随机和循环；点扬声器图标可以切换音频输出。"))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

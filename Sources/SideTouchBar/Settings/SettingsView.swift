import SwiftUI

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
                LayoutPicker(selection: $settings.layout)
                    .padding(.vertical, 4)

                if settings.layout == .both {
                    Picker("系统控制条", selection: $settings.controlStripSide) {
                        Text("左侧").tag(BarSide.left)
                        Text("右侧").tag(BarSide.right)
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("布局")
            } footer: {
                Text(layoutFooter)
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
                    Text("收起时的控制条")
                    Spacer()
                    Button("恢复默认") { settings.compactItems = ControlItem.defaultCompact }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            } footer: {
                Text("最多 \(Settings.maxCompactItems) 个。点控制条顶部的 ⌃ 可以展开完整控制条。")
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
                    Text("用于发送快捷键、媒体键和 esc")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .frame(minHeight: 560)
    }

    private var layoutFooter: String {
        switch settings.layout {
        case .both:
            "一侧显示系统控制条，另一侧显示 esc、fn 和当前应用的按钮。"
        case .left, .right:
            "应用按钮和系统控制条合并在同一条里，和原来的 Touch Bar 一样。"
        }
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

/// Three little screens showing where the bars appear.
struct LayoutPicker: View {
    @Binding var selection: BarLayout

    var body: some View {
        HStack(spacing: 14) {
            ForEach(BarLayout.allCases) { layout in
                Button {
                    withAnimation(.snappy) { selection = layout }
                } label: {
                    VStack(spacing: 8) {
                        LayoutThumbnail(layout: layout, isSelected: selection == layout)
                        Text(layout.title)
                            .font(.callout)
                            .foregroundStyle(selection == layout ? .primary : .secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LayoutThumbnail: View {
    let layout: BarLayout
    let isSelected: Bool

    var body: some View {
        let screen = RoundedRectangle(cornerRadius: 8, style: .continuous)
        ZStack {
            screen.fill(
                LinearGradient(
                    colors: [Color(red: 0.36, green: 0.55, blue: 0.95), Color(red: 0.62, green: 0.4, blue: 0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            HStack {
                bar(visible: layout != .right)
                Spacer()
                bar(visible: layout != .left)
            }
            .padding(5)
        }
        .frame(width: 112, height: 72)
        .overlay(
            screen.strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 3 : 1)
        )
        .shadow(color: .black.opacity(isSelected ? 0.18 : 0.08), radius: isSelected ? 6 : 3, y: 2)
    }

    private func bar(visible: Bool) -> some View {
        Capsule()
            .fill(.white.opacity(0.75))
            .overlay(Capsule().strokeBorder(.white, lineWidth: 0.5))
            .frame(width: 9, height: 44)
            .opacity(visible ? 1 : 0)
    }
}

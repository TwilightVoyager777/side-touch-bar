import SwiftUI

/// The whole bar at its natural size, without glass: the Touch Bar turned
/// vertical — esc on top, then the page chosen in settings. Also used by
/// `BarSizer` to measure how tall each page gets.
struct BarBody: View {
    @ObservedObject var state: BarState
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var frontmost = FrontmostAppMonitor.shared
    @ObservedObject private var permissions = Permissions.shared
    @Environment(\.barMetrics) private var metrics

    private var page: BarPage {
        state.currentPage(settings: settings, frontmostBundleID: frontmost.app?.bundleIdentifier)
    }

    var body: some View {
        VStack(spacing: metrics.spacing) {
            BarButton(icon: .text("esc"), help: "Esc") { ActionRunner.run(.escape) }
            BarDivider()

            if !permissions.isTrusted {
                BarButton(icon: .symbol("exclamationmark.triangle.fill"), help: "需要辅助功能权限才能发送快捷键", tint: .orange) {
                    Permissions.openSettings()
                }
            }

            Group {
                switch page {
                case .appControlsWithStrip:
                    StandardPage(state: state)
                case .expandedStrip:
                    ItemGroupsView(groups: AppPresets.controlStripFull)
                case .appControls:
                    AppControlsView(state: state)
                case .functionKeys:
                    ItemGroupsView(groups: AppPresets.functionKeys)
                case .quickActions:
                    QuickActionsPage()
                case .spaces:
                    SpacesPage()
                }
            }
            .transition(.blurReplace)
        }
        .animation(BarAnimation.morph, value: page)
        .padding(.vertical, metrics.innerPadding)
        .frame(width: metrics.width)
    }
}

/// The default Touch Bar: app controls, then the control strip. Expanding the
/// strip replaces the app controls, as on the Touch Bar.
struct StandardPage: View {
    @ObservedObject var state: BarState
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        VStack(spacing: metrics.spacing) {
            if state.stripMode == .compact {
                AppControlsView(state: state)
                    .transition(.blurReplace)
                BarDivider()
            }
            ControlStripView(state: state)
        }
    }
}

/// Buttons for the frontmost app, or the emoji scrubber.
struct AppControlsView: View {
    @ObservedObject var state: BarState
    @ObservedObject private var frontmost = FrontmostAppMonitor.shared

    private var preset: AppPreset { state.presetOverride ?? frontmost.preset }

    var body: some View {
        Group {
            if state.showEmojiPicker {
                EmojiPickerView(state: state)
            } else {
                ItemGroupsView(groups: preset.groups, state: state)
                    .id(preset.id)
            }
        }
        .transition(.blurReplace)
        .animation(BarAnimation.morph, value: preset.id)
        .animation(BarAnimation.morph, value: state.showEmojiPicker)
    }
}

/// The Touch Bar emoji scrubber: tap to type an emoji into the focused app.
struct EmojiPickerView: View {
    @ObservedObject var state: BarState
    @ObservedObject private var store = EmojiStore.shared
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        VStack(spacing: metrics.spacing) {
            BarButton(icon: .symbol("xmark"), help: "关闭表情") {
                withAnimation(BarAnimation.morph) { state.showEmojiPicker = false }
            }
            ScrollingColumn {
                ForEach(store.all, id: \.self) { emoji in
                    Button {
                        store.use(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: metrics.symbolSize * 1.4))
                            .frame(width: metrics.buttonSize, height: metrics.buttonSize)
                            .contentShape(Circle())
                    }
                    .buttonStyle(GlassBarButtonStyle())
                }
            }
        }
    }
}

/// The Touch Bar "Quick Actions" page, backed by the Shortcuts app.
struct QuickActionsPage: View {
    @ObservedObject private var store = QuickActionsStore.shared
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        VStack(spacing: metrics.spacing) {
            BarButton(icon: .symbol("square.stack.3d.up.fill"), help: "打开快捷指令") {
                ActionRunner.run(.shortcuts)
            }
            BarDivider()
            ScrollingColumn {
                if store.names.isEmpty {
                    Text(store.isLoading ? "载入中" : "没有快捷指令")
                        .font(.system(size: metrics.captionSize))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, metrics.spacing * 2)
                }
                ForEach(store.names, id: \.self) { name in
                    Button {
                        store.run(name)
                    } label: {
                        Text(name)
                            .font(.system(size: metrics.captionSize, weight: .medium))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.7)
                            .padding(3 * metrics.scale)
                            .frame(width: metrics.buttonSize, height: metrics.buttonSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(GlassBarButtonStyle(cornerRadius: metrics.buttonSize * 0.3))
                    .help(name)
                }
            }
        }
        .onAppear { store.reloadIfNeeded() }
    }
}

/// The Touch Bar "Spaces" page: one button per desktop, current one highlighted.
struct SpacesPage: View {
    @ObservedObject private var store = SpacesStore.shared
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        VStack(spacing: metrics.spacing) {
            BarButton(icon: .symbol("rectangle.3.group"), help: "调度中心") {
                ActionRunner.run(.missionControl)
            }
            BarButton(icon: .symbol("chevron.up"), help: "上一个空间") { store.move(by: -1) }
            BarDivider()
            ScrollingColumn {
                ForEach(Array(store.spaces.enumerated()), id: \.element.id) { index, space in
                    BarButton(
                        icon: space.isFullScreen ? .symbol("arrow.up.left.and.arrow.down.right") : .text("\(index + 1)"),
                        help: space.isFullScreen ? "全屏应用" : "桌面 \(index + 1)",
                        tint: space.id == store.currentID ? .accentColor : nil
                    ) {
                        store.switchTo(space)
                    }
                }
            }
            BarDivider()
            BarButton(icon: .symbol("chevron.down"), help: "下一个空间") { store.move(by: 1) }
        }
        .onAppear { store.refresh() }
    }
}

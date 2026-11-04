import SwiftUI

/// The Touch Bar "app region": esc, fn, the frontmost app's icon, and buttons for that app.
struct AppRegionView: View {
    @ObservedObject var state: BarState
    @ObservedObject private var frontmost = FrontmostAppMonitor.shared
    @ObservedObject private var permissions = Permissions.shared
    @Environment(\.barMetrics) private var metrics

    private var preset: AppPreset { state.presetOverride ?? frontmost.preset }

    var body: some View {
        VStack(spacing: metrics.spacing) {
            BarButton(icon: .text("esc"), help: "Esc") { ActionRunner.run(.escape) }
            BarButton(icon: .text("fn"), help: "功能键 F1–F12", tint: state.showFunctionKeys ? .accentColor : nil) {
                withAnimation(BarAnimation.morph) { state.showFunctionKeys.toggle() }
            }
            BarDivider()

            if !permissions.isTrusted {
                BarButton(icon: .symbol("exclamationmark.triangle.fill"), help: "需要辅助功能权限才能发送快捷键", tint: .orange) {
                    Permissions.openSettings()
                }
            }

            if state.showFunctionKeys {
                ItemGroupsView(groups: AppPresets.functionKeys)
                    .transition(.blurReplace)
            } else {
                // The combined bar is tall already; the Touch Bar never showed the icon either.
                if state.content != .combined, let icon = frontmost.app?.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: metrics.appIconSize, height: metrics.appIconSize)
                        .padding(.vertical, 2 * metrics.scale)
                        .help(frontmost.app?.localizedName ?? "")
                }
                ItemGroupsView(groups: preset.groups)
                    .id(preset.id)
                    .transition(.blurReplace)
            }
        }
        .animation(BarAnimation.morph, value: preset.id)
    }
}

/// Single-side layout: app region on top, control strip below — the Touch Bar
/// order, with the control strip in easy thumb reach. As on the Touch Bar,
/// expanding the strip replaces the app region, and fn keys take the whole bar.
struct CombinedBarView: View {
    @ObservedObject var state: BarState
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        VStack(spacing: metrics.spacing) {
            if state.stripMode == .compact {
                AppRegionView(state: state)
                    .transition(.blurReplace)
            }
            if !state.showFunctionKeys {
                if state.stripMode == .compact { BarDivider() }
                ControlStripView(state: state)
                    .transition(.blurReplace)
            }
        }
    }
}

import SwiftUI

/// Vertical version of the Touch Bar Control Strip: a compact set of system
/// controls that can expand to the full strip, or turn into a level slider.
struct ControlStripView: View {
    @ObservedObject var state: BarState
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var frontmost = FrontmostAppMonitor.shared
    @ObservedObject private var nowPlaying = NowPlayingStore.shared
    @Environment(\.barMetrics) private var metrics

    /// The Touch Bar's Now Playing button: something plays, but the app
    /// controls aren't already showing its playback controls.
    private var nowPlayingButtonInfo: NowPlayingInfo? {
        guard let info = NowPlayingPresentation.info(for: state),
              !NowPlayingPresentation.isShown(state: state, frontmost: frontmost.app)
        else { return nil }
        return info
    }

    var body: some View {
        VStack(spacing: metrics.spacing) {
            switch state.stripMode {
            case .compact:
                compact
            case .full:
                full
            case .slider(let kind):
                LevelSliderPanel(kind: kind, state: state) { set(.compact) }
            }
        }
    }

    @ViewBuilder
    private var compact: some View {
        BarButton(icon: .symbol("chevron.up"), help: "展开控制条") { set(.full) }
        BarDivider()
        if let info = nowPlayingButtonInfo {
            BarButton(icon: info.app?.icon.map(BarIcon.image) ?? .symbol("play.circle.fill"), help: "正在播放：\(info.title)") {
                withAnimation(BarAnimation.morph) { state.nowPlayingOverride = true }
            }
        }
        ForEach(settings.compactItems) { item in
            BarButton(icon: .symbol(item.symbol), help: item.title) {
                switch item.behavior {
                case .slider(let kind):
                    set(.slider(kind))
                case .command(let command):
                    ActionRunner.run(command)
                }
            }
        }
    }

    @ViewBuilder
    private var full: some View {
        BarButton(icon: .symbol("xmark"), help: "收起控制条") { set(.compact) }
        BarDivider()
        ItemGroupsView(groups: AppPresets.controlStripFull)
    }

    private func set(_ mode: ControlStripMode) {
        withAnimation(BarAnimation.morph) { state.stripMode = mode }
    }
}

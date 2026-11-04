import SwiftUI

/// Vertical version of the Touch Bar Control Strip: a compact set of system
/// controls that can expand to the full strip, or turn into a level slider.
struct ControlStripView: View {
    @ObservedObject var state: BarState
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var frontmost = FrontmostAppMonitor.shared
    @ObservedObject private var nowPlaying = NowPlayingStore.shared
    @ObservedObject private var agents = AgentMonitor.shared
    @Environment(\.barMetrics) private var metrics

    /// One contextual slot, like the Touch Bar's Now Playing button: agents
    /// that want attention first, then media playing elsewhere, then running agents.
    private enum ContextButton {
        case agents(AgentStatus)
        case nowPlaying(NowPlayingInfo)
    }

    private var contextButton: ContextButton? {
        let content = AppControlsContent.resolve(state: state)
        let agentStatus = settings.aiEnabled ? (state.agentSessionSample?.status ?? agents.attention) : nil
        if let agentStatus, agentStatus.wantsAttention, !content.isAgentRelated {
            return .agents(agentStatus)
        }
        if case .nowPlaying = content {} else if let info = NowPlayingPresentation.info(for: state) {
            return .nowPlaying(info)
        }
        if agentStatus == .running, !content.isAgentRelated {
            return .agents(.running)
        }
        return nil
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
        switch contextButton {
        case .agents(let status):
            BarButton(icon: .symbol("sparkles"), help: "AI 会话：\(status.title)", tint: status == .running ? nil : status.color) {
                withAnimation(BarAnimation.morph) { state.showSessions = true }
            }
        case .nowPlaying(let info):
            BarButton(icon: info.app?.icon.map(BarIcon.image) ?? .symbol("play.circle.fill"), help: "正在播放：\(info.title)") {
                withAnimation(BarAnimation.morph) { state.nowPlayingOverride = true }
            }
        case nil:
            EmptyView()
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

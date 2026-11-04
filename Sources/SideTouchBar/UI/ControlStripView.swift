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
            BarButton(icon: .symbol("sparkles"), help: tr("AI 会话：%@", status.title), tint: status == .running ? nil : status.color) {
                withAnimation(BarAnimation.morph) { state.showSessions = true }
            }
        case .nowPlaying(let info):
            BarButton(icon: info.app?.icon.map(BarIcon.image) ?? .symbol("play.circle.fill"), help: tr("正在播放：%@", info.title)) {
                withAnimation(BarAnimation.morph) { state.nowPlayingOverride = true }
            }
        case nil:
            EmptyView()
        }
        ForEach(settings.compactItems) { item in
            switch item.behavior {
            case .slider(let kind):
                LevelSlideButton(kind: kind, symbol: item.symbol, help: item.title, state: state) {
                    set(.slider(kind))
                }
            case .command(let command):
                BarButton(icon: .symbol(item.symbol), help: item.title, behavior: item.isDangerous ? .confirm : .tap) {
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

/// Like the Touch Bar: tap to open the slider, or press and drag up/down to
/// change the level right away. A ring shows the level while sliding.
struct LevelSlideButton: View {
    let kind: LevelKind
    let symbol: String
    let help: String
    @ObservedObject var state: BarState
    let onTap: () -> Void

    @GestureState private var isPressed = false
    @Environment(\.barMetrics) private var metrics

    private var isSliding: Bool { state.slidingLevel == kind }

    var body: some View {
        BarIconView(icon: .symbol(symbol))
            .frame(width: metrics.buttonSize, height: metrics.buttonSize)
            .background(Circle().fill(GlassBarButtonStyle.fill(tint: nil, pressed: isPressed)))
            .overlay(
                Circle()
                    .trim(from: 0, to: state.slideValue)
                    .stroke(Color.primary.opacity(0.85), style: StrokeStyle(lineWidth: 3 * metrics.scale, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(1.5 * metrics.scale)
                    .opacity(isSliding ? 1 : 0)
            )
            .scaleEffect(isPressed && !isSliding ? 0.88 : 1)
            .animation(BarAnimation.press, value: isPressed)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, pressed, _ in pressed = true }
                    .onChanged { gesture in
                        if state.slidingLevel == nil, abs(gesture.translation.height) > 6,
                           let current = LevelControl.get(kind) {
                            state.slidingLevel = kind
                            state.slideStart = current
                            state.isInteracting = true
                        }
                        guard isSliding else { return }
                        let value = min(max(Double(state.slideStart) - gesture.translation.height / metrics.sliderHeight, 0), 1)
                        state.slideValue = value
                        LevelControl.set(kind, Float(value))
                    }
                    .onEnded { _ in
                        if isSliding {
                            state.slidingLevel = nil
                            state.isInteracting = false
                        } else {
                            onTap()
                        }
                    }
            )
            .help(tr(help) + tr("（点按打开滑条，按住上下拖动直接调节）"))
    }
}

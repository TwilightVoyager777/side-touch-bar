import SwiftUI

/// The extra views a preset page asks for, rendered after its buttons.
struct PageExtrasView: View {
    let extras: [PageExtra]
    @ObservedObject var state: BarState
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        ForEach(Array(extras.enumerated()), id: \.offset) { _, extra in
            switch extra {
            case .agentStatus:
                AgentStatusBadge(state: state)
            case .voiceAndScreenshot:
                BarDivider()
                VoiceButton(state: state)
                BarButton(icon: .symbol("camera.viewfinder"), help: "截图发给 AI") { AIActions.screenshot() }
            case .quickInputs:
                BarDivider()
                QuickInputColumn()
            case .browserTabs:
                BrowserTabsView()
            case .scrollPad:
                BarDivider()
                ScrollPadView(state: state)
            case .favoriteSites:
                FavoriteSitesColumn()
            case .cursorPad:
                BarDivider()
                CursorPadView(state: state)
            }
        }
    }
}

/// Status and context usage of the agent session in the frontmost terminal.
struct AgentStatusBadge: View {
    @ObservedObject var state: BarState
    @ObservedObject private var monitor = AgentMonitor.shared
    @ObservedObject private var frontmost = FrontmostAppMonitor.shared
    @Environment(\.barMetrics) private var metrics

    private var session: AgentSession? {
        state.agentSessionSample ?? monitor.session(inTerminal: frontmost.app)
    }

    var body: some View {
        HStack(spacing: 3 * metrics.scale) {
            Circle()
                .fill(session?.status.color ?? .secondary.opacity(0.4))
                .frame(width: 7 * metrics.scale, height: 7 * metrics.scale)
            if let percent = session?.contextPercent {
                ContextGauge(percent: percent)
            } else {
                Text(session?.status.title ?? "AI")
                    .font(.system(size: metrics.captionSize * 0.9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(width: metrics.width - 6, height: metrics.captionSize * 2.4)
        .help(helpText)
    }

    private var helpText: String {
        guard let session else { return tr("安装状态提醒后，这里会显示会话状态和上下文用量") }
        var parts = [tr("%@：%@", session.agent.title, session.status.title)]
        if let model = session.model { parts.append(model) }
        if let percent = session.contextPercent { parts.append(tr("上下文 %d%%", Int(percent))) }
        if let cost = session.cost { parts.append(String(format: "$%.2f", cost)) }
        return parts.joined(separator: " · ")
    }
}

/// Context window usage as a small ring, orange from 70% and red from 90%.
struct ContextGauge: View {
    let percent: Double
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        let size = metrics.captionSize * 2.1
        ZStack {
            Circle().stroke(Color.primary.opacity(0.15), lineWidth: 2.5 * metrics.scale)
            Circle()
                .trim(from: 0, to: min(percent, 100) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 2.5 * metrics.scale, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(percent))")
                .font(.system(size: metrics.captionSize * 0.75, weight: .semibold, design: .rounded).monospacedDigit())
        }
        .frame(width: size, height: size)
    }

    private var color: Color {
        percent >= 90 ? .red : percent >= 70 ? .orange : .green
    }
}

/// Hold to talk; the transcript is typed into the frontmost app on release.
struct VoiceButton: View {
    @ObservedObject var state: BarState
    @ObservedObject private var voice = VoiceInput.shared
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        BarIconView(icon: .symbol(voice.isListening ? "waveform" : "mic.fill"))
            .foregroundStyle(voice.isListening ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(width: metrics.buttonSize, height: metrics.buttonSize)
            .background(Circle().fill(voice.isListening ? Color.red.opacity(0.9) : Color.primary.opacity(0.07)))
            .scaleEffect(voice.isListening ? 1.08 : 1)
            .animation(BarAnimation.press, value: voice.isListening)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !voice.isListening else { return }
                        state.isInteracting = true
                        voice.begin()
                    }
                    .onEnded { _ in
                        state.isInteracting = false
                        voice.end()
                    }
            )
            .help(tr(voice.errorMessage ?? "按住说话，松开后输入"))
    }
}

/// One-tap prompts and slash commands from settings.
struct QuickInputColumn: View {
    @ObservedObject private var settings = Settings.shared
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: metrics.spacing) {
                ForEach(settings.aiSnippets) { snippet in
                    TextButton(title: snippet.title, help: snippet.text) {
                        TextInserter.insert(snippet.text, submit: snippet.submit)
                    }
                }
            }
        }
        .scrollIndicators(.never)
        .frame(width: metrics.width, height: metrics.quickInputHeight)
    }
}

/// A rounded-square button with a short text label, for names that don't fit a symbol.
struct TextButton: View {
    let title: String
    var help: String = ""
    var tint: Color?
    let action: () -> Void
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        Button(action: action) {
            Text(tr(title))
                .font(.system(size: metrics.captionSize, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .padding(3 * metrics.scale)
                .frame(width: metrics.buttonSize, height: metrics.buttonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(GlassBarButtonStyle(tint: tint, cornerRadius: metrics.buttonSize * 0.3))
        .help(tr(help.isEmpty ? title : help))
    }
}

/// A session needs a permission decision: shown wherever you are, with the
/// agent's answer keys, so it can be approved without switching windows first.
struct AgentAttentionPanel: View {
    @ObservedObject var state: BarState
    let session: AgentSession
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        VStack(spacing: metrics.spacing) {
            header
            BarDivider()
            BarButton(icon: .symbol("checkmark"), help: "是", tint: .green) {
                AgentSessionActions.answer(.yes, for: session)
            }
            if AIPresets.keys(for: .always, agent: session.agent) != nil {
                BarButton(icon: .symbol("checkmark.seal"), help: "总是允许（这一项不存在时等于否）", behavior: .confirm) {
                    AgentSessionActions.answer(.always, for: session)
                }
            }
            BarButton(icon: .symbol("xmark"), help: "否") {
                AgentSessionActions.answer(.no, for: session)
            }
            BarDivider()
            BarButton(icon: .symbol("arrow.up.forward.app"), help: "跳到这个会话") {
                AgentSessionActions.jump(to: session)
            }
            BarButton(icon: .symbol("chevron.down"), help: "稍后处理") {
                withAnimation(BarAnimation.morph) { state.dismissedAttentionKey = AttentionKey(session) }
            }
        }
    }

    /// What's waiting, as one centered card the width of the buttons below it.
    private var header: some View {
        let textWidth = metrics.buttonSize + 2 * metrics.scale
        return VStack(spacing: 3 * metrics.scale) {
            Text(tr("待确认"))
                .font(.system(size: metrics.captionSize * 0.9, weight: .bold))
                .foregroundStyle(.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(session.title)
                .font(.system(size: metrics.captionSize * 0.9, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .help(session.cwd ?? session.title)
            if let detail = session.detail {
                Text(detail)
                    .font(.system(size: metrics.captionSize * 0.8, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .help(detail)
            }
        }
        .multilineTextAlignment(.center)
        .frame(width: textWidth)
        .padding(.vertical, 6 * metrics.scale)
        .padding(.horizontal, 2 * metrics.scale)
        .background(
            RoundedRectangle(cornerRadius: metrics.buttonSize * 0.3, style: .continuous)
                .fill(Color.orange.opacity(0.14))
        )
    }
}

/// Every known agent session, most urgent first; tap one to jump to it.
struct AgentSessionsPanel: View {
    @ObservedObject var state: BarState
    @ObservedObject private var monitor = AgentMonitor.shared
    @Environment(\.barMetrics) private var metrics

    private var sessions: [AgentSession] {
        state.agentSessionSample.map { [$0] } ?? monitor.sessions
    }

    var body: some View {
        VStack(spacing: metrics.spacing) {
            BarButton(icon: .symbol("xmark"), help: "关闭") {
                withAnimation(BarAnimation.morph) { state.showSessions = false }
            }
            ScrollingColumn {
                if sessions.isEmpty {
                    Text(tr("没有 AI 会话"))
                        .font(.system(size: metrics.captionSize))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, metrics.spacing * 2)
                }
                ForEach(sessions) { session in
                    Button {
                        AgentSessionActions.jump(to: session)
                    } label: {
                        Text(session.shortLabel)
                            .font(.system(size: metrics.textSize, weight: .semibold, design: .rounded))
                            .frame(width: metrics.buttonSize, height: metrics.buttonSize)
                            .overlay(
                                Circle().strokeBorder(session.status.color, lineWidth: 2.5 * metrics.scale)
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(GlassBarButtonStyle())
                    .help(tr("%@（%@）：%@", session.title, session.agent.title, session.status.title))
                }
            }
        }
    }
}

/// Identifies one permission request, so "later" hides only that request.
struct AttentionKey: Equatable {
    let sessionID: String
    let detail: String?

    init(_ session: AgentSession) {
        sessionID = session.id
        detail = session.detail
    }
}

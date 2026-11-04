import SwiftUI

struct BarRootView: View {
    @ObservedObject var state: BarState
    @ObservedObject private var settings = Settings.shared
    let onSizeChange: (CGSize) -> Void

    private var alignment: Alignment { state.side == .left ? .leading : .trailing }

    private var hiddenOffset: CGFloat {
        let distance = BarMetrics.edgeInset + state.metrics.width + BarMetrics.shadowMargin
        return state.side == .left ? -distance : distance
    }

    var body: some View {
        ZStack(alignment: alignment) {
            EdgeHandle()
                .opacity(state.isExpanded ? 0 : 1)

            BarBody(state: state)
                .glassEffect(
                    settings.glassStyle.glass,
                    in: RoundedRectangle(cornerRadius: state.metrics.cornerRadius, style: .continuous)
                )
                .fixedSize()
                .onGeometryChange(for: CGSize.self) { proxy in
                    proxy.size
                } action: { size in
                    onSizeChange(size)
                }
                .padding(state.side == .left ? .leading : .trailing, BarMetrics.edgeInset)
                .offset(x: state.isExpanded ? 0 : hiddenOffset)
                .scaleEffect(state.isExpanded ? 1 : 0.92, anchor: state.side == .left ? .leading : .trailing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .environment(\.barMetrics, state.metrics)
        .animation(BarAnimation.slide, value: state.isExpanded)
    }
}

/// Small pill on the screen edge while the bar is hidden, hinting where to
/// reach. It takes the color of coding agent status: orange when one waits for
/// you, green when one finished, pulsing blue while one works.
struct EdgeHandle: View {
    @ObservedObject private var agents = AgentMonitor.shared
    @ObservedObject private var settings = Settings.shared
    @Environment(\.barMetrics) private var metrics

    private var status: AgentStatus? { settings.aiEnabled ? agents.attention : nil }

    var body: some View {
        let color = status?.color ?? .white
        let pulses = status == .needsPermission || status == .needsInput
        TimelineView(.animation(minimumInterval: 1 / 20, paused: !pulses)) { context in
            let phase = pulses ? (sin(context.date.timeIntervalSinceReferenceDate * 3) + 1) / 2 : 1
            Capsule()
                .fill(color.opacity(status == nil ? 0.6 : 0.55 + 0.45 * phase))
                .overlay(Capsule().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5))
                .frame(width: status == nil ? 5 : 6, height: metrics.handleHeight)
                .shadow(color: (status == nil ? Color.black : color).opacity(0.35), radius: 3)
                .padding(.horizontal, 2)
        }
    }
}

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

/// Small pill on the screen edge while the bar is hidden, hinting where to reach.
struct EdgeHandle: View {
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.6))
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5))
            .frame(width: 5, height: metrics.handleHeight)
            .shadow(color: .black.opacity(0.25), radius: 3)
            .padding(.horizontal, 2)
    }
}

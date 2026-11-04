import SwiftUI

struct BarRootView: View {
    @ObservedObject var state: BarState
    @ObservedObject private var settings = Settings.shared
    let onSizeChange: (CGSize) -> Void

    private var alignment: Alignment { state.side == .left ? .leading : .trailing }

    private var hiddenOffset: CGFloat {
        let distance = BarMetrics.edgeInset + BarMetrics.width + BarMetrics.shadowMargin
        return state.side == .left ? -distance : distance
    }

    var body: some View {
        ZStack(alignment: alignment) {
            EdgeHandle()
                .opacity(state.isExpanded ? 0 : 1)

            GlassBar(glass: settings.glassStyle.glass, maxHeight: state.maxBarHeight) {
                switch state.content {
                case .controlStrip:
                    ControlStripView(state: state)
                case .appRegion:
                    AppRegionView(state: state)
                case .combined:
                    CombinedBarView(state: state)
                }
            }
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
        .animation(BarAnimation.slide, value: state.isExpanded)
    }
}

/// A floating Liquid Glass capsule. Hugs its content, and scrolls only if the
/// content is taller than the screen allows.
struct GlassBar<Content: View>: View {
    let glass: Glass
    let maxHeight: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: BarMetrics.cornerRadius, style: .continuous)
        ScrollView(.vertical) {
            content
                .padding(.vertical, BarMetrics.innerPadding)
                .frame(width: BarMetrics.width)
        }
        .scrollIndicators(.never)
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: maxHeight)
        .clipShape(shape)
        .glassEffect(glass, in: shape)
    }
}

/// Small pill on the screen edge while the bar is hidden, hinting where to reach.
struct EdgeHandle: View {
    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.6))
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5))
            .frame(width: 5, height: 64)
            .shadow(color: .black.opacity(0.25), radius: 3)
            .padding(.horizontal, 2)
    }
}

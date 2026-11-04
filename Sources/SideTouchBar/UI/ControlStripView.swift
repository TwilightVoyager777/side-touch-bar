import SwiftUI

/// Vertical version of the Touch Bar Control Strip: a compact set of system
/// controls that can expand to the full strip, or turn into a level slider.
struct ControlStripView: View {
    @ObservedObject var state: BarState
    @ObservedObject private var settings = Settings.shared
    @Environment(\.barMetrics) private var metrics

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

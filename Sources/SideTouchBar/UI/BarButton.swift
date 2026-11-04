import SwiftUI

struct BarButton: View {
    let icon: BarIcon
    var help: String = ""
    /// Filled tint for a highlighted/active button (e.g. fn on, warnings).
    var tint: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BarIconView(icon: icon)
                .frame(width: BarMetrics.buttonSize, height: BarMetrics.buttonSize)
                .contentShape(Circle())
        }
        .buttonStyle(GlassBarButtonStyle(tint: tint))
        .help(help)
    }
}

struct BarIconView: View {
    let icon: BarIcon

    var body: some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 17, weight: .medium))
                .symbolRenderingMode(.hierarchical)
        case .text(let text):
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
    }
}

/// Buttons sit on the bar's single glass layer (no glass-on-glass): a faint
/// circular fill that brightens and squishes on press.
struct GlassBarButtonStyle: ButtonStyle {
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .foregroundStyle(tint == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
            .background {
                Circle().fill(fill(pressed: pressed))
            }
            .scaleEffect(pressed ? 0.88 : 1)
            .animation(BarAnimation.press, value: pressed)
    }

    private func fill(pressed: Bool) -> AnyShapeStyle {
        if let tint {
            return AnyShapeStyle(tint.opacity(pressed ? 0.7 : 0.9))
        }
        return AnyShapeStyle(Color.primary.opacity(pressed ? 0.22 : 0.07))
    }
}

struct BarDivider: View {
    var body: some View {
        Capsule()
            .fill(Color.primary.opacity(0.15))
            .frame(width: 24, height: 1.5)
            .padding(.vertical, 3)
    }
}

struct ItemGroupsView: View {
    let groups: [[BarItem]]

    var body: some View {
        VStack(spacing: BarMetrics.spacing) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                if index > 0 { BarDivider() }
                ForEach(group) { item in
                    BarButton(icon: item.icon, help: item.title) {
                        ActionRunner.run(item.action)
                    }
                }
            }
        }
    }
}

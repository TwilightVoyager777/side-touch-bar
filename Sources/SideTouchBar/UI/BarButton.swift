import SwiftUI

struct BarButton: View {
    let icon: BarIcon
    var help: String = ""
    /// Filled tint for a highlighted/active button (e.g. fn on, warnings).
    var tint: Color?
    var behavior: ItemBehavior = .tap
    let action: () -> Void

    @ObservedObject private var settings = Settings.shared
    @Environment(\.barMetrics) private var metrics

    private var effectiveBehavior: ItemBehavior {
        switch behavior {
        case .repeats where !settings.touchRepeat: .tap
        case .confirm where !settings.touchConfirm: .tap
        default: behavior
        }
    }

    var body: some View {
        switch effectiveBehavior {
        case .tap:
            Button(action: action) {
                BarIconView(icon: icon)
                    .frame(width: metrics.buttonSize, height: metrics.buttonSize)
                    .contentShape(Circle())
            }
            .buttonStyle(GlassBarButtonStyle(tint: tint))
            .help(tr(help))
        case .repeats:
            RepeatingButton(icon: icon, help: help, tint: tint, action: action)
        case .confirm:
            HoldToConfirmButton(icon: icon, help: help, tint: tint, action: action)
        }
    }
}

/// Fires on touch, then again and again, faster, while held.
struct RepeatingButton: View {
    let icon: BarIcon
    let help: String
    var tint: Color?
    let action: () -> Void

    @GestureState private var isPressed = false
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        BarIconView(icon: icon)
            .foregroundStyle(tint == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
            .frame(width: metrics.buttonSize, height: metrics.buttonSize)
            .background(Circle().fill(GlassBarButtonStyle.fill(tint: tint, pressed: isPressed)))
            .scaleEffect(isPressed ? 0.88 : 1)
            .animation(BarAnimation.press, value: isPressed)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, pressed, _ in pressed = true }
                    .onChanged { _ in
                        if !Repeater.shared.isActive { Repeater.shared.start(action) }
                    }
                    .onEnded { _ in Repeater.shared.stop() }
            )
            .onChange(of: isPressed) { _, pressed in
                if !pressed { Repeater.shared.stop() }
            }
            .help(tr(help) + tr("（按住连续）"))
    }
}

/// Runs only after a 0.6 second hold, shown by a ring that fills up.
struct HoldToConfirmButton: View {
    let icon: BarIcon
    let help: String
    var tint: Color?
    let action: () -> Void

    static let duration = 0.6

    @GestureState private var isHolding = false
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        BarIconView(icon: icon)
            .foregroundStyle(tint == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
            .frame(width: metrics.buttonSize, height: metrics.buttonSize)
            .background(Circle().fill(GlassBarButtonStyle.fill(tint: tint, pressed: isHolding)))
            .overlay(
                Circle()
                    .trim(from: 0, to: isHolding ? 1 : 0)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 3 * metrics.scale, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(1.5 * metrics.scale)
                    .animation(isHolding ? .linear(duration: Self.duration) : .easeOut(duration: 0.15), value: isHolding)
            )
            .scaleEffect(isHolding ? 0.92 : 1)
            .animation(BarAnimation.press, value: isHolding)
            .contentShape(Circle())
            .gesture(
                LongPressGesture(minimumDuration: Self.duration, maximumDistance: 24)
                    .updating($isHolding) { value, holding, _ in holding = value }
                    .onEnded { _ in action() }
            )
            .help(tr(help) + tr("（长按确认）"))
    }
}

/// Drives repeating buttons; only one can be held at a time.
@MainActor
final class Repeater {
    static let shared = Repeater()

    private var task: Task<Void, Never>?

    var isActive: Bool { task != nil }

    func start(_ action: @escaping () -> Void) {
        stop()
        action()
        task = Task { @MainActor in
            guard (try? await Task.sleep(for: .milliseconds(400))) != nil else { return }
            var interval = 0.12
            while !Task.isCancelled {
                action()
                guard (try? await Task.sleep(for: .seconds(interval))) != nil else { return }
                interval = max(0.045, interval * 0.92)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

struct BarIconView: View {
    let icon: BarIcon

    @Environment(\.barMetrics) private var metrics

    var body: some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: metrics.symbolSize, weight: .medium))
                .symbolRenderingMode(.hierarchical)
        case .text(let text):
            Text(text)
                .font(.system(size: metrics.textSize, weight: .semibold, design: .rounded))
        case .image(let image):
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: metrics.symbolSize * 1.6, height: metrics.symbolSize * 1.6)
        }
    }
}

/// Buttons sit on the bar's single glass layer (no glass-on-glass): a faint
/// circular fill that brightens and squishes on press.
struct GlassBarButtonStyle: ButtonStyle {
    var tint: Color?
    /// Circle by default; text buttons such as quick actions use a rounded square.
    var cornerRadius: CGFloat?

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .foregroundStyle(tint == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
            .background {
                if let cornerRadius {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(fill(pressed: pressed))
                } else {
                    Circle().fill(fill(pressed: pressed))
                }
            }
            .scaleEffect(pressed ? 0.88 : 1)
            .animation(BarAnimation.press, value: pressed)
    }

    private func fill(pressed: Bool) -> AnyShapeStyle {
        Self.fill(tint: tint, pressed: pressed)
    }

    static func fill(tint: Color?, pressed: Bool) -> AnyShapeStyle {
        if let tint {
            return AnyShapeStyle(tint.opacity(pressed ? 0.7 : 0.9))
        }
        return AnyShapeStyle(Color.primary.opacity(pressed ? 0.22 : 0.07))
    }
}

struct BarDivider: View {
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        Capsule()
            .fill(Color.primary.opacity(0.15))
            .frame(width: metrics.dividerWidth, height: 1.5)
            .padding(.vertical, 3 * metrics.scale)
    }
}

struct ItemGroupsView: View {
    let groups: [[BarItem]]
    /// Needed for items that change the bar itself, such as the emoji picker.
    var state: BarState?

    @Environment(\.barMetrics) private var metrics

    var body: some View {
        VStack(spacing: metrics.spacing) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                if index > 0 { BarDivider() }
                ForEach(group) { item in
                    BarButton(icon: item.icon, help: item.title, behavior: item.behavior) {
                        perform(item.action)
                    }
                }
            }
        }
    }

    private func perform(_ action: BarAction) {
        if case .view(let command) = action {
            withAnimation(BarAnimation.morph) { state?.handle(command) }
        } else {
            ActionRunner.run(action)
        }
    }
}

/// A fixed-height, scrolling column of buttons for long lists.
struct ScrollingColumn<Content: View>: View {
    @ViewBuilder var content: Content

    @Environment(\.barMetrics) private var metrics

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: metrics.spacing) {
                content
            }
        }
        .scrollIndicators(.never)
        .frame(width: metrics.width, height: metrics.scrollPageHeight)
    }
}

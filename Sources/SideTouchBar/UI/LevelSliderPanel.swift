import SwiftUI

enum LevelKind: Equatable {
    case brightness, volume, keyboard
}

/// Reads and sets the levels the control strip can slide.
@MainActor
enum LevelControl {
    static func get(_ kind: LevelKind) -> Float? {
        switch kind {
        case .volume: Volume.get()
        case .brightness: Brightness.get()
        case .keyboard: KeyboardBrightness.get()
        }
    }

    static func set(_ kind: LevelKind, _ value: Float) {
        switch kind {
        case .volume: Volume.set(value)
        case .brightness: Brightness.set(value)
        case .keyboard: KeyboardBrightness.set(value)
        }
    }
}

/// Like tapping brightness/volume on the Touch Bar: the strip turns into a slider.
struct LevelSliderPanel: View {
    let kind: LevelKind
    @ObservedObject var state: BarState
    let onClose: () -> Void

    @Environment(\.barMetrics) private var metrics

    var body: some View {
        VStack(spacing: metrics.spacing) {
            BarButton(icon: .symbol("xmark"), help: "关闭", action: onClose)
            BarDivider()

            if state.isLevelAvailable {
                symbol(highSymbol)
                VerticalSlider(value: $state.levelValue) { editing in
                    state.isInteracting = editing
                } onChange: { newValue in
                    apply(newValue)
                }
                symbol(lowSymbol)
                Text("\(Int((state.levelValue * 100).rounded()))")
                    .font(.system(size: metrics.captionSize, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2 * metrics.scale)
            } else {
                // No direct control (e.g. external display): fall back to step buttons.
                BarButton(icon: .symbol(highSymbol), help: "增加") { ActionRunner.run(stepUp) }
                BarButton(icon: .symbol(lowSymbol), help: "减少") { ActionRunner.run(stepDown) }
            }
        }
        .onAppear(perform: load)
    }

    private var highSymbol: String {
        switch kind {
        case .volume: "speaker.wave.3.fill"
        case .brightness: "sun.max.fill"
        case .keyboard: "light.max"
        }
    }

    private var lowSymbol: String {
        switch kind {
        case .volume: "speaker.fill"
        case .brightness: "sun.min.fill"
        case .keyboard: "light.min"
        }
    }

    private var stepUp: SystemCommand {
        switch kind {
        case .volume: .volumeUp
        case .brightness: .brightnessUp
        case .keyboard: .keyboardBrightnessUp
        }
    }

    private var stepDown: SystemCommand {
        switch kind {
        case .volume: .volumeDown
        case .brightness: .brightnessDown
        case .keyboard: .keyboardBrightnessDown
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: metrics.textSize, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(height: 20 * metrics.scale)
    }

    private func load() {
        let current = LevelControl.get(kind)
        state.isLevelAvailable = current != nil
        state.levelValue = Double(current ?? 0.5)
    }

    private func apply(_ newValue: Double) {
        LevelControl.set(kind, Float(newValue))
    }
}

struct VerticalSlider: View {
    @Binding var value: Double
    /// Defaults to the level slider height.
    var height: CGFloat?
    var onEditingChanged: (Bool) -> Void = { _ in }
    var onChange: (Double) -> Void = { _ in }

    @Environment(\.barMetrics) private var metrics

    var body: some View {
        let knob = metrics.knobSize
        let trackWidth = metrics.trackWidth
        GeometryReader { proxy in
            let travel = proxy.size.height - knob
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.primary.opacity(0.14))
                    .frame(width: trackWidth)
                Capsule()
                    .fill(Color.primary.opacity(0.85))
                    .frame(width: trackWidth, height: knob / 2 + travel * value)
                Circle()
                    .fill(Color.white)
                    .frame(width: knob, height: knob)
                    .shadow(color: .black.opacity(0.28), radius: 4, y: 1)
                    .offset(y: -travel * value)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        onEditingChanged(true)
                        let raw = 1 - (gesture.location.y - knob / 2) / max(travel, 1)
                        let clamped = min(max(raw, 0), 1)
                        value = clamped
                        onChange(clamped)
                    }
                    .onEnded { _ in onEditingChanged(false) }
            )
        }
        .frame(width: metrics.buttonSize, height: height ?? metrics.sliderHeight)
    }
}

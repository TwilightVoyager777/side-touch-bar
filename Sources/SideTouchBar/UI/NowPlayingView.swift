import SwiftUI

/// When the app controls turn into playback controls, like the Touch Bar did
/// for videos and music.
@MainActor
enum NowPlayingPresentation {
    static func info(for state: BarState) -> NowPlayingInfo? {
        state.nowPlayingSample ?? NowPlayingStore.shared.info
    }

    /// Shown automatically while the frontmost app is playing (dedicated players
    /// also while paused), or when opened from the control strip.
    static func isShown(state: BarState, frontmost: NSRunningApplication?) -> Bool {
        guard let info = info(for: state) else { return false }
        if let override = state.nowPlayingOverride { return override }
        guard info.belongs(to: frontmost) else { return false }
        let isPlayer = frontmost?.bundleIdentifier.map(MediaApps.players.contains) ?? false
        return info.isPlaying || isPlayer
    }
}

/// Playback controls in one style for every app: title, a scrubber with
/// elapsed/remaining time, transport buttons and system volume.
struct NowPlayingPanel: View {
    @ObservedObject var state: BarState
    let info: NowPlayingInfo
    @ObservedObject private var store = NowPlayingStore.shared
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        VStack(spacing: metrics.spacing) {
            BarButton(
                icon: .symbol(state.nowPlayingOverride == true ? "xmark" : "square.grid.2x2"),
                help: state.nowPlayingOverride == true ? "关闭" : "显示应用按钮"
            ) {
                withAnimation(BarAnimation.morph) { state.nowPlayingOverride = false }
            }

            Text(info.title)
                .font(.system(size: metrics.captionSize, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: metrics.width - 4, height: metrics.captionSize * 2.6)
                .help([info.title, info.artist].compactMap { $0 }.joined(separator: " — "))

            if let duration = info.duration {
                scrubber(duration: duration)
            }

            BarDivider()
            transport
            BarDivider()
            volume
        }
    }

    private func scrubber(duration: Double) -> some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let position = state.isScrubbing ? state.scrubValue * duration : info.position(at: context.date)
            VStack(spacing: 2 * metrics.scale) {
                timeLabel(position)
                VerticalSlider(
                    value: Binding(
                        get: { state.isScrubbing ? state.scrubValue : position / duration },
                        set: { state.scrubValue = $0 }
                    ),
                    height: metrics.progressHeight
                ) { editing in
                    if editing, !state.isScrubbing {
                        state.isScrubbing = true
                        state.isInteracting = true
                    } else if !editing {
                        store.seek(to: state.scrubValue * duration)
                        state.isScrubbing = false
                        state.isInteracting = false
                    }
                }
                timeLabel(duration - position, prefix: "-")
            }
        }
    }

    @ViewBuilder
    private var transport: some View {
        if info.isMusic {
            BarButton(icon: .symbol("backward.fill"), help: "上一首") { store.previousTrack() }
        } else {
            BarButton(icon: .symbol("gobackward.15"), help: "后退 15 秒") { store.skip(by: -15) }
        }
        BarButton(icon: .symbol(info.isPlaying ? "pause.fill" : "play.fill"), help: info.isPlaying ? "暂停" : "播放") {
            store.togglePlayPause()
        }
        if info.isMusic {
            BarButton(icon: .symbol("forward.fill"), help: "下一首") { store.nextTrack() }
        } else {
            BarButton(icon: .symbol("goforward.15"), help: "前进 15 秒") { store.skip(by: 15) }
        }
    }

    private var volume: some View {
        VStack(spacing: 2 * metrics.scale) {
            VerticalSlider(
                value: Binding(
                    get: { Double(store.systemVolume ?? 0.5) },
                    set: { store.setVolume(Float($0)) }
                ),
                height: metrics.volumeHeight
            ) { editing in
                state.isInteracting = editing
            }
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: metrics.captionSize, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(height: metrics.captionSize * 1.6)
        }
    }

    private func timeLabel(_ seconds: Double, prefix: String = "") -> some View {
        Text(prefix + Self.format(seconds))
            .font(.system(size: metrics.captionSize * 0.9, weight: .medium, design: .rounded).monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: metrics.width - 4)
    }

    private static func format(_ seconds: Double) -> String {
        let total = Int(max(seconds, 0).rounded(.down))
        let hours = total / 3600
        let minutes = total / 60 % 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}

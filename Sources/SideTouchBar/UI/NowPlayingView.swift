import Carbon.HIToolbox
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
/// elapsed/remaining time, transport buttons and system volume, plus a
/// "more" page and an audio output page.
struct NowPlayingPanel: View {
    @ObservedObject var state: BarState
    let info: NowPlayingInfo
    @ObservedObject private var store = NowPlayingStore.shared
    @ObservedObject private var settings = Settings.shared
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        Group {
            switch state.nowPlayingPage {
            case .main: main
            case .more: NowPlayingMorePanel(state: state, info: info)
            case .outputs: AudioOutputsPanel(state: state)
            }
        }
        .transition(.blurReplace)
        .animation(BarAnimation.morph, value: state.nowPlayingPage)
    }

    private var main: some View {
        VStack(spacing: metrics.spacing) {
            BarButton(
                icon: store.artwork.map(BarIcon.image) ?? .symbol(state.nowPlayingOverride == true ? "xmark" : "square.grid.2x2"),
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
            BarButton(icon: .symbol("ellipsis"), help: "更多：倍速、全屏、字幕…") {
                state.handle(.mediaMore)
            }
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

    private var skipSeconds: Int { Int(settings.mediaSkipSeconds) }

    @ViewBuilder
    private var transport: some View {
        if info.isMusic {
            BarButton(icon: .symbol("backward.fill"), help: "上一首") { store.previousTrack() }
        } else {
            BarButton(icon: .symbol("gobackward.\(skipSeconds)"), help: tr("后退 %d 秒", skipSeconds), behavior: .repeats) { store.skip(by: -Double(skipSeconds)) }
        }
        BarButton(icon: .symbol(info.isPlaying ? "pause.fill" : "play.fill"), help: info.isPlaying ? "暂停" : "播放") {
            store.togglePlayPause()
        }
        if info.isMusic {
            BarButton(icon: .symbol("forward.fill"), help: "下一首") { store.nextTrack() }
        } else {
            BarButton(icon: .symbol("goforward.\(skipSeconds)"), help: tr("前进 %d 秒", skipSeconds), behavior: .repeats) { store.skip(by: Double(skipSeconds)) }
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
            Button {
                state.handle(.audioOutputs)
            } label: {
                Image(systemName: "airplayaudio")
                    .font(.system(size: metrics.captionSize * 1.2, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: metrics.buttonSize, height: metrics.captionSize * 2.2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("切换音频输出")
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

/// Speed, picture options and shuffle/repeat for the current media.
struct NowPlayingMorePanel: View {
    @ObservedObject var state: BarState
    let info: NowPlayingInfo
    @ObservedObject private var store = NowPlayingStore.shared
    @Environment(\.barMetrics) private var metrics

    private static let rates: [Double] = [0.5, 1, 1.25, 1.5, 2]

    var body: some View {
        VStack(spacing: metrics.spacing) {
            BarButton(icon: .symbol("chevron.left"), help: "返回") { state.nowPlayingPage = .main }
            BarDivider()
            ForEach(Self.rates, id: \.self) { rate in
                TextButton(title: Self.label(rate), help: "\(Self.label(rate)) 倍速", tint: abs(info.rate - rate) < 0.01 && info.isPlaying ? .accentColor : nil) {
                    store.setRate(rate)
                }
            }
            BarDivider()
            if info.isMusic {
                BarButton(icon: .symbol("shuffle"), help: "随机播放", tint: (info.shuffleMode ?? 1) != 1 ? .accentColor : nil) {
                    store.toggleShuffle()
                }
                BarButton(icon: .symbol(info.repeatMode == 2 ? "repeat.1" : "repeat"), help: "循环", tint: (info.repeatMode ?? 1) != 1 ? .accentColor : nil) {
                    store.cycleRepeat()
                }
                BarButton(icon: .symbol("heart"), help: "喜欢") { store.like() }
            } else {
                BarButton(icon: .symbol("arrow.up.left.and.arrow.down.right"), help: "全屏") { MediaActions.fullScreen(for: info) }
                BarButton(icon: .symbol("pip.enter"), help: "画中画") { MediaActions.pictureInPicture(for: info) }
                BarButton(icon: .symbol("captions.bubble"), help: "字幕") { MediaActions.subtitles(for: info) }
            }
            BarDivider()
            BarButton(icon: .symbol("airplayaudio"), help: "切换音频输出") { state.handle(.audioOutputs) }
        }
    }

    private static func label(_ rate: Double) -> String {
        rate == rate.rounded() ? "\(Int(rate))×" : "\(rate)×"
    }
}

/// Pick the audio output: speakers, headphones, AirPods, displays, AirPlay.
struct AudioOutputsPanel: View {
    @ObservedObject var state: BarState
    @ObservedObject private var outputs = AudioOutputsStore.shared
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        VStack(spacing: metrics.spacing) {
            BarButton(icon: .symbol("chevron.left"), help: "返回") { state.nowPlayingPage = .main }
            ScrollingColumn {
                ForEach(outputs.devices) { device in
                    TextButton(title: device.name, help: device.name, tint: device.isDefault ? .accentColor : nil) {
                        outputs.select(device)
                    }
                }
            }
        }
        .onAppear { outputs.refresh() }
    }
}

/// Picture and subtitle actions, sent to the playing app: browsers get the
/// common web player keys, native players get their menu items.
@MainActor
enum MediaActions {
    private static func perform(for info: NowPlayingInfo, _ action: @escaping @MainActor (_ isBrowser: Bool) -> Void) {
        let app = info.app
        let isBrowser = AppPresets.browser.bundleIDs.contains(app?.bundleIdentifier ?? "")
        if let app, FrontmostAppMonitor.shared.app?.processIdentifier != app.processIdentifier {
            app.activate()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                action(isBrowser)
            }
        } else {
            action(isBrowser)
        }
    }

    static func fullScreen(for info: NowPlayingInfo) {
        perform(for: info) { isBrowser in
            if isBrowser {
                ActionRunner.run(.keys(KeyCombo(kVK_ANSI_F)))
            } else {
                ActionRunner.run(.menuSearch(["Enter Full Screen", "Exit Full Screen", "Toggle Full Screen", "进入全屏", "退出全屏"], fallback: KeyCombo(kVK_ANSI_F, [.maskCommand, .maskControl])))
            }
        }
    }

    static func pictureInPicture(for info: NowPlayingInfo) {
        perform(for: info) { _ in
            ActionRunner.run(.menuSearch(["Picture in Picture", "画中画"], fallback: nil))
        }
    }

    static func subtitles(for info: NowPlayingInfo) {
        perform(for: info) { isBrowser in
            if isBrowser {
                ActionRunner.run(.keys(KeyCombo(kVK_ANSI_C)))
            } else {
                ActionRunner.run(.menuSearch(["Show Subtitles", "Hide Subtitles", "Subtitles", "显示字幕", "隐藏字幕", "字幕"], fallback: nil))
            }
        }
    }
}

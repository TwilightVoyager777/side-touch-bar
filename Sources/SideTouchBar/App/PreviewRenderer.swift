import AppKit
import SwiftUI

/// `SideTouchBar --render-previews <directory>`: renders README images from
/// the real bar views, in English (preview-light.jpg) and Chinese
/// (preview-light.zh.jpg), light and dark. Liquid Glass can't be captured
/// offscreen, so the glass is approximated with a translucent fill.
@MainActor
enum PreviewRenderer {
    static func run(to directory: String) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let defaults = UserDefaults.standard
        let previousLanguage = defaults.string(forKey: L10n.languageKey)
        defer { defaults.set(previousLanguage, forKey: L10n.languageKey) }

        for (language, suffix) in [(AppLanguage.english, ""), (.chinese, ".zh")] {
            defaults.set(language.rawValue, forKey: L10n.languageKey)
            for scheme in [ColorScheme.light, .dark] {
                render(scheme: scheme, to: directory, name: "preview-\(scheme == .light ? "light" : "dark")\(suffix).jpg")
            }
        }
    }

    private static func render(scheme: ColorScheme, to directory: String, name: String) {
        let image = ImageRenderer(content: PreviewSheet().environment(\.colorScheme, scheme))
        image.scale = 1.2
        guard let tiff = image.nsImage?.tiffRepresentation,
              let jpeg = NSBitmapImageRep(data: tiff)?.representation(using: .jpeg, properties: [.compressionFactor: 0.88]) else { return }
        let url = URL(fileURLWithPath: directory).appendingPathComponent(name)
        try? jpeg.write(to: url)
        print("Wrote \(url.path)")
    }

    static func states() -> [(String, BarState)] {
        func make(_ configure: (BarState) -> Void) -> BarState {
            let state = BarState(side: .right)
            state.pageOverride = .appControlsWithStrip
            configure(state)
            return state
        }

        let finder = make { $0.presetOverride = AppPresets.finder }
        let debug = make {
            $0.presetOverride = IDEPresets.vscode
            $0.presetPageIndex = IDEPresets.vscode.pages.firstIndex { $0.id == "debug" } ?? 0
        }
        let playback = make {
            $0.nowPlayingSample = NowPlayingInfo(
                title: tr("设计评审：液态玻璃"), artist: nil, duration: 1_860, elapsed: 742, rate: 1,
                timestamp: Date(), isPlaying: true, pid: nil, bundleID: nil, parentBundleID: nil,
                shuffleMode: nil, repeatMode: nil
            )
            $0.nowPlayingOverride = true
        }
        let approval = make {
            $0.agentSessionSample = AgentSession(
                id: "preview", agent: .claude, status: .needsPermission,
                cwd: "/Users/me/side-touch-bar", detail: "npm run test"
            )
        }
        return [
            (tr("访达"), finder), (tr("VS Code · 调试"), debug),
            (tr("正在播放"), playback), (tr("Claude Code · 确认"), approval),
        ]
    }
}

private struct PreviewSheet: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            ForEach(Array(PreviewRenderer.states().enumerated()), id: \.offset) { _, entry in
                VStack(spacing: 18) {
                    Text(entry.0)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    PreviewBar(state: entry.1)
                }
            }
        }
        .padding(.horizontal, 64)
        .padding(.vertical, 48)
        .background(
            LinearGradient(
                colors: scheme == .light
                    ? [Color(red: 0.36, green: 0.55, blue: 0.97), Color(red: 0.63, green: 0.42, blue: 0.93), Color(red: 0.98, green: 0.62, blue: 0.48)]
                    : [Color(red: 0.07, green: 0.10, blue: 0.24), Color(red: 0.25, green: 0.12, blue: 0.38), Color(red: 0.48, green: 0.20, blue: 0.30)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct PreviewBar: View {
    @ObservedObject var state: BarState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let metrics = BarMetrics.standard
        let shape = RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
        BarBody(state: state)
            .environment(\.barMetrics, metrics)
            .fixedSize()
            .background(shape.fill(scheme == .light ? Color.white.opacity(0.62) : Color.black.opacity(0.42)))
            .overlay(shape.strokeBorder(Color.white.opacity(scheme == .light ? 0.75 : 0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
    }
}

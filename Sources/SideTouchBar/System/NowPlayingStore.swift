import AppKit
import Combine

struct NowPlayingInfo: Equatable {
    var title: String
    var artist: String?
    /// nil for live streams or when the player doesn't report it.
    var duration: Double?
    var elapsed: Double
    var rate: Double
    /// When `elapsed` was measured.
    var timestamp: Date
    var isPlaying: Bool
    var pid: pid_t?
    var bundleID: String?
    /// Set when media plays through a helper process, e.g. Safari's WebKit.
    var parentBundleID: String?
    /// MediaRemote modes: shuffle 1 off, 3 on; repeat 1 off, 2 one, 3 all.
    var shuffleMode: Int?
    var repeatMode: Int?

    static let sample = NowPlayingInfo(
        title: "示例标题，可能有两行", artist: nil, duration: 200, elapsed: 50, rate: 1,
        timestamp: Date(), isPlaying: true, pid: nil, bundleID: nil, parentBundleID: nil,
        shuffleMode: nil, repeatMode: nil
    )

    func position(at date: Date) -> Double {
        var position = elapsed
        if isPlaying {
            position += date.timeIntervalSince(timestamp) * (rate > 0 ? rate : 1)
        }
        if let duration { position = min(position, duration) }
        return max(position, 0)
    }

    var app: NSRunningApplication? {
        if let parentBundleID, let parent = NSRunningApplication.runningApplications(withBundleIdentifier: parentBundleID).first {
            return parent
        }
        return pid.flatMap { NSRunningApplication(processIdentifier: $0) }
    }

    func belongs(to app: NSRunningApplication?) -> Bool {
        guard let app else { return false }
        if app.processIdentifier == pid { return true }
        guard let id = app.bundleIdentifier else { return false }
        return id == bundleID || id == parentBundleID
    }

    /// Music players get previous/next track; everything else ±15 seconds.
    var isMusic: Bool {
        [bundleID, parentBundleID].contains { $0.map(MediaApps.music.contains) ?? false }
    }
}

enum MediaApps {
    static let music: Set<String> = [
        "com.apple.Music", "com.spotify.client", "com.netease.163music", "com.tencent.QQMusicMac", "com.kugou.mac",
    ]

    /// Dedicated players show the playback controls even while paused.
    static let players: Set<String> = music.union([
        "com.apple.podcasts", "com.apple.TV", "com.apple.QuickTimePlayerX",
        "com.colliderli.iina", "org.videolan.vlc", "io.mpv", "com.firecore.infuse",
    ])
}

/// Now Playing information for the playback controls, like the Touch Bar's.
///
/// Reading uses a helper library hosted in /usr/bin/perl, because MediaRemote
/// only answers Apple-signed processes since macOS 15.4 (see
/// Helpers/NowPlayingHelper.m). Commands are sent directly.
@MainActor
final class NowPlayingStore: ObservableObject {
    static let shared = NowPlayingStore()

    @Published private(set) var info: NowPlayingInfo?
    @Published private(set) var systemVolume: Float?
    @Published private(set) var artwork: NSImage?

    private var artworkKey: Int?

    private var process: Process?
    private var stdinPipe: Pipe?
    private var buffer = Data()
    private var restarts: [Date] = []
    private var volumeTimer: Timer?
    private var volumeCancellable: AnyCancellable?

    private typealias SendCommandFunction = @convention(c) (UInt32, CFDictionary?) -> Bool
    private typealias SetElapsedTimeFunction = @convention(c) (Double) -> Void

    private static let mediaRemote = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY)

    private static let sendCommandFunction: SendCommandFunction? = {
        guard let mediaRemote, let symbol = dlsym(mediaRemote, "MRMediaRemoteSendCommand") else { return nil }
        return unsafeBitCast(symbol, to: SendCommandFunction.self)
    }()

    private static let setElapsedTimeFunction: SetElapsedTimeFunction? = {
        guard let mediaRemote, let symbol = dlsym(mediaRemote, "MRMediaRemoteSetElapsedTime") else { return nil }
        return unsafeBitCast(symbol, to: SetElapsedTimeFunction.self)
    }()

    private static let loaderScript = """
    use DynaLoader;
    my $lib = DynaLoader::dl_load_file($ARGV[0], 0) or die DynaLoader::dl_error();
    my $symbol = DynaLoader::dl_find_symbol($lib, "stb_stream") or die "missing stb_stream";
    my $stream = DynaLoader::dl_install_xsub("main::stream", $symbol);
    &$stream;
    """

    private var helperURL: URL? {
        Bundle.main.url(forResource: "libNowPlayingHelper", withExtension: "dylib")
    }

    // MARK: - Helper process

    func start() {
        guard process == nil, let helperURL else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = ["-e", Self.loaderScript, helperURL.path]
        let output = Pipe()
        let input = Pipe()
        process.standardOutput = output
        process.standardInput = input
        process.standardError = FileHandle.nullDevice

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            Task { @MainActor in self?.receive(data) }
        }
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in self?.helperExited() }
        }

        do {
            try process.run()
        } catch {
            return
        }
        self.process = process
        stdinPipe = input
        startVolumePolling()
    }

    func stop() {
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
        stdinPipe = nil
    }

    private func helperExited() {
        process = nil
        stdinPipe = nil
        info = nil
        let now = Date()
        restarts = restarts.filter { now.timeIntervalSince($0) < 60 } + [now]
        guard restarts.count <= 5 else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            self.start()
        }
    }

    private func receive(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            parse(Data(line))
        }
    }

    private func parse(_ line: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { return }
        guard (json["active"] as? Bool) == true, let title = json["title"] as? String else {
            if info != nil { info = nil }
            setArtwork(nil)
            return
        }
        setArtwork(json["artwork"] as? String)
        let duration = (json["duration"] as? Double).flatMap { $0 > 0 ? $0 : nil }
        let newInfo = NowPlayingInfo(
            title: title,
            artist: json["artist"] as? String,
            duration: duration,
            elapsed: json["elapsed"] as? Double ?? 0,
            rate: json["rate"] as? Double ?? 0,
            timestamp: (json["timestamp"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date(),
            isPlaying: json["playing"] as? Bool ?? false,
            pid: (json["pid"] as? Int).map { pid_t($0) },
            bundleID: json["bundle"] as? String,
            parentBundleID: json["parentBundle"] as? String,
            shuffleMode: json["shuffle"] as? Int,
            repeatMode: json["repeat"] as? Int
        )
        if newInfo != info { info = newInfo }
    }

    // MARK: - Commands

    func togglePlayPause() {
        send(2)
        guard var current = info else { return }
        current.elapsed = current.position(at: Date())
        current.timestamp = Date()
        current.isPlaying.toggle()
        info = current
    }

    func nextTrack() { send(4) }

    func previousTrack() { send(5) }

    func seek(to seconds: Double) {
        guard var current = info else { return }
        let target = max(0, current.duration.map { min(seconds, $0) } ?? seconds)
        Self.setElapsedTimeFunction?(target)
        current.elapsed = target
        current.timestamp = Date()
        info = current
    }

    func skip(by delta: Double) {
        guard let info else { return }
        seek(to: info.position(at: Date()) + delta)
    }

    func setRate(_ rate: Double) {
        send(19, options: ["kMRMediaRemoteOptionPlaybackRate": rate])
        guard var current = info else { return }
        current.elapsed = current.position(at: Date())
        current.timestamp = Date()
        current.rate = rate
        info = current
    }

    func toggleShuffle() {
        let isOn = (info?.shuffleMode ?? 1) != 1
        send(26, options: ["kMRMediaRemoteOptionShuffleMode": isOn ? 1 : 3])
        info?.shuffleMode = isOn ? 1 : 3
    }

    /// Off → all → one → off, like the Music app.
    func cycleRepeat() {
        let next = switch info?.repeatMode ?? 1 {
        case 1: 3
        case 3: 2
        default: 1
        }
        send(25, options: ["kMRMediaRemoteOptionRepeatMode": next])
        info?.repeatMode = next
    }

    func like() { send(21) }

    func setVolume(_ value: Float) {
        Volume.set(value)
        systemVolume = value
    }

    private func send(_ command: UInt32, options: [String: Any]? = nil) {
        _ = Self.sendCommandFunction?(command, options as CFDictionary?)
    }

    private func setArtwork(_ base64: String?) {
        let key = base64.map { $0.count ^ $0.prefix(64).hashValue ^ $0.suffix(64).hashValue }
        guard key != artworkKey else { return }
        artworkKey = key
        artwork = base64.flatMap { Data(base64Encoded: $0) }.flatMap(NSImage.init(data:))
    }

    /// The volume slider is only visible while the bar is out, so only poll then.
    private func startVolumePolling() {
        guard volumeCancellable == nil else { return }
        volumeCancellable = BarActivity.shared.$isExpanded
            .removeDuplicates()
            .sink { [weak self] expanded in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.volumeTimer?.invalidate()
                    self.volumeTimer = nil
                    guard expanded else { return }
                    self.refreshVolume()
                    self.volumeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                        MainActor.assumeIsolated { self?.refreshVolume() }
                    }
                }
            }
    }

    private func refreshVolume() {
        let volume = Volume.get()
        if let volume, let current = systemVolume, abs(volume - current) < 0.005 { return }
        systemVolume = volume
    }
}

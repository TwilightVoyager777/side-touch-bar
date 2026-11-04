import AVFoundation
import Speech

/// Hold-to-talk dictation for prompts: records while the button is held, then
/// types the transcript into the frontmost app. Uses on-device recognition when available.
@MainActor
final class VoiceInput: ObservableObject {
    static let shared = VoiceInput()

    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""
    @Published private(set) var errorMessage: String?

    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func begin() {
        guard !isListening else { return }
        isListening = true
        transcript = ""
        errorMessage = nil
        Task { @MainActor in
            guard await Self.authorize() else {
                errorMessage = "需要麦克风和语音识别权限"
                isListening = false
                return
            }
            // Released before permission came back.
            guard isListening else { return }
            startRecording()
        }
    }

    func end() {
        guard isListening else { return }
        isListening = false
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
        request?.endAudio()
        Task { @MainActor in
            // Give the recognizer a moment to deliver the final words.
            try? await Task.sleep(for: .milliseconds(700))
            let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            task?.cancel()
            task = nil
            request = nil
            if !text.isEmpty { TextInserter.insert(text) }
        }
    }

    private func startRecording() {
        let locale = Settings.shared.voiceLanguage.locale
        guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(), recognizer.isAvailable else {
            errorMessage = "语音识别不可用"
            isListening = false
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            errorMessage = "无法打开麦克风"
            isListening = false
            input.removeTap(onBus: 0)
            return
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let text = result?.bestTranscription.formattedString else { return }
            Task { @MainActor in self?.transcript = text }
        }
        self.engine = engine
        self.request = request
    }

    private static func authorize() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVCaptureDevice.requestAccess(for: .audio)
    }
}

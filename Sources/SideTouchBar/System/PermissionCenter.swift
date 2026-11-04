import AppKit
import AVFoundation
import ServiceManagement
import Speech

/// Status of every permission the app can use, plus launch at login and
/// signing, for the setup checklist.
@MainActor
final class PermissionCenter: ObservableObject {
    static let shared = PermissionCenter()

    enum Status {
        case granted, denied, notAsked

        var isGranted: Bool { self == .granted }
    }

    @Published private(set) var microphone: Status = .notAsked
    @Published private(set) var speech: Status = .notAsked
    @Published private(set) var screenRecording: Status = .notAsked
    @Published private(set) var launchAtLogin = false
    @Published private(set) var launchAtLoginNeedsApproval = false
    /// False when ad-hoc signed: permissions may reset after each rebuild.
    @Published private(set) var hasStableSignature = false

    private var timer: Timer?

    /// Refreshes while the settings window shows the checklist.
    func startWatching() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stopWatching() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        Permissions.shared.refresh()
        microphone = switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .granted
        case .notDetermined: .notAsked
        default: .denied
        }
        speech = switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: .granted
        case .notDetermined: .notAsked
        default: .denied
        }
        screenRecording = CGPreflightScreenCaptureAccess() ? .granted : .notAsked
        let service = SMAppService.mainApp
        launchAtLogin = service.status == .enabled
        launchAtLoginNeedsApproval = service.status == .requiresApproval
        hasStableSignature = Self.isSignedWithCertificate()
    }

    // MARK: - Requests

    func requestMicrophone() {
        if microphone == .denied { return Self.openPrivacy("Privacy_Microphone") }
        AVCaptureDevice.requestAccess(for: .audio) { _ in
            Task { @MainActor in PermissionCenter.shared.refresh() }
        }
    }

    func requestSpeech() {
        if speech == .denied { return Self.openPrivacy("Privacy_SpeechRecognition") }
        SFSpeechRecognizer.requestAuthorization { _ in
            Task { @MainActor in PermissionCenter.shared.refresh() }
        }
    }

    func requestScreenRecording() {
        if !CGRequestScreenCaptureAccess() { Self.openPrivacy("Privacy_ScreenCapture") }
        refresh()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            showError(error)
        }
        if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        refresh()
    }

    static func openPrivacy(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func isSignedWithCertificate() -> Bool {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return false }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return false }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dictionary = info as? [String: Any] else { return false }
        return !((dictionary[kSecCodeInfoCertificates as String] as? [Any]) ?? []).isEmpty
    }
}

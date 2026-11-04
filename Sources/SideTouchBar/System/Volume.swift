import CoreAudio

/// Reads and writes the default output device volume via CoreAudio.
enum Volume {
    /// kAudioHardwareServiceDeviceProperty_VirtualMainVolume ('vmvc')
    private static let virtualMainVolume: AudioObjectPropertySelector = 0x766D_7663

    static func get() -> Float? {
        guard let device = outputDevice() else { return nil }
        var address = outputAddress(virtualMainVolume)
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    static func set(_ value: Float) {
        guard let device = outputDevice() else { return }
        var address = outputAddress(virtualMainVolume)
        guard isSettable(device, &address) else { return }
        var newValue = Float32(min(max(value, 0), 1))
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &newValue)
        if newValue > 0, isMuted == true {
            setMuted(false)
        }
    }

    static func step(_ delta: Float) {
        guard let current = get() else { return }
        set(current + delta)
    }

    static var isMuted: Bool? {
        guard let device = outputDevice() else { return nil }
        var address = outputAddress(kAudioDevicePropertyMute)
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value != 0
    }

    static func setMuted(_ muted: Bool) {
        guard let device = outputDevice() else { return }
        var address = outputAddress(kAudioDevicePropertyMute)
        guard isSettable(device, &address) else { return }
        var value = UInt32(muted ? 1 : 0)
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }

    static func toggleMute() {
        setMuted(!(isMuted ?? false))
    }

    // MARK: - Helpers

    private static func outputDevice() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return status == noErr && device != 0 ? device : nil
    }

    private static func outputAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func isSettable(_ device: AudioDeviceID, _ address: inout AudioObjectPropertyAddress) -> Bool {
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }
}

import AppKit

/// NX_KEYTYPE_* values from IOKit/hidsystem/ev_keymap.h
enum MediaKey: Int32 {
    case soundUp = 0
    case soundDown = 1
    case brightnessUp = 2
    case brightnessDown = 3
    case mute = 7
    case play = 16
    case next = 17
    case previous = 18
    case illuminationUp = 21
    case illuminationDown = 22
}

/// Simulates the hardware media keys, so macOS shows its own volume/brightness HUD
/// and the current Now Playing app receives play/pause. Requires Accessibility permission.
enum MediaKeySender {
    static func send(_ key: MediaKey) {
        post(key, down: true)
        post(key, down: false)
    }

    private static func post(_ key: MediaKey, down: Bool) {
        let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
        let data1 = Int((key.rawValue << 16) | ((down ? 0xA : 0xB) << 8))
        let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        )
        event?.cgEvent?.post(tap: .cghidEventTap)
    }
}

import Carbon.HIToolbox
import CoreGraphics

struct KeyCombo {
    let key: CGKeyCode
    let flags: CGEventFlags

    init(_ key: Int, _ flags: CGEventFlags = []) {
        self.key = CGKeyCode(key)
        self.flags = flags
    }
}

/// Sends keyboard shortcuts to the frontmost app. Requires Accessibility permission.
enum KeySender {
    private static let arrowKeys: Set<Int> = [kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow]

    static func send(_ combo: KeyCombo) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: combo.key, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: combo.key, keyDown: false)
        else { return }

        var flags = combo.flags
        if arrowKeys.contains(Int(combo.key)) {
            flags.formUnion([.maskNumericPad, .maskSecondaryFn])
        }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// Types arbitrary text (such as an emoji) into the focused app.
    static func type(_ text: String) {
        let units = Array(text.utf16)
        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return }
        down.flags = []
        up.flags = []
        down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

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
}

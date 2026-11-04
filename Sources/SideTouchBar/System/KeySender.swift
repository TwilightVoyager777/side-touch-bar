import Carbon.HIToolbox
import CoreGraphics

struct KeyCombo: Codable, Hashable {
    let key: CGKeyCode
    let flags: CGEventFlags

    init(_ key: Int, _ flags: CGEventFlags = []) {
        self.key = CGKeyCode(key)
        self.flags = flags
    }

    init(key: CGKeyCode, flags: CGEventFlags) {
        self.key = key
        self.flags = flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
    }

    private enum CodingKeys: String, CodingKey { case key, flags }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(CGKeyCode.self, forKey: .key)
        flags = CGEventFlags(rawValue: try container.decode(UInt64.self, forKey: .flags))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(flags.rawValue, forKey: .flags)
    }

    static func == (lhs: KeyCombo, rhs: KeyCombo) -> Bool {
        lhs.key == rhs.key && lhs.flags.rawValue == rhs.flags.rawValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(flags.rawValue)
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

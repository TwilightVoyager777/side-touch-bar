import AppKit
import Carbon.HIToolbox

/// Puts text into the focused app, by typing short text and pasting long text.
@MainActor
enum TextInserter {
    /// Unicode keyboard events reliably carry only about 20 UTF-16 units each.
    private static let chunkSize = 16

    static func insert(_ text: String, submit: Bool = false, pasteCombo: KeyCombo = KeyCombo(kVK_ANSI_V, .maskCommand)) {
        guard Permissions.shared.requestIfNeeded(), !text.isEmpty else { return }
        let delay: Duration
        if text.utf16.count > 120 || text.contains("\n") {
            paste(text, combo: pasteCombo)
            delay = .milliseconds(250)
        } else {
            type(text)
            delay = .milliseconds(80)
        }
        guard submit else { return }
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            KeySender.send(KeyCombo(kVK_Return))
        }
    }

    static func type(_ text: String) {
        var units = Array(text.utf16)
        while !units.isEmpty {
            var count = min(chunkSize, units.count)
            // Don't split a surrogate pair (e.g. emoji).
            if count < units.count, UTF16.isLeadSurrogate(units[count - 1]) { count -= 1 }
            let chunk = String(decoding: units[0..<count], as: UTF16.self)
            KeySender.type(chunk)
            units.removeFirst(count)
        }
    }

    /// Pastes through the clipboard, then restores what was there.
    static func paste(_ text: String, combo: KeyCombo = KeyCombo(kVK_ANSI_V, .maskCommand)) {
        let saved = ClipboardSnapshot.take()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        KeySender.send(combo)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            saved.restore()
        }
    }
}

/// A copy of everything on the general pasteboard, to put back later.
struct ClipboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]
    let changeCount: Int

    @MainActor
    static func take() -> ClipboardSnapshot {
        let pasteboard = NSPasteboard.general
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
        return ClipboardSnapshot(items: items, changeCount: pasteboard.changeCount)
    }

    @MainActor
    func restore() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let restored = items.map { entries -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entries { item.setData(data, forType: type) }
            return item
        }
        if !restored.isEmpty { pasteboard.writeObjects(restored) }
    }
}

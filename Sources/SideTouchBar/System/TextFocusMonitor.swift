import AppKit

/// Whether the focused element of the frontmost app is an editable text
/// field, so the text editing page can come forward while typing.
@MainActor
final class TextFocusMonitor: ObservableObject {
    static let shared = TextFocusMonitor()

    @Published private(set) var isEditingText = false

    private static let editableRoles: Set<String> = [
        kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole, "AXSearchField",
    ]

    private var timer: Timer?

    /// Polls only while the bar is out and the app has an automatic text page.
    func setActive(_ active: Bool) {
        if active, timer == nil {
            poll()
            timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.poll() }
            }
        } else if !active {
            timer?.invalidate()
            timer = nil
        }
    }

    func poll() {
        let app = FrontmostAppMonitor.shared.app
        let preset = PresetResolver.preset(for: app, context: AIContextMonitor.shared.context)
        guard Settings.shared.touchAutoTextPage, Permissions.shared.isTrusted, let app,
              preset.pages.contains(where: \.activatesOnTextFocus) else {
            if isEditingText { isEditingText = false }
            return
        }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var focused: CFTypeRef?
        var editing = false
        if AXUIElementCopyAttributeValue(element, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
           let focused {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXRoleAttribute as CFString, &role)
            editing = (role as? String).map(Self.editableRoles.contains) ?? false
        }
        if editing != isEditingText { isEditingText = editing }
    }
}

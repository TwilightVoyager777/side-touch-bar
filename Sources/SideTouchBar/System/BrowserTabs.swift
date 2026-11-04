import AppKit

/// The open tabs of the frontmost browser window, read from its tab bar
/// through Accessibility (like the Touch Bar's tab scrubber in Safari).
@MainActor
final class BrowserTabsStore: ObservableObject {
    static let shared = BrowserTabsStore()

    struct Tab: Identifiable, Equatable {
        let id: Int
        let title: String
        let isSelected: Bool
    }

    @Published private(set) var tabs: [Tab] = []

    private var elements: [AXUIElement] = []
    private var tabGroup: AXUIElement?
    private var groupPID: pid_t?
    private var timer: Timer?
    private var viewers = 0

    /// Polls while a tab list is on screen.
    func startWatching() {
        viewers += 1
        refresh()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stopWatching() {
        viewers = max(0, viewers - 1)
        guard viewers == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    func select(_ tab: Tab) {
        guard tab.id < elements.count else { return }
        AXUIElementPerformAction(elements[tab.id], kAXPressAction as CFString)
        refresh()
    }

    func refresh() {
        guard let app = FrontmostAppMonitor.shared.app, Permissions.shared.isTrusted else {
            update([], [])
            return
        }
        if groupPID != app.processIdentifier || tabGroup.map(Self.children)?.isEmpty ?? true {
            tabGroup = Self.findTabGroup(in: app)
            groupPID = app.processIdentifier
        }
        guard let tabGroup else {
            update([], [])
            return
        }
        let buttons = Self.children(tabGroup).filter {
            let role = Self.string($0, kAXRoleAttribute)
            return role == kAXRadioButtonRole || Self.string($0, kAXSubroleAttribute) == "AXTabButton"
        }
        let tabs = buttons.enumerated().map { index, element in
            Tab(id: index, title: Self.cleanTitle(Self.string(element, kAXTitleAttribute) ?? ""),
                isSelected: (Self.value(element, kAXValueAttribute) as? Int) == 1)
        }
        update(tabs, buttons)
    }

    private func update(_ tabs: [Tab], _ elements: [AXUIElement]) {
        self.elements = elements
        if tabs != self.tabs { self.tabs = tabs }
    }

    /// Breadth-first search of the focused window for the tab bar, skipping
    /// web content (walking it would make the browser build its page tree).
    private static func findTabGroup(in app: NSRunningApplication) -> AXUIElement? {
        let root = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = value(root, kAXFocusedWindowAttribute) else { return nil }
        var queue: [(AXUIElement, Int)] = [(window as! AXUIElement, 0)]
        var visited = 0
        while !queue.isEmpty, visited < 400 {
            let (element, depth) = queue.removeFirst()
            visited += 1
            let role = string(element, kAXRoleAttribute)
            if role == kAXTabGroupRole { return element }
            if role == "AXWebArea" || depth >= 9 { continue }
            queue += children(element).map { ($0, depth + 1) }
        }
        return nil
    }

    /// Chrome appends "- Memory usage - 120 MB" to tab titles.
    private static func cleanTitle(_ title: String) -> String {
        for marker in [" - Memory usage", " - 内存用量", " - 内存使用量"] {
            if let range = title.range(of: marker) { return String(title[..<range.lowerBound]) }
        }
        return title
    }

    private static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        value(element, attribute) as? String
    }

    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        (value(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    }
}

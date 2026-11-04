import AppKit

/// Reads and presses an app's menu bar items through Accessibility.
///
/// Pressing a menu item by name keeps working when an app changes its
/// shortcuts, and the enabled state of items tells what the app is doing
/// (for example, "Step Over" is only enabled while debugging).
///
/// A path lists menu titles from the menu bar down, e.g. `["View", "Hide Sidebar|Show Sidebar"]`.
/// Each component may list alternatives separated by `|`, including localized titles.
/// Matching ignores case and a trailing ellipsis.
@MainActor
enum MenuInvoker {
    struct Entry: Identifiable, Hashable {
        let path: [String]
        let shortcut: String?
        var id: String { path.joined(separator: " › ") }
        var title: String { path.last ?? "" }
    }

    static func press(_ path: [String], in app: NSRunningApplication?) -> Bool {
        guard let item = find(path, in: app) else { return false }
        return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
    }

    /// nil when the item doesn't exist.
    static func isEnabled(_ path: [String], in app: NSRunningApplication?) -> Bool? {
        guard let item = find(path, in: app) else { return nil }
        return (value(item, kAXEnabledAttribute) as? Bool) ?? true
    }

    static func find(_ path: [String], in app: NSRunningApplication?) -> AXUIElement? {
        guard let app, !path.isEmpty, let menuBar = menuBar(of: app) else { return nil }
        var level: [AXUIElement] = children(menuBar)
        var found: AXUIElement?
        for (index, component) in path.enumerated() {
            let alternatives = component.split(separator: "|").map { normalize(String($0)) }
            guard let match = level.first(where: { alternatives.contains(normalize(title(of: $0))) }) else { return nil }
            found = match
            if index < path.count - 1 {
                // A menu bar item or submenu item holds one AXMenu with the items.
                level = children(match).flatMap(children)
            }
        }
        return found
    }

    /// First menu item, at any depth, whose title contains one of the keywords.
    static func search(_ keywords: [String], in app: NSRunningApplication?) -> AXUIElement? {
        guard let app, let menuBar = menuBar(of: app) else { return nil }
        let needles = keywords.map(normalize)
        var queue: [(AXUIElement, Int)] = children(menuBar).map { ($0, 0) }
        while !queue.isEmpty {
            let (element, depth) = queue.removeFirst()
            let name = normalize(title(of: element))
            if depth > 0, !name.isEmpty, needles.contains(where: { name.contains($0) }) {
                return element
            }
            if depth < 3 {
                queue += children(element).flatMap(children).map { ($0, depth + 1) }
            }
        }
        return nil
    }

    static func pressFirst(matching keywords: [String], in app: NSRunningApplication?) -> Bool {
        guard let item = search(keywords, in: app) else { return false }
        return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
    }

    /// Every menu item with its path and shortcut, for the button editor.
    static func entries(of app: NSRunningApplication?) -> [Entry] {
        guard let app, let menuBar = menuBar(of: app) else { return [] }
        var result: [Entry] = []

        func walk(_ element: AXUIElement, path: [String], depth: Int) {
            for item in children(element).flatMap(children) {
                let name = title(of: item)
                guard !name.isEmpty else { continue }
                let submenu = children(item)
                if !submenu.isEmpty, depth < 3 {
                    walk(item, path: path + [name], depth: depth + 1)
                } else {
                    result.append(Entry(path: path + [name], shortcut: shortcut(of: item)))
                }
            }
        }

        for top in children(menuBar).dropFirst() { // skip the Apple menu
            let name = title(of: top)
            guard !name.isEmpty else { continue }
            walk(top, path: [name], depth: 1)
        }
        return result
    }

    // MARK: - Accessibility helpers

    private static func menuBar(of app: NSRunningApplication) -> AXUIElement? {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        guard let bar = value(element, kAXMenuBarAttribute) else { return nil }
        return (bar as! AXUIElement)
    }

    private static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }

    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        (value(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    }

    private static func title(of element: AXUIElement) -> String {
        (value(element, kAXTitleAttribute) as? String) ?? ""
    }

    private static func shortcut(of item: AXUIElement) -> String? {
        guard let char = value(item, "AXMenuItemCmdChar") as? String, !char.isEmpty else { return nil }
        let modifiers = (value(item, "AXMenuItemCmdModifiers") as? Int) ?? 0
        // kAXMenuItemModifier*: bit 0 shift, bit 1 option, bit 2 control, bit 3 no command.
        var text = ""
        if modifiers & 4 != 0 { text += "⌃" }
        if modifiers & 2 != 0 { text += "⌥" }
        if modifiers & 1 != 0 { text += "⇧" }
        if modifiers & 8 == 0 { text += "⌘" }
        return text + char
    }

    private static func normalize(_ title: String) -> String {
        var text = title.trimmingCharacters(in: .whitespaces).lowercased()
        for suffix in ["…", "..."] where text.hasSuffix(suffix) {
            text.removeLast(suffix.count)
        }
        return text.trimmingCharacters(in: .whitespaces)
    }
}

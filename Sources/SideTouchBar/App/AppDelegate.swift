import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings.shared
    private let settingsWindow = SettingsWindowController()
    private var controllers: [EdgeController] = []
    private var statusItem: NSStatusItem?
    private var eventMonitors: [Any] = []
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        controllers = [EdgeController(side: .left), EdgeController(side: .right)]
        layoutPanels()
        applySettings()
        setupStatusItem()
        setupEventMonitors()

        // objectWillChange fires before the new value is stored, so apply on the next run loop pass.
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applySettings()
                self?.layoutPanels()
            }
            .store(in: &cancellables)

        // The permission warning button changes the bar height.
        Permissions.shared.$isTrusted
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applySettings() }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.layoutPanels() }
        }

        if !settings.hasLaunchedBefore {
            settings.hasLaunchedBefore = true
            settingsWindow.show()
        }
        _ = Permissions.shared.requestIfNeeded()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return true
    }

    // MARK: - Panels

    private func layoutPanels(pointer: NSPoint? = nil) {
        guard let screen = targetScreen(pointer: pointer) else { return }
        // A pointer-driven layout only acts when the pointer moved to another screen.
        let moving = controllers.filter { pointer == nil || $0.screen?.displayID != screen.displayID }
        guard !moving.isEmpty else { return }
        moving.forEach { $0.setScreen(screen) }
        updateDisplayStatus()
    }

    private func targetScreen(pointer: NSPoint?) -> NSScreen? {
        let screens = NSScreen.screens
        switch settings.displayTarget {
        case .main:
            return screens.first
        case .builtIn:
            return screens.first(where: \.isBuiltIn) ?? screens.first
        case .followMouse:
            let point = pointer ?? NSEvent.mouseLocation
            return screens.first { NSMouseInRect(point, $0.frame, false) } ?? screens.first
        }
    }

    private func updateDisplayStatus() {
        guard let controller = controllers.first(where: \.isEnabled), let screen = controller.screen else { return }
        DisplayStatus.shared.update(screen: screen, result: BarSizer.metrics(for: screen, content: controller.state.content))
    }

    private func applySettings() {
        defer { updateDisplayStatus() }
        for controller in controllers {
            let side = controller.side
            switch settings.layout {
            case .both:
                controller.setContent(side == settings.controlStripSide ? .controlStrip : .appRegion)
                controller.setEnabled(true)
            case .left, .right:
                controller.setContent(.combined)
                controller.setEnabled(side.rawValue == settings.layout.rawValue)
            }
            controller.refreshMetrics()
            controller.setAppearance(settings.appearance.nsAppearance)
            controller.setAutoHide(settings.autoHide)
        }
    }

    // MARK: - Mouse / touch tracking

    private func setupEventMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .leftMouseDragged, .rightMouseDown]

        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            let type = event.type
            MainActor.assumeIsolated { self?.dispatchPointer(type) }
        }) {
            eventMonitors.append(global)
        }

        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            let type = event.type
            MainActor.assumeIsolated { self?.dispatchPointer(type) }
            return event
        }) {
            eventMonitors.append(local)
        }
    }

    private func dispatchPointer(_ type: NSEvent.EventType) {
        let location = NSEvent.mouseLocation
        // Move the bars to the screen under the pointer, but never while one is open.
        if settings.displayTarget == .followMouse, !controllers.contains(where: \.isExpanded) {
            layoutPanels(pointer: location)
        }
        controllers.forEach { $0.handlePointer(at: location, type: type) }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Side Touch Bar")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(menuItem("设置…", action: #selector(openSettings), key: ","))
        menu.addItem(.separator())

        let layoutHeader = NSMenuItem(title: "布局", action: nil, keyEquivalent: "")
        layoutHeader.isEnabled = false
        menu.addItem(layoutHeader)
        for layout in BarLayout.allCases {
            let item = menuItem(layout.title, action: #selector(selectLayout(_:)))
            item.representedObject = layout.rawValue
            item.state = settings.layout == layout ? .on : .off
            item.indentationLevel = 1
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let autoHide = menuItem("自动隐藏", action: #selector(toggleAutoHide))
        autoHide.state = settings.autoHide ? .on : .off
        menu.addItem(autoHide)

        Permissions.shared.refresh()
        if !Permissions.shared.isTrusted {
            menu.addItem(.separator())
            menu.addItem(menuItem("授予辅助功能权限…", action: #selector(openAccessibility)))
        }

        menu.addItem(.separator())
        menu.addItem(menuItem("退出 Side Touch Bar", action: #selector(quit), key: "q"))
    }

    private func menuItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func selectLayout(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let layout = BarLayout(rawValue: raw) else { return }
        settings.layout = layout
    }

    @objc private func toggleAutoHide() {
        settings.autoHide.toggle()
    }

    @objc private func openAccessibility() {
        Permissions.openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

import AppKit
import Carbon.HIToolbox
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings.shared
    private let settingsWindow = SettingsWindowController()
    private let bar = EdgeController(side: .right)
    private var statusItem: NSStatusItem?
    private var eventMonitors: [Any] = []
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        layoutBar()
        applySettings()
        bar.setEnabled(true)
        setupStatusItem()
        setupEventMonitors()
        NowPlayingStore.shared.start()
        AgentMonitor.shared.start()
        AIContextMonitor.shared.refresh()
        _ = MenuStateMonitor.shared

        AgentMonitor.shared.$revealToken
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard Settings.shared.aiEnabled, Settings.shared.aiAutoReveal else { return }
                self?.bar.revealForAttention()
            }
            .store(in: &cancellables)

        FrontmostAppMonitor.shared.$app
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { AgentMonitor.shared.appActivated($0) }
            .store(in: &cancellables)

        // objectWillChange fires before the new value is stored, so apply on the next run loop pass.
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applySettings()
                self?.layoutBar()
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
            MainActor.assumeIsolated { self?.layoutBar() }
        }

        if !settings.hasLaunchedBefore {
            settings.hasLaunchedBefore = true
            settingsWindow.show()
        }
        _ = Permissions.shared.requestIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NowPlayingStore.shared.stop()
        AgentMonitor.shared.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return true
    }

    // MARK: - Bar

    private func layoutBar(pointer: NSPoint? = nil) {
        guard let screen = targetScreen(pointer: pointer) else { return }
        // A pointer-driven layout only acts when the pointer moved to another screen.
        if pointer != nil, bar.screen?.displayID == screen.displayID { return }
        bar.setScreen(screen)
        DisplayStatus.shared.update(screen: screen, result: BarSizer.metrics(for: screen))
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

    private func applySettings() {
        bar.refreshMetrics()
        bar.setAppearance(settings.appearance.nsAppearance)
        bar.setAutoHide(settings.autoHide)
        if let screen = bar.screen {
            DisplayStatus.shared.update(screen: screen, result: BarSizer.metrics(for: screen))
        }
    }

    // MARK: - Mouse / touch and fn key tracking

    private func setupEventMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .leftMouseDragged, .rightMouseDown, .flagsChanged]

        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            let info = EventInfo(event)
            MainActor.assumeIsolated { self?.handle(info) }
        }) {
            eventMonitors.append(global)
        }

        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            let info = EventInfo(event)
            MainActor.assumeIsolated { self?.handle(info) }
            return event
        }) {
            eventMonitors.append(local)
        }
    }

    private struct EventInfo {
        let type: NSEvent.EventType
        let keyCode: UInt16
        let isFnDown: Bool

        init(_ event: NSEvent) {
            type = event.type
            keyCode = event.type == .flagsChanged ? event.keyCode : 0
            isFnDown = event.modifierFlags.contains(.function)
        }
    }

    private func handle(_ event: EventInfo) {
        if event.type == .flagsChanged {
            // Only the fn/Globe key itself; arrow keys also carry the function flag.
            if event.keyCode == UInt16(kVK_Function) {
                bar.setFnHeld(event.isFnDown)
            }
            return
        }

        let location = NSEvent.mouseLocation
        // Move the bar to the screen under the pointer, but never while it is open.
        if settings.displayTarget == .followMouse, !bar.isExpanded {
            layoutBar(pointer: location)
        }
        bar.handlePointer(at: location, type: event.type)
    }

    // MARK: - Status item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: "Side Touch Bar")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(menuItem("设置…", action: #selector(openSettings), key: ","))
        menu.addItem(.separator())

        let header = NSMenuItem(title: "触控栏显示", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for page in BarPage.allCases {
            let item = menuItem(page.title, action: #selector(selectPage(_:)))
            item.representedObject = page.rawValue
            item.state = settings.barPage == page ? .on : .off
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

    @objc private func selectPage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let page = BarPage(rawValue: raw) else { return }
        settings.barPage = page
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

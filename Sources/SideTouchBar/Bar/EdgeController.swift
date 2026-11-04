import AppKit
import SwiftUI

/// Owns the side bar: positions its panel on the screen edge and decides
/// when it slides in (pointer/touch reaches the edge, or fn is held) and out
/// (pointer leaves or idles).
@MainActor
final class EdgeController {
    let state: BarState
    var side: BarSide { state.side }

    private let panel = EdgePanel()
    private var contentSize = CGSize(width: BarMetrics.standard.width, height: 320)
    private(set) var screen: NSScreen?
    private(set) var isEnabled = true
    private var autoHide = true

    private var lastInside = Date()
    private var lastActivity = Date()
    private var dwellTask: Task<Void, Never>?
    private var shrinkTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?
    private var collapseTimer: Timer?
    /// The bar was revealed by holding fn and should hide again on release.
    private var expandedByFn = false
    /// Stay open while an agent waits for a permission decision, up to this time.
    private var holdOpenUntil: Date?

    init(side: BarSide) {
        state = BarState(side: side)
        panel.setRootView(BarRootView(state: state) { [weak self] size in
            MainActor.assumeIsolated { self?.contentSizeChanged(size) }
        })
        panel.ignoresMouseEvents = true
    }

    // MARK: - Configuration

    func setScreen(_ screen: NSScreen) {
        self.screen = screen
        SpacesStore.shared.displayID = screen.displayID
        refreshMetrics()
        updateFrame(immediately: true)
    }

    var isExpanded: Bool { state.isExpanded }

    /// Re-picks bar sizes for the current screen and settings.
    func refreshMetrics() {
        guard let screen else { return }
        let metrics = BarSizer.metrics(for: screen).metrics
        if metrics != state.metrics {
            state.metrics = metrics
            updateFrame(immediately: true)
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled || enabled != panel.isVisible else { return }
        isEnabled = enabled
        if enabled {
            panel.orderFrontRegardless()
        } else {
            forceCollapse()
            panel.orderOut(nil)
        }
    }

    /// Slides the bar out for an agent that needs a decision, and keeps it out
    /// until the request is answered or 20 seconds pass.
    func revealForAttention() {
        guard isEnabled else { return }
        holdOpenUntil = Date().addingTimeInterval(20)
        expand()
    }

    /// Like the Touch Bar: while fn is held, show the fn page, revealing the bar if hidden.
    func setFnHeld(_ held: Bool) {
        guard isEnabled, held != state.isFnHeld else { return }
        withAnimation(BarAnimation.morph) { state.isFnHeld = held }
        if held {
            if !state.isExpanded {
                expandedByFn = true
                expand()
            }
        } else if expandedByFn {
            expandedByFn = false
            collapse()
        } else {
            lastActivity = Date()
        }
    }

    func setAutoHide(_ enabled: Bool) {
        autoHide = enabled
        if enabled {
            if state.isExpanded { startCollapseTimer() }
        } else {
            collapseTimer?.invalidate()
            expand()
        }
    }

    func setAppearance(_ appearance: NSAppearance?) {
        panel.appearance = appearance
    }

    // MARK: - Pointer handling

    func handlePointer(at point: NSPoint, type: NSEvent.EventType) {
        guard isEnabled, screen != nil else { return }
        if Settings.shared.touchEdgeSwipe { trackSwipe(at: point, type: type) }

        if state.isExpanded {
            if hoverRect.contains(point) {
                lastInside = Date()
                lastActivity = Date()
            }
            return
        }

        // A touch on the handle pill opens the bar right away.
        if type == .leftMouseDown, isOnHandle(point) {
            expand()
            return
        }

        guard isInTriggerZone(point) else {
            dwellTask?.cancel()
            dwellTask = nil
            return
        }

        if type == .leftMouseDown {
            expand()
            return
        }

        // Short dwell so that flicking the cursor past the edge doesn't pop the bar open.
        guard dwellTask == nil else { return }
        dwellTask = Task { @MainActor [weak self] in
            guard (try? await Task.sleep(for: .milliseconds(140))) != nil, let self else { return }
            self.dwellTask = nil
            if self.isInTriggerZone(NSEvent.mouseLocation) { self.expand() }
        }
    }

    // MARK: - Swipes

    private var swipeOrigin: (point: NSPoint, time: Date)?

    /// Swipe in from the screen edge to reveal the bar; swipe out across the
    /// bar toward the edge to hide it. Touch screens deliver these as mouse drags.
    private func trackSwipe(at point: NSPoint, type: NSEvent.EventType) {
        guard let screen else { return }
        switch type {
        case .leftMouseDown:
            let edgeDistance = side == .right ? screen.frame.maxX - point.x : point.x - screen.frame.minX
            let band = barRect.insetBy(dx: 0, dy: -40)
            let startsAtEdge = !state.isExpanded && edgeDistance <= 24 && point.y >= band.minY && point.y <= band.maxY
            let startsOnBar = state.isExpanded && barRect.contains(point)
            swipeOrigin = startsAtEdge || startsOnBar ? (point, Date()) : nil
        case .leftMouseDragged:
            guard let origin = swipeOrigin, Date().timeIntervalSince(origin.time) < 0.8 else { return }
            let inward = side == .right ? origin.point.x - point.x : point.x - origin.point.x
            let vertical = abs(point.y - origin.point.y)
            if !state.isExpanded, inward >= 24, inward > vertical {
                swipeOrigin = nil
                expand()
            } else if state.isExpanded, !state.isInteracting, -inward >= 50, -inward > vertical * 2 {
                swipeOrigin = nil
                forceCollapse()
            }
        case .leftMouseUp:
            swipeOrigin = nil
        default:
            break
        }
    }

    private func isOnHandle(_ point: NSPoint) -> Bool {
        guard let screen else { return false }
        let edgeDistance = side == .right ? screen.frame.maxX - point.x : point.x - screen.frame.minX
        let center = barRect.midY
        return edgeDistance <= 14 && abs(point.y - center) <= state.metrics.handleHeight / 2 + 12
    }

    // MARK: - Expand / collapse

    private func expand() {
        guard isEnabled, !state.isExpanded else { return }
        resetTask?.cancel()
        lastInside = Date()
        lastActivity = Date()
        panel.ignoresMouseEvents = false
        state.isExpanded = true
        BarActivity.shared.isExpanded = true
        startCollapseTimer()
    }

    private func collapse() {
        guard autoHide else { return }
        forceCollapse()
    }

    private func forceCollapse() {
        collapseTimer?.invalidate()
        guard state.isExpanded else { return }
        state.isExpanded = false
        state.isInteracting = false
        expandedByFn = false
        panel.ignoresMouseEvents = true
        BarActivity.shared.isExpanded = false
        Repeater.shared.stop()

        // Return to the compact strip once the bar has slid away.
        resetTask = Task { @MainActor [weak self] in
            guard (try? await Task.sleep(for: .milliseconds(450))) != nil, let self, !self.state.isExpanded else { return }
            self.state.resetTransientState()
        }
    }

    private func startCollapseTimer() {
        collapseTimer?.invalidate()
        guard autoHide else { return }
        collapseTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        let now = Date()
        if let holdOpenUntil {
            if now < holdOpenUntil, AgentMonitor.shared.sessionNeedingPermission != nil {
                lastInside = now
                lastActivity = now
                return
            }
            self.holdOpenUntil = nil
        }
        if state.isInteracting || state.isFnHeld || Repeater.shared.isActive {
            lastInside = now
            lastActivity = now
            return
        }
        if hoverRect.contains(NSEvent.mouseLocation) {
            lastInside = now
        }
        // A touch leaves the cursor parked on the bar, so also hide after a period with no input.
        let idleDelay = Settings.shared.idleDelay
        let isIdle = idleDelay > 0 && now.timeIntervalSince(lastActivity) > idleDelay
        if now.timeIntervalSince(lastInside) > BarMetrics.leaveDelay || isIdle {
            collapse()
        }
    }

    // MARK: - Geometry

    /// The visible bar in global screen coordinates.
    private var barRect: NSRect {
        guard let screen else { return .zero }
        let frame = screen.frame
        let band = screen.barBand
        let width = state.metrics.width
        let height = contentSize.height
        let x = side == .left
            ? frame.minX + BarMetrics.edgeInset
            : frame.maxX - BarMetrics.edgeInset - width
        let midY = (band.lowerBound + band.upperBound) / 2
        return NSRect(x: x, y: midY - height / 2, width: width, height: height)
    }

    private var hoverRect: NSRect {
        let rect = barRect.insetBy(dx: -BarMetrics.hoverSlack, dy: -BarMetrics.hoverSlack)
        // Extend to the screen edge so the gap between edge and bar counts as inside.
        guard let screen else { return rect }
        return side == .left
            ? rect.union(NSRect(x: screen.frame.minX, y: rect.minY, width: 1, height: rect.height))
            : rect.union(NSRect(x: screen.frame.maxX - 1, y: rect.minY, width: 1, height: rect.height))
    }

    private func isInTriggerZone(_ point: NSPoint) -> Bool {
        guard let screen else { return false }
        let frame = screen.frame
        let bar = barRect
        let atEdge = side == .left
            ? point.x <= frame.minX + BarMetrics.triggerWidth && point.x >= frame.minX
            : point.x >= frame.maxX - BarMetrics.triggerWidth && point.x <= frame.maxX
        return atEdge && point.y >= bar.minY - 20 && point.y <= bar.maxY + 20
    }

    private func contentSizeChanged(_ size: CGSize) {
        guard size.height > 0, size != contentSize else { return }
        contentSize = size
        updateFrame(immediately: false)
    }

    /// Grows the window right away, but shrinks it only after the SwiftUI
    /// animation has finished so content is never clipped mid-animation.
    private func updateFrame(immediately: Bool) {
        guard let screen else { return }
        let frame = screen.frame
        let band = screen.barBand
        let margin = BarMetrics.shadowMargin
        let width = BarMetrics.edgeInset + state.metrics.width + margin
        let height = min(contentSize.height + margin * 2, band.upperBound - band.lowerBound).rounded(.up)
        let x = side == .left ? frame.minX : frame.maxX - width
        let midY = (band.lowerBound + band.upperBound) / 2
        let target = NSRect(x: x, y: (midY - height / 2).rounded(), width: width, height: height)

        shrinkTask?.cancel()
        let current = panel.frame
        if immediately || target.height >= current.height || current.minX != target.minX {
            panel.setFrame(target, display: true)
        } else {
            shrinkTask = Task { @MainActor [weak self] in
                guard (try? await Task.sleep(for: .milliseconds(450))) != nil else { return }
                self?.panel.setFrame(target, display: true)
            }
        }
    }
}

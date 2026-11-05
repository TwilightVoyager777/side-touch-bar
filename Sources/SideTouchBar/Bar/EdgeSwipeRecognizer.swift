import AppKit

/// Recognizes edge swipes from mouse events, which is how touch screens
/// deliver touches: in from the screen edge beside the bar reveals it, out
/// across the bar toward the edge hides it.
struct EdgeSwipeRecognizer {
    enum Result: Equatable {
        case none, reveal, hide
    }

    /// A reveal swipe must start this close to the screen edge…
    static let edgeBand: CGFloat = 24
    /// …and no further than this above or below the bar.
    static let verticalSlack: CGFloat = 40
    static let revealDistance: CGFloat = 24
    static let hideDistance: CGFloat = 50
    static let maxDuration: TimeInterval = 0.8

    let side: BarSide
    private var origin: (point: NSPoint, time: Date)?

    init(side: BarSide) {
        self.side = side
    }

    /// Feeds one mouse event. `bar` is the visible bar's frame in the same
    /// coordinates as `point` and `screen`.
    mutating func handle(
        _ type: NSEvent.EventType,
        at point: NSPoint,
        time: Date = Date(),
        screen: NSRect,
        bar: NSRect,
        isExpanded: Bool,
        isInteracting: Bool
    ) -> Result {
        switch type {
        case .leftMouseDown:
            let edgeDistance = side == .right ? screen.maxX - point.x : point.x - screen.minX
            let band = bar.insetBy(dx: 0, dy: -Self.verticalSlack)
            let startsAtEdge = !isExpanded && edgeDistance <= Self.edgeBand && point.y >= band.minY && point.y <= band.maxY
            let startsOnBar = isExpanded && bar.contains(point)
            origin = startsAtEdge || startsOnBar ? (point, time) : nil
        case .leftMouseDragged:
            guard let origin, time.timeIntervalSince(origin.time) < Self.maxDuration else { return .none }
            let inward = side == .right ? origin.point.x - point.x : point.x - origin.point.x
            let vertical = abs(point.y - origin.point.y)
            if !isExpanded, inward >= Self.revealDistance, inward > vertical {
                self.origin = nil
                return .reveal
            }
            if isExpanded, !isInteracting, -inward >= Self.hideDistance, -inward > vertical * 2 {
                self.origin = nil
                return .hide
            }
        case .leftMouseUp:
            origin = nil
        default:
            break
        }
        return .none
    }
}

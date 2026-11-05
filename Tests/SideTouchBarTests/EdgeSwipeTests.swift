import AppKit
import Testing
@testable import SideTouchBar

/// Touch screens deliver touches as mouse events, so these swipes are what a
/// finger on the screen edge produces.
struct EdgeSwipeTests {
    private let screen = NSRect(x: 0, y: 0, width: 1512, height: 982)
    /// A right-edge bar, 6 pt from the edge, vertically centered.
    private let bar = NSRect(x: 1512 - 6 - 56, y: 291, width: 56, height: 400)
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    private func swipe(
        side: BarSide = .right,
        from: NSPoint,
        to: NSPoint,
        after seconds: TimeInterval = 0.15,
        isExpanded: Bool = false,
        isInteracting: Bool = false,
        bar: NSRect? = nil
    ) -> EdgeSwipeRecognizer.Result {
        var recognizer = EdgeSwipeRecognizer(side: side)
        let bar = bar ?? self.bar
        _ = recognizer.handle(.leftMouseDown, at: from, time: start, screen: screen, bar: bar,
                              isExpanded: isExpanded, isInteracting: isInteracting)
        return recognizer.handle(.leftMouseDragged, at: to, time: start.addingTimeInterval(seconds), screen: screen,
                                 bar: bar, isExpanded: isExpanded, isInteracting: isInteracting)
    }

    @Test func swipingLeftFromTheRightEdgeRevealsTheBar() {
        #expect(swipe(from: NSPoint(x: 1510, y: 490), to: NSPoint(x: 1480, y: 495)) == .reveal)
    }

    @Test func revealWorksJustAboveAndBelowTheBar() {
        #expect(swipe(from: NSPoint(x: 1505, y: bar.maxY + 35), to: NSPoint(x: 1470, y: bar.maxY + 35)) == .reveal)
        #expect(swipe(from: NSPoint(x: 1505, y: bar.minY - 35), to: NSPoint(x: 1470, y: bar.minY - 35)) == .reveal)
    }

    @Test func swipesFarFromTheBarHeightAreIgnored() {
        #expect(swipe(from: NSPoint(x: 1510, y: 900), to: NSPoint(x: 1450, y: 900)) == .none)
        #expect(swipe(from: NSPoint(x: 1510, y: 60), to: NSPoint(x: 1450, y: 60)) == .none)
    }

    @Test func swipesNotStartingAtTheEdgeAreIgnored() {
        #expect(swipe(from: NSPoint(x: 1450, y: 490), to: NSPoint(x: 1380, y: 490)) == .none)
    }

    @Test func shortSlowOrVerticalMovesAreIgnored() {
        #expect(swipe(from: NSPoint(x: 1510, y: 490), to: NSPoint(x: 1495, y: 490)) == .none)
        #expect(swipe(from: NSPoint(x: 1510, y: 490), to: NSPoint(x: 1470, y: 490), after: 1) == .none)
        #expect(swipe(from: NSPoint(x: 1510, y: 490), to: NSPoint(x: 1480, y: 560)) == .none)
    }

    @Test func swipingOutAcrossTheBarHidesIt() {
        #expect(swipe(from: NSPoint(x: 1455, y: 490), to: NSPoint(x: 1510, y: 495), isExpanded: true) == .hide)
    }

    @Test func swipingOutIsIgnoredWhileDraggingAControl() {
        #expect(swipe(from: NSPoint(x: 1455, y: 490), to: NSPoint(x: 1510, y: 495), isExpanded: true, isInteracting: true) == .none)
    }

    @Test func swipingInwardOnAnOpenBarDoesNothing() {
        #expect(swipe(from: NSPoint(x: 1505, y: 490), to: NSPoint(x: 1460, y: 490), isExpanded: true) == .none)
    }

    @Test func aSwipeFiresOnce() {
        var recognizer = EdgeSwipeRecognizer(side: .right)
        _ = recognizer.handle(.leftMouseDown, at: NSPoint(x: 1510, y: 490), time: start, screen: screen, bar: bar,
                              isExpanded: false, isInteracting: false)
        let first = recognizer.handle(.leftMouseDragged, at: NSPoint(x: 1480, y: 490), time: start, screen: screen,
                                      bar: bar, isExpanded: false, isInteracting: false)
        let second = recognizer.handle(.leftMouseDragged, at: NSPoint(x: 1450, y: 490), time: start, screen: screen,
                                       bar: bar, isExpanded: false, isInteracting: false)
        #expect(first == .reveal)
        #expect(second == .none)
    }

    @Test func leftEdgeIsMirrored() {
        let leftBar = NSRect(x: 6, y: 291, width: 56, height: 400)
        #expect(swipe(side: .left, from: NSPoint(x: 2, y: 490), to: NSPoint(x: 32, y: 490), bar: leftBar) == .reveal)
        #expect(swipe(side: .left, from: NSPoint(x: 2, y: 490), to: NSPoint(x: -20, y: 490), bar: leftBar) == .none)
    }
}

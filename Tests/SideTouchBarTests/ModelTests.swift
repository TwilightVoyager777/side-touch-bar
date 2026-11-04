import Carbon.HIToolbox
import Foundation
import Testing
@testable import SideTouchBar

struct ModelTests {
    @Test func keyComboRoundTrips() throws {
        let combo = KeyCombo(kVK_ANSI_K, [.maskCommand, .maskShift])
        let decoded = try JSONDecoder().decode(KeyCombo.self, from: JSONEncoder().encode(combo))
        #expect(decoded == combo)
    }

    @Test func recordedComboKeepsOnlyModifierKeys() {
        let combo = KeyCombo(key: CGKeyCode(kVK_ANSI_A), flags: [.maskCommand, .maskNumericPad, .maskSecondaryFn])
        #expect(combo.flags == .maskCommand)
    }

    @Test func customButtonsRoundTrip() throws {
        let set = CustomButtonSet(replacesBuiltIn: true, buttons: [
            CustomButton(title: "Build", symbol: "hammer", kind: .menu(["Product", "Build"])),
            CustomButton(title: "Save", symbol: "", kind: .keys(KeyCombo(kVK_ANSI_S, .maskCommand))),
            CustomButton(title: "Hi", symbol: "", kind: .text("hello", submit: true)),
        ])
        let decoded = try JSONDecoder().decode(CustomButtonSet.self, from: JSONEncoder().encode(set))
        #expect(decoded == set)
    }

    @Test func customButtonWithoutSymbolShowsTitle() {
        let button = CustomButton(title: "构建项目", symbol: "", kind: .keys(KeyCombo(0)))
        #expect(button.barItem.icon == .text("构建"))
    }

    @MainActor @Test func customPageSplitsIntoGroupsOfFour() {
        let buttons = (0..<7).map { CustomButton(title: "\($0)", symbol: "star", kind: .keys(KeyCombo(0))) }
        let page = PresetResolver.customPage(buttons)
        #expect(page.groups.map(\.count) == [4, 3])
    }

    @Test func snippetsRoundTrip() throws {
        // Defaults are generated per language with fresh IDs, so take them once.
        let defaults = AISnippet.defaults
        let decoded = try JSONDecoder().decode([AISnippet].self, from: JSONEncoder().encode(defaults))
        #expect(decoded == defaults)
    }

    @Test func playbackPositionAdvancesWhilePlaying() {
        let start = Date()
        var info = NowPlayingInfo.sample
        info.elapsed = 10
        info.timestamp = start
        info.rate = 2
        info.isPlaying = true
        #expect(info.position(at: start.addingTimeInterval(5)) == 20)
        info.isPlaying = false
        #expect(info.position(at: start.addingTimeInterval(5)) == 10)
    }

    @Test func playbackPositionStopsAtDuration() {
        var info = NowPlayingInfo.sample
        info.elapsed = 190
        info.timestamp = Date()
        info.isPlaying = true
        #expect(info.position(at: Date().addingTimeInterval(60)) == 200)
    }

    @Test func metricsScaleFromBaseline() {
        let standard = BarMetrics.standard
        #expect(standard.buttonSize == 44)
        #expect(standard.width == 58)
        let small = BarMetrics(scale: 0.85)
        #expect(small.buttonSize == 37)
        #expect(small.cornerRadius == small.width / 2)
    }

    @MainActor @Test func physicalScaleMatchesMacBookPro() {
        // 14" and 16" MacBook Pro default resolutions are 5 pt/mm: 44pt buttons.
        #expect(abs(BarSizer.physicalScale(pointsPerMillimeter: 1512 / 302.5) - 1) < 0.01)
        #expect(abs(BarSizer.physicalScale(pointsPerMillimeter: 1728 / 345.6) - 1) < 0.01)
        // Clamped on very dense or very sparse displays.
        #expect(BarSizer.physicalScale(pointsPerMillimeter: 20) == BarSizer.physicalScaleRange.upperBound)
        #expect(BarSizer.physicalScale(pointsPerMillimeter: 1) == BarSizer.physicalScaleRange.lowerBound)
    }
}

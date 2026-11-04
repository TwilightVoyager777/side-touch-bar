import AppKit
import Carbon.HIToolbox

/// Desktops (Spaces) of the bar's display, read through SkyLight, for the
/// Touch Bar "Spaces" page.
@MainActor
final class SpacesStore: ObservableObject {
    static let shared = SpacesStore()

    struct Space: Identifiable, Equatable {
        let id: Int
        let isFullScreen: Bool
    }

    @Published private(set) var spaces: [Space] = []
    @Published private(set) var currentID: Int?

    /// Display whose spaces are listed; nil uses the first one reported.
    var displayID: CGDirectDisplayID? {
        didSet { if displayID != oldValue { refresh() } }
    }

    private typealias ConnectionFunction = @convention(c) () -> Int32
    private typealias CopySpacesFunction = @convention(c) (Int32) -> Unmanaged<CFArray>?

    private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private static let mainConnection: ConnectionFunction? = {
        guard let skyLight, let symbol = dlsym(skyLight, "SLSMainConnectionID") else { return nil }
        return unsafeBitCast(symbol, to: ConnectionFunction.self)
    }()

    private static let copyManagedDisplaySpaces: CopySpacesFunction? = {
        guard let skyLight, let symbol = dlsym(skyLight, "SLSCopyManagedDisplaySpaces") else { return nil }
        return unsafeBitCast(symbol, to: CopySpacesFunction.self)
    }()

    private init() {
        refresh()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        guard
            let connection = Self.mainConnection?(),
            let displays = Self.copyManagedDisplaySpaces?(connection)?.takeRetainedValue() as? [[String: Any]]
        else { return }

        let display = displays.first { ($0["Display Identifier"] as? String) == displayUUID }
            ?? displays.first { ($0["Display Identifier"] as? String) == "Main" }
            ?? displays.first
        guard let display else { return }

        let newSpaces = ((display["Spaces"] as? [[String: Any]]) ?? []).compactMap { info -> Space? in
            guard let id = info["ManagedSpaceID"] as? Int else { return nil }
            return Space(id: id, isFullScreen: (info["type"] as? Int) == 4)
        }
        let newCurrent = (display["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int
        if newSpaces != spaces { spaces = newSpaces }
        if newCurrent != currentID { currentID = newCurrent }
    }

    /// Moves to a space with repeated ⌃← / ⌃→ (enabled by default in macOS),
    /// since the ⌃1…9 shortcuts are often turned off.
    func switchTo(_ space: Space) {
        guard
            let current = spaces.firstIndex(where: { $0.id == currentID }),
            let target = spaces.firstIndex(where: { $0.id == space.id }),
            current != target
        else { return }
        let key = target > current ? kVK_RightArrow : kVK_LeftArrow
        let steps = abs(target - current)
        Task { @MainActor in
            for step in 0..<steps {
                if step > 0 { try? await Task.sleep(for: .milliseconds(80)) }
                ActionRunner.sendKeys(KeyCombo(key, .maskControl))
            }
        }
    }

    func move(by offset: Int) {
        ActionRunner.sendKeys(KeyCombo(offset > 0 ? kVK_RightArrow : kVK_LeftArrow, .maskControl))
    }

    private var displayUUID: String? {
        guard let displayID, let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String?
    }
}

import AppKit

// Wrappers around private system frameworks for features the Touch Bar had but
// that have no public API. Every call is optional: if a framework or selector
// is missing on a given macOS version, callers fall back to something else.

private let coreBrightness: UnsafeMutableRawPointer? = dlopen(
    "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
    RTLD_LAZY
)

private func makeClient(_ className: String) -> NSObject? {
    _ = coreBrightness
    guard let type = NSClassFromString(className) as? NSObject.Type else { return nil }
    return type.init()
}

/// Keyboard backlight via CoreBrightness `KeyboardBrightnessClient`.
@MainActor
enum KeyboardBrightness {
    private typealias GetFunction = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias SetFunction = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool

    private static let client = makeClient("KeyboardBrightnessClient")

    private static let keyboardID: UInt64? = {
        let selector = NSSelectorFromString("copyKeyboardBacklightIDs")
        guard let client, client.responds(to: selector),
              let ids = client.perform(selector)?.takeUnretainedValue() as? [NSNumber]
        else { return nil }
        return ids.first?.uint64Value
    }()

    static func get() -> Float? {
        let selector = NSSelectorFromString("brightnessForKeyboard:")
        guard let client, let keyboardID, client.responds(to: selector) else { return nil }
        let function = unsafeBitCast(client.method(for: selector), to: GetFunction.self)
        return function(client, selector, keyboardID)
    }

    static func set(_ value: Float) {
        let selector = NSSelectorFromString("setBrightness:forKeyboard:")
        guard let client, let keyboardID, client.responds(to: selector) else { return }
        let function = unsafeBitCast(client.method(for: selector), to: SetFunction.self)
        _ = function(client, selector, min(max(value, 0), 1), keyboardID)
    }

    /// Returns false when unsupported, so the caller can fall back to media keys.
    static func step(_ delta: Float) -> Bool {
        guard let current = get() else { return false }
        set(current + delta)
        return true
    }
}

/// Night Shift via CoreBrightness `CBBlueLightClient`.
@MainActor
enum NightShift {
    private typealias GetStatusFunction = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> Bool
    private typealias SetEnabledFunction = @convention(c) (AnyObject, Selector, Bool) -> Bool

    private static let client = makeClient("CBBlueLightClient")

    static func toggle() {
        let getSelector = NSSelectorFromString("getBlueLightStatus:")
        let setSelector = NSSelectorFromString("setEnabled:")
        guard let client, client.responds(to: getSelector), client.responds(to: setSelector) else { return }

        // Status struct: { BOOL active; BOOL enabled; BOOL sunSchedulePermitted; int mode; ... }
        let status = UnsafeMutableRawPointer.allocate(byteCount: 128, alignment: 8)
        defer { status.deallocate() }
        status.initializeMemory(as: UInt8.self, repeating: 0, count: 128)

        let getStatus = unsafeBitCast(client.method(for: getSelector), to: GetStatusFunction.self)
        guard getStatus(client, getSelector, status) else { return }
        let isEnabled = status.load(fromByteOffset: 1, as: UInt8.self) != 0

        let setEnabled = unsafeBitCast(client.method(for: setSelector), to: SetEnabledFunction.self)
        _ = setEnabled(client, setSelector, !isEnabled)
    }
}

/// Light/Dark appearance via SkyLight, falling back to AppleScript (asks for Automation permission).
@MainActor
enum DarkMode {
    private typealias GetFunction = @convention(c) () -> Bool
    private typealias SetFunction = @convention(c) (Bool) -> Void

    private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private static let getFunction: GetFunction? = {
        guard let skyLight, let symbol = dlsym(skyLight, "SLSGetAppearanceThemeLegacy") else { return nil }
        return unsafeBitCast(symbol, to: GetFunction.self)
    }()

    private static let setFunction: SetFunction? = {
        guard let skyLight, let symbol = dlsym(skyLight, "SLSSetAppearanceThemeLegacy") else { return nil }
        return unsafeBitCast(symbol, to: SetFunction.self)
    }()

    static func toggle() {
        if let getFunction, let setFunction {
            setFunction(!getFunction())
            return
        }
        let source = """
        tell application "System Events" to tell appearance preferences to set dark mode to not dark mode
        """
        NSAppleScript(source: source)?.executeAndReturnError(nil)
    }
}

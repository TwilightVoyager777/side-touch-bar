import CoreGraphics
import Foundation

/// Built-in display brightness through the private DisplayServices framework
/// (the same API the brightness keys use). Unavailable on most external displays.
enum Brightness {
    private typealias GetFunction = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFunction = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let handle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_LAZY
    )

    private static let getFunction: GetFunction? = {
        guard let handle, let symbol = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(symbol, to: GetFunction.self)
    }()

    private static let setFunction: SetFunction? = {
        guard let handle, let symbol = dlsym(handle, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(symbol, to: SetFunction.self)
    }()

    static func get() -> Float? {
        guard let getFunction else { return nil }
        var value: Float = 0
        return getFunction(displayID, &value) == 0 ? value : nil
    }

    static func set(_ value: Float) {
        _ = setFunction?(displayID, min(max(value, 0), 1))
    }

    static func step(_ delta: Float) {
        guard let current = get() else { return }
        set(current + delta)
    }

    private static var displayID: CGDirectDisplayID {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &displays, &count)
        return displays.first { CGDisplayIsBuiltin($0) != 0 } ?? CGMainDisplayID()
    }
}

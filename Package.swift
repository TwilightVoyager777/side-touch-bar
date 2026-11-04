// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SideTouchBar",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "SideTouchBar",
            path: "Sources/SideTouchBar"
        ),
        .testTarget(
            name: "SideTouchBarTests",
            dependencies: ["SideTouchBar"],
            path: "Tests/SideTouchBarTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)

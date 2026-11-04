// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SideTouchBar",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "SideTouchBar",
            path: "Sources/SideTouchBar"
        )
    ]
)

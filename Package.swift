// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "quickSwitch",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "QuickSwitchCore"),
        .executableTarget(
            name: "quickSwitch",
            dependencies: ["QuickSwitchCore"]
        ),
        .testTarget(
            name: "QuickSwitchCoreTests",
            dependencies: ["QuickSwitchCore"]
        ),
    ]
)

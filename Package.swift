// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DualQueuePlayer",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DualQueuePlayer", targets: ["DualQueuePlayer"])
    ],
    targets: [
        .executableTarget(
            name: "DualQueuePlayer",
            path: "DualQueuePlayer"
        ),
        .testTarget(
            name: "DualQueuePlayerTests",
            dependencies: ["DualQueuePlayer"],
            path: "Tests/DualQueuePlayerTests"
        )
    ],
    swiftLanguageModes: [.v5]
)

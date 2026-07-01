// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "orca",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "OrcaBridgeCore",
            path: "Sources/OrcaBridgeCore"
        ),
        .executableTarget(
            name: "orca",
            dependencies: ["OrcaBridgeCore"],
            path: "Sources/orca"
        ),
        .testTarget(
            name: "OrcaBridgeCoreTests",
            dependencies: ["OrcaBridgeCore"],
            path: "Tests/OrcaBridgeCoreTests"
        )
    ]
)

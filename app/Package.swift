// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Orca",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "OrcaCore",
            path: "Sources/OrcaCore"
        ),
        .executableTarget(
            name: "Orca",
            dependencies: ["OrcaCore"],
            path: "Sources/Orca"
        ),
        .testTarget(
            name: "OrcaCoreTests",
            dependencies: ["OrcaCore"],
            path: "Tests/OrcaCoreTests"
        )
    ]
)

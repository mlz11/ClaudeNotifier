// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "ClaudeNotifier",
    platforms: [
        .macOS(.v11)
    ],
    targets: [
        .executableTarget(
            name: "ClaudeNotifier",
            path: "Sources/ClaudeNotifier"
        )
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "clod",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "clod",
            path: "Sources/clod"
        ),
    ]
)

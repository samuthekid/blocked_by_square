// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BlockedBySquare",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "BlockedBySquare",
            path: "Sources/BlockedBySquare"
        )
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitBeacon",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "GitBeacon",
            path: "Sources/GitBeacon"
        )
    ]
)

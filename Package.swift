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
            path: "Sources/GitBeacon",
            exclude: ["Info.plist"],
            linkerSettings: [
                // SwiftPM executables (via `swift build` or Xcode's SwiftPM
                // run) are bare Mach-O binaries, not `.app` bundles, so
                // Bundle.main has no CFBundleIdentifier by default —
                // UNUserNotificationCenter requires one. Embedding an
                // Info.plist into the __TEXT,__info_plist section is the
                // standard workaround short of a full .xcodeproj/.app target.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/GitBeacon/Info.plist"
                ])
            ]
        )
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PiChat",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PiChat",
            path: "PiChat",
            exclude: ["Info.plist", "Assets.xcassets"],
            swiftSettings: [
                .unsafeFlags(["-framework", "AppKit"])
            ]
        )
    ]
)

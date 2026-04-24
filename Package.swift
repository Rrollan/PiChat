// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PiChat",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PiChat",
            path: "PiChat",
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets"),
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-framework", "AppKit"])
            ]
        )
    ]
)

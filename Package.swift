// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ColorPicker",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.10.0")
    ],
    targets: [
        .executableTarget(
            name: "ColorPicker",
            dependencies: ["KeyboardShortcuts"],
            path: "Sources/ColorPicker"
        )
    ]
)

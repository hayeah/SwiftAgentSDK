// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TodoList",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(name: "SwiftUITap", path: "../../"),
    ],
    targets: [
        .executableTarget(
            name: "TodoList",
            dependencies: [.product(name: "SwiftUITap", package: "SwiftUITap")],
            path: "TodoList",
            exclude: ["Info.plist"]
        ),
    ]
)

// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TodoListiOS",
    platforms: [
        .iOS(.v17),
    ],
    dependencies: [
        .package(name: "SwiftUITap", path: "../../"),
    ],
    targets: [
        .executableTarget(
            name: "TodoListiOS",
            dependencies: [.product(name: "SwiftUITap", package: "SwiftUITap")],
            path: "TodoListiOS"
        ),
    ]
)

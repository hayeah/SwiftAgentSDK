// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftAgentSDK",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "SwiftAgentSDK",
            targets: ["SwiftAgentSDK"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftAgentSDK",
            path: "Sources/SwiftAgentSDK"
        ),
    ]
)

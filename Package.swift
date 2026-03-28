// swift-tools-version: 5.9

import PackageDescription
import CompilerPluginSupport

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
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "509.0.0"),
    ],
    targets: [
        .macro(
            name: "SwiftAgentSDKMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "Sources/SwiftAgentSDKMacros"
        ),
        .target(
            name: "SwiftAgentSDK",
            dependencies: ["SwiftAgentSDKMacros"],
            path: "Sources/SwiftAgentSDK"
        ),
        .testTarget(
            name: "SwiftAgentSDKTests",
            dependencies: [
                "SwiftAgentSDKMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)

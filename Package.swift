// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var defaultSwiftSettings: [SwiftSetting] {
    [
        .treatAllWarnings(as: .error),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("NonisolatedNonsendingBy"),
    ]
}

let package = Package(
    name: "async-swiftly",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(
            name: "AsyncSwiftly",
            targets: ["AsyncSwiftly"],
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.4"),
    ],
    targets: [
        .target(
            name: "AsyncSwiftly",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            swiftSettings: defaultSwiftSettings,
        ),
        .target(
            name: "AsyncMaterializedSequence",
            swiftSettings: defaultSwiftSettings,
        ),
        .target(
            name: "AsyncTrigger",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            swiftSettings: defaultSwiftSettings,
        ),
        .target(
            name: "ManualClock",
            swiftSettings: defaultSwiftSettings,
        ),
        .target(
            name: "TestingSupport",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            swiftSettings: defaultSwiftSettings,
        ),
        .testTarget(
            name: "AsyncSwiftlyTests",
            dependencies: [
                "AsyncSwiftly",
                "TestingSupport",
            ],
            swiftSettings: defaultSwiftSettings,
        ),
        .testTarget(
            name: "AsyncMaterializedSequenceTests",
            dependencies: [
                "AsyncMaterializedSequence", 
                "TestingSupport",
            ],
            swiftSettings: defaultSwiftSettings,
        ),
        .testTarget(
            name: "AsyncTriggerTests",
            dependencies: [
                "AsyncTrigger",
                "TestingSupport",
            ],
            swiftSettings: defaultSwiftSettings,
        ),
        .testTarget(
            name: "ManualClockTests",
            dependencies: [
                "ManualClock",
                "TestingSupport",
            ],
            swiftSettings: defaultSwiftSettings,
        ),
        .testTarget(
            name: "TestingSupportTests",
            dependencies: [
                "TestingSupport",
            ],
            swiftSettings: defaultSwiftSettings,
        ),
    ]
)

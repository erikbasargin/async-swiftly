// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "async-swiftly",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "AsyncSwiftly",
            targets: ["AsyncSwiftly"]
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
            ]
        ),
        .target(
            name: "AsyncMaterializedSequence"
        ),
        .target(
            name: "AsyncTrigger",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),
        .target(
            name: "TestingSupport",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
        ),
        .testTarget(
            name: "AsyncSwiftlyTests",
            dependencies: [
                "AsyncSwiftly",
                "TestingSupport",
            ]
        ),
        .testTarget(
            name: "AsyncMaterializedSequenceTests",
            dependencies: [
                "AsyncMaterializedSequence", 
                "TestingSupport",
            ]
        ),
        .testTarget(
            name: "AsyncTriggerTests",
            dependencies: [
                "AsyncTrigger",
                "TestingSupport",
            ]
        ),
        .testTarget(
            name: "TestingSupportTests",
            dependencies: [
                "TestingSupport",
            ]
        ),
    ]
)

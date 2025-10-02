// swift-tools-version: 6.2
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
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .target(
            name: "AsyncMaterializedSequence",
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .target(
            name: "AsyncTrigger",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .target(
            name: "TestingSupport",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "AsyncSwiftlyTests",
            dependencies: [
                "AsyncSwiftly",
                "TestingSupport",
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "AsyncMaterializedSequenceTests",
            dependencies: [
                "AsyncMaterializedSequence", 
                "TestingSupport",
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "AsyncTriggerTests",
            dependencies: [
                "AsyncTrigger",
                "TestingSupport",
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "TestingSupportTests",
            dependencies: [
                "TestingSupport",
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ]
)

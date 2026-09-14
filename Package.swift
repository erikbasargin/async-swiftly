// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var defaultSwiftSettings: [SwiftSetting] {
    [
        .enableUpcomingFeature("ApproachableConcurrency"),
        .enableUpcomingFeature("ExistentialAny"),
    ]
}

let package = Package(
    name: "async-swiftly",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "AsyncSwiftly",
            targets: ["AsyncSwiftly"],
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.6.0")
    ],
    targets: [
        .target(
            name: "AsyncSwiftly",
            swiftSettings: defaultSwiftSettings,
        ),
        .target(
            name: "BucketPriorityQueue",
            dependencies: [
                .product(name: "DequeModule", package: "swift-collections")
            ],
            swiftSettings: defaultSwiftSettings,
        ),
        .testTarget(
            name: "AsyncSwiftlyTests",
            dependencies: ["AsyncSwiftly"],
            swiftSettings: defaultSwiftSettings,
        ),
        .testTarget(
            name: "BucketPriorityQueueTests",
            dependencies: ["BucketPriorityQueue"],
            swiftSettings: defaultSwiftSettings,
        ),
    ],
)

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
    products: [
        .library(
            name: "AsyncSwiftly",
            targets: ["AsyncSwiftly"],
        )
    ],
    targets: [
        .target(
            name: "AsyncSwiftly",
            swiftSettings: defaultSwiftSettings,
        ),
        .target(
            name: "BucketPriorityQueue",
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

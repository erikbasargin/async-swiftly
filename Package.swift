// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "async-swiftly",
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
            name: "AsyncSwiftly"
        ),
        .target(
            name: "TestingSupport",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
        ),
        .testTarget(
            name: "AsyncSwiftlyTests",
            dependencies: ["AsyncSwiftly"]
        ),
        .testTarget(
            name: "TestingSupportTests",
            dependencies: ["TestingSupport"]
        ),
    ]
)

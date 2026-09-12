// swift-tools-version: 6.4
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
    targets: [
        .target(
            name: "AsyncSwiftly"
        ),
        .testTarget(
            name: "AsyncSwiftlyTests",
            dependencies: ["AsyncSwiftly"]
        ),
    ]
)

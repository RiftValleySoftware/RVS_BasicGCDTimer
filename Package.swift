// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "RVS_BasicGCDTimer",
    platforms: [
        .iOS(.v11),
        .tvOS(.v11),
        .macOS(.v10.14),
        .watchOS(.v5)
    ],
    products: [
        .library(
            name: "RVS-BasicGCDTimer",
            type: .dynamic,
            targets: ["RVS_BasicGCDTimer"])
    ],
    targets: [
        .target(
            name: "RVS_BasicGCDTimer",
            path: "./src")
    ]
)

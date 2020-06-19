// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "RVS_BasicGCDTimer",
    products: [
        .library(
            name: "RVS_BasicGCDTimer",
            type: .dynamic,
            targets: ["RVS_BasicGCDTimer"])
    ],
    targets: [
        .target(
            name: "RVS_BasicGCDTimer",
            path: "./src")
    ]
)

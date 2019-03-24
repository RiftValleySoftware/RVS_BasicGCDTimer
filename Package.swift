import PackageDescription

let package = Package(
    name: "RVS_BasicGCDTimer",
    products: [
        .library(
            name: "RVS_BasicGCDTimer",
            targets: ["RVS_BasicGCDTimer"]
        )
    ],
    targets: [
        .target(
            name: "RVS_BasicGCDTimer",
            path: "RVS_BasicGCDTimer"
        )
    ],
    swiftLanguageVersions: [
        4.2
    ]
)

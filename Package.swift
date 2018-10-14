// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "JSONUtilities",
    products: [
        .library(name: "JSONUtilities", targets: ["JSONUtilities"])
    ],
    dependencies: [],
    targets: [
        .target(name: "JSONUtilities"),
        .testTarget(name: "JSONUtilitiesTests")
    ]
)

// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "JSONUtilities",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(name: "JSONUtilities", targets: ["JSONUtilities"]),
    ],
    targets: [
        .target(name: "JSONUtilities"),
        .testTarget(name: "JSONUtilitiesTests", dependencies: ["JSONUtilities"]),
    ]
)

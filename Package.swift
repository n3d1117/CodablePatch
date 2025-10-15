// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CodablePatch",
    platforms: [
        .iOS(.v16),
        .macOS(.v10_13),
        .tvOS(.v12),
        .watchOS(.v4)
    ],
    products: [
        .library(
            name: "CodablePatch",
            targets: ["CodablePatch"]
        )
    ],
    targets: [
        .target(name: "CodablePatch"),
        .testTarget(
            name: "CodablePatchTests",
            dependencies: ["CodablePatch"]
        )
    ]
)

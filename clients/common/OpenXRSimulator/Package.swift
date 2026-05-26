// swift-tools-version: 5.10
// SPDX-License-Identifier: MPL-2.0

import PackageDescription

let package = Package(
    name: "OpenXRSimulator",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "OpenXRSimulator", targets: ["OpenXRSimulator"]),
    ],
    dependencies: [
        .package(path: "../OpenXRStreaming"),
    ],
    targets: [
        .target(
            name: "OpenXRSimulator",
            dependencies: ["OpenXRStreaming"],
            path: "Sources/OpenXRSimulator"
        ),
    ]
)

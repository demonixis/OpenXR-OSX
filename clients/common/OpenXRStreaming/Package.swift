// swift-tools-version: 5.10
// SPDX-License-Identifier: MPL-2.0

import PackageDescription

let package = Package(
    name: "OpenXRStreaming",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "OpenXRStreaming", targets: ["OpenXRStreaming"]),
    ],
    targets: [
        .target(
            name: "OpenXRStreaming",
            path: "Sources/OpenXRStreaming",
            resources: [
                .process("Shaders.metal"),
            ]
        ),
        .testTarget(
            name: "OpenXRStreamingTests",
            dependencies: ["OpenXRStreaming"],
            path: "Tests/OpenXRStreamingTests"
        ),
    ]
)

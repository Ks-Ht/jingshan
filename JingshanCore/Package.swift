// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JingshanCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "JingshanCore",
            targets: ["JingshanCore"]
        )
    ],
    targets: [
        .target(
            name: "JingshanCore",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "JingshanCoreTests",
            dependencies: ["JingshanCore"]
        )
    ]
)

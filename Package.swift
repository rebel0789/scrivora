// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocalVoiceFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "LocalVoiceFlowCore", targets: ["LocalVoiceFlowCore"]),
        .executable(name: "LocalVoiceFlowApp", targets: ["LocalVoiceFlowApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.15.2")
    ],
    targets: [
        .target(name: "LocalVoiceFlowCore"),
        .executableTarget(
            name: "LocalVoiceFlowApp",
            dependencies: [
                "LocalVoiceFlowCore",
                .product(name: "FluidAudio", package: "FluidAudio")
            ]
        ),
        .testTarget(
            name: "LocalVoiceFlowCoreTests",
            dependencies: ["LocalVoiceFlowCore"]
        )
    ]
)

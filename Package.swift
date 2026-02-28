// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Transcribo",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "Transcribo", targets: ["TranscriboApp"]),
        .library(name: "AudioCapture", targets: ["AudioCapture"]),
        .library(name: "InferenceEngine", targets: ["InferenceEngine"]),
        .library(name: "TextInjection", targets: ["TextInjection"]),
    ],
    targets: [
        // Main app target
        .executableTarget(
            name: "TranscriboApp",
            dependencies: [
                "AudioCapture",
                "InferenceEngine",
                "TextInjection",
            ],
            path: "Sources/TranscriboApp",
            resources: [
                .copy("Resources"),
            ]
        ),

        // Audio capture library
        .target(
            name: "AudioCapture",
            path: "Sources/AudioCapture"
        ),

        // Inference engine library
        .target(
            name: "InferenceEngine",
            path: "Sources/InferenceEngine"
        ),

        // Text injection library
        .target(
            name: "TextInjection",
            path: "Sources/TextInjection"
        ),

        // Tests
        .testTarget(
            name: "AudioCaptureTests",
            dependencies: ["AudioCapture"]
        ),
        .testTarget(
            name: "InferenceEngineTests",
            dependencies: ["InferenceEngine"]
        ),
        .testTarget(
            name: "TextInjectionTests",
            dependencies: ["TextInjection"]
        ),
    ]
)

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
    dependencies: [
        .package(url: "https://github.com/Blaizzy/mlx-audio-swift.git", branch: "main"),
        .package(url: "https://github.com/huggingface/swift-huggingface.git", from: "0.6.0"),
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
            dependencies: [
                .product(name: "MLXAudioSTT", package: "mlx-audio-swift"),
                .product(name: "MLXAudioCore", package: "mlx-audio-swift"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
            ],
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

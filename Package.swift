// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Flockerwhisper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "FlockerwhisperCore",
            targets: ["FlockerwhisperCore"]
        ),
        .executable(
            name: "Flockerwhisper",
            targets: ["Flockerwhisper"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.1.1")
    ],
    targets: [
        .target(
            name: "FlockerwhisperCore",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift")
            ],
            path: "Sources/FlockerwhisperCore"
        ),
        .executableTarget(
            name: "Flockerwhisper",
            dependencies: [
                "FlockerwhisperCore"
            ],
            path: "Sources/Flockerwhisper"
        ),
        .testTarget(
            name: "FlockerwhisperTests",
            dependencies: [
                "FlockerwhisperCore"
            ],
            path: "Tests/FlockerwhisperTests"
        )
    ]
)

// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AIVoiceManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AIVoiceManager", targets: ["AIVoiceManagerApp"])
    ],
    dependencies: [],
    targets: [
        // One executable, no helper / XPC (ADR-001)
        .executableTarget(
            name: "AIVoiceManagerApp",
            path: "Sources/AIVoiceManagerApp",
            // Info.plist is copied by scripts/build-app.sh, not compiled in
            exclude: ["Info.plist"],
            // Art/ keeps its folders (.copy): same Art/Voices/<name>.png path here and in the .app
            resources: [.process("Resources"), .copy("Art")]
        ),
        .testTarget(
            name: "AIVoiceManagerTests",
            dependencies: ["AIVoiceManagerApp"],
            path: "Tests/AIVoiceManagerTests"
        )
    ]
)

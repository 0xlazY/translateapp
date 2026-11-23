// swift-tools-version:6.0
import PackageDescription

// Pure, platform-independent rules: Russian text handling, spaced repetition, card
// import/export. No Apple-only frameworks, so `swift test` also runs on Linux.
let package = Package(
    name: "PandouchkaCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "PandouchkaCore", targets: ["PandouchkaCore"])],
    targets: [
        .target(name: "PandouchkaCore"),
        .testTarget(name: "PandouchkaCoreTests", dependencies: ["PandouchkaCore"]),
    ],
    swiftLanguageModes: [.v5]
)

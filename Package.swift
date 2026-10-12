// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AetherNote",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "AetherNote", targets: ["AetherNote"]), .library(name: "AetherNoteCore", targets: ["AetherNoteCore"])],
    targets: [
        .target(name: "AetherNoteCore"),
        .executableTarget(name: "AetherNote", dependencies: ["AetherNoteCore"]),
        .testTarget(name: "AetherNoteCoreTests", dependencies: ["AetherNoteCore"])
    ],
    swiftLanguageModes: [.v5]
)

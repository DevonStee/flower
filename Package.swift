// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Flower",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Flower", targets: ["Flower"]),
    ],
    targets: [
        // Platform-independent logic: HTTP parsing, routing, auth, settings, networking helpers.
        .target(name: "FlowerCore"),
        // The menu bar app: SwiftUI, ScreenCaptureKit, Keychain.
        .executableTarget(name: "Flower", dependencies: ["FlowerCore"]),
        .testTarget(name: "FlowerCoreTests", dependencies: ["FlowerCore"]),
    ]
)

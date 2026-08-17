// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PaspoID",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        // Not a supported integration target: macOS is here so `swift test` can run the
        // wire/crypto suites without a simulator.
        .macOS(.v12),
    ],
    products: [
        // Headless client API. This is what an integrating application needs.
        .library(name: "PaspoID", targets: ["PaspoID"]),
        // Ready-made "Sign in with Paspo ID" button (SwiftUI + UIKit).
        .library(name: "PaspoIDUI", targets: ["PaspoIDUI"]),
        // Wire contract shared by the client SDK and the Paspo ID app itself.
        // Integrating applications should not depend on this directly.
        .library(name: "PaspoIDWire", targets: ["PaspoIDWire"]),

        // Dynamic mirrors of the products above. They exist so `scripts/build-xcframework.sh`
        // can archive real `.framework` bundles; SwiftPM consumers should use the plain
        // products and let the build system pick the linkage.
        .library(name: "PaspoIDWire-Dynamic", type: .dynamic, targets: ["PaspoIDWire"]),
        .library(name: "PaspoID-Dynamic", type: .dynamic, targets: ["PaspoID"]),
        .library(name: "PaspoIDUI-Dynamic", type: .dynamic, targets: ["PaspoIDUI"]),
    ],
    targets: [
        .target(name: "PaspoIDWire"),
        .target(name: "PaspoID", dependencies: ["PaspoIDWire"]),
        .target(name: "PaspoIDUI", dependencies: ["PaspoID"]),
        .testTarget(name: "PaspoIDTests", dependencies: ["PaspoID", "PaspoIDWire"]),
    ]
)

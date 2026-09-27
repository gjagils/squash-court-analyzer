// swift-tools-version: 5.9
import PackageDescription

// Phase 1 of the Android port (see docs/android-port.md): the pure,
// UI/platform-independent rules of the app, with no SwiftUI, SwiftData or
// CloudKit. This is the module Skip will transpile to Kotlin for Android;
// the app target links it and no behaviour should change on iOS.
let package = Package(
    name: "SquashAnalyzerCore",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SquashAnalyzerCore", targets: ["SquashAnalyzerCore"]),
    ],
    targets: [
        .target(name: "SquashAnalyzerCore"),
        .testTarget(name: "SquashAnalyzerCoreTests", dependencies: ["SquashAnalyzerCore"]),
    ]
)

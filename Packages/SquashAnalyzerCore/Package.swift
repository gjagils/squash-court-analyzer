// swift-tools-version: 6.1
// This is a Skip (https://skip.dev) package.
import PackageDescription

// Phase 1 of the Android port (see docs/android-port.md): the pure,
// UI/platform-independent rules of the app, with no SwiftUI, SwiftData or
// CloudKit. This is the module Skip transpiles to Kotlin for Android; the
// app target links it and no behaviour should change on iOS.
let package = Package(
    name: "SquashAnalyzerCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SquashAnalyzerCore", type: .dynamic, targets: ["SquashAnalyzerCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/skiptools/skip.git", from: "1.9.11"),
        .package(url: "https://github.com/skiptools/skip-foundation.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "SquashAnalyzerCore", dependencies: [
            .product(name: "SkipFoundation", package: "skip-foundation"),
        ], plugins: [.plugin(name: "skipstone", package: "skip")]),
        .testTarget(name: "SquashAnalyzerCoreTests", dependencies: [
            "SquashAnalyzerCore",
            .product(name: "SkipTest", package: "skip"),
        ], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)

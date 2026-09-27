// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "SquashAnalyzerUI",
    defaultLocalization: "nl",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "SquashAnalyzerUI", targets: ["SquashAnalyzerUI"])],
    dependencies: [
        .package(path: "../SquashAnalyzerCore"),
        .package(url: "https://github.com/skiptools/skip.git", from: "1.9.11"),
        .package(url: "https://github.com/skiptools/skip-ui.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "SquashAnalyzerUI", dependencies: [
            .product(name: "SquashAnalyzerCore", package: "SquashAnalyzerCore"),
            .product(name: "SkipUI", package: "skip-ui"),
        ], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)

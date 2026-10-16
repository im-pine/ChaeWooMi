// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChaeWooMiCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ChaeWooMiCore", targets: ["ChaeWooMiCore"])
    ],
    targets: [
        .target(name: "ChaeWooMiCore"),
        .testTarget(name: "ChaeWooMiCoreTests", dependencies: ["ChaeWooMiCore"])
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChaeWooMiCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ChaeWooMiCore", targets: ["ChaeWooMiCore"])
    ],
    dependencies: [
        // swift-6.0.3-RELEASE 태그 (Swift 6.0.3 툴체인과 맞춤)
        .package(
            url: "https://github.com/swiftlang/swift-markdown.git",
            revision: "907674c2ae2d24c32fba50101821b1a7fdd291e2"
        )
    ],
    targets: [
        .target(
            name: "ChaeWooMiCore",
            dependencies: [.product(name: "Markdown", package: "swift-markdown")],
            resources: [.copy("Sites/Resources/sites.default.json")]
        ),
        .testTarget(name: "ChaeWooMiCoreTests", dependencies: ["ChaeWooMiCore"])
    ]
)

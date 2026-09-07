// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThoughtCore",
    platforms: [.iOS(.v16)],
    products: [.library(name: "ThoughtCore", targets: ["ThoughtCore"])],
    targets: [
        .target(name: "ThoughtCore", path: "ThoughtCore"),
        .testTarget(name: "ThoughtCoreTests", dependencies: ["ThoughtCore"], path: "ThoughtCoreTests")
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThoughtCore",
    platforms: [.iOS(.v16), .macOS(.v10_15)],
    products: [.library(name: "ThoughtCore", targets: ["ThoughtCore"])],
    targets: [
        .systemLibrary(name: "CSQLite", path: "CSQLite"),
        .target(name: "ThoughtCore", dependencies: ["CSQLite"], path: "ThoughtCore"),
        .testTarget(name: "ThoughtCoreTests", dependencies: ["ThoughtCore"], path: "ThoughtCoreTests")
    ]
)

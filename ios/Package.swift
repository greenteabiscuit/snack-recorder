// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SnackRecorderCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "SnackRecorderCore", targets: ["SnackRecorderCore"])],
    targets: [
        .target(name: "SnackRecorderCore", path: "Core"),
        .testTarget(name: "SnackRecorderCoreTests", dependencies: ["SnackRecorderCore"], path: "Tests")
    ]
)

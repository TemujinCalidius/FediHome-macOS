// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FediHomeKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "FediHomeKit", targets: ["FediHomeKit"]),
    ],
    targets: [
        .target(name: "FediHomeKit"),
        .testTarget(
            name: "FediHomeKitTests",
            dependencies: ["FediHomeKit"],
            resources: [.process("Fixtures")]
        ),
    ]
)

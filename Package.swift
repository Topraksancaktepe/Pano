// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Pano",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Pano", targets: ["Pano"]),
        .executable(name: "PanoControl", targets: ["PanoControl"])
    ],
    targets: [
        .target(name: "PanoCore"),
        .executableTarget(name: "Pano", dependencies: ["PanoCore"]),
        .executableTarget(name: "PanoControl"),
        .testTarget(name: "PanoCoreTests", dependencies: ["PanoCore"])
    ]
)

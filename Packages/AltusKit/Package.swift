// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AltusKit",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "AltusKit", targets: ["AltusKit"])
    ],
    targets: [
        .target(name: "AltusKit"),
        .testTarget(name: "AltusKitTests", dependencies: ["AltusKit"])
    ]
)

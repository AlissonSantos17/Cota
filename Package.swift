// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Cota",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Cota",
            targets: ["Cota"]
        )
    ],
    targets: [
        .target(
            name: "CotaKit"
        ),
        .executableTarget(
            name: "Cota",
            dependencies: ["CotaKit"]
        ),
        .testTarget(
            name: "CotaKitTests",
            dependencies: ["CotaKit"]
        )
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Cota",
    defaultLocalization: "pt-BR",
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
        // The strings live here rather than in the app target: number formats,
        // menu bar notes and notifications are built in CotaKit, and they have
        // to follow the language the person picked too.
        .target(
            name: "CotaKit",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "Cota",
            dependencies: ["CotaKit"]
        ),
        .testTarget(
            name: "CotaKitTests",
            dependencies: ["CotaKit"]
        ),
    ]
)

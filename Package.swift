// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ferrous",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ferrous", targets: ["ferrous"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.2"),
        .package(url: "https://github.com/soto-project/soto.git", from: "6.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "ferrous",
            dependencies: [
                "Yams",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SotoEKS", package: "soto"),
                .product(name: "SotoCore", package: "soto")
            ],
            path: "ferrous",
            resources: [
                .process("App/Assets.xcassets"),
                .process("Resources/default.yaml"),
                .process("Info.plist"),
                .process("ferrous.entitlements")
            ]
        )
    ]
)
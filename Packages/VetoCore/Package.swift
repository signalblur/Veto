// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VetoCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "VetoCore",
            targets: ["VetoCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.12.0"),
    ],
    targets: [
        .target(
            name: "VetoCore",
            path: "Sources/VetoCore",
            resources: [
                .copy("Packs"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "VetoCoreTests",
            dependencies: [
                "VetoCore",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/VetoCoreTests",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Vox",
    defaultLocalization: "pt-BR",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "VoxDomain",
            targets: ["VoxDomain"]
        ),
        .library(
            name: "VoxUI",
            targets: ["VoxUI"]
        ),
        .executable(
            name: "VoxApp",
            targets: ["VoxApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/jedisct1/swift-sodium.git", exact: "0.11.0")
    ],
    targets: [
        .target(
            name: "VoxDomain",
            dependencies: [
                .product(name: "Clibsodium", package: "swift-sodium")
            ],
            path: "src/VoxDomain"
        ),
        .target(
            name: "VoxUI",
            dependencies: ["VoxDomain"],
            path: "src/VoxUI"
        ),
        .executableTarget(
            name: "VoxApp",
            dependencies: ["VoxDomain", "VoxUI"],
            path: "src/VoxApp"
        ),
        .testTarget(
            name: "VoxTests",
            dependencies: ["VoxDomain", "VoxUI"],
            path: "Tests/VoxTests"
        )
    ]
)

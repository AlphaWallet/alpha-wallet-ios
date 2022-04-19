// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "WalletConnect",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "WalletConnect",
            targets: ["WalletConnect"]),
    ],
    targets: [
        .target(
            name: "WalletConnect",
            dependencies: ["Relayer", "WalletConnectUtils", "WalletConnectKMS"],
            path: "Sources/WalletConnect"),
        .target(
            name: "Relayer",
            dependencies: ["WalletConnectUtils"],
            path: "Sources/Relayer"),
        .target(
            name: "WalletConnectKMS",
            dependencies: ["WalletConnectUtils"],
            path: "Sources/WalletConnectKMS"),
        .target(
            name: "WalletConnectUtils",
            dependencies: []),
        .testTarget(
            name: "WalletConnectTests",
            dependencies: ["WalletConnect", "TestingUtils", "WalletConnectKMS"]),
        .testTarget(
            name: "IntegrationTests",
            dependencies: ["WalletConnect", "TestingUtils", "WalletConnectKMS"]),
        .testTarget(
            name: "RelayerTests",
            dependencies: ["Relayer", "WalletConnectUtils", "TestingUtils"]),
        .testTarget(
            name: "WalletConnectKMSTests",
            dependencies: ["WalletConnectKMS", "WalletConnectUtils", "TestingUtils"]),
        .target(
            name: "TestingUtils",
            dependencies: ["WalletConnectUtils", "WalletConnectKMS"],
            path: "Tests/TestingUtils"),
    ],
    swiftLanguageVersions: [.v5]
)

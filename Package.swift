// swift-tools-version: 5.9

import PackageDescription

var products: [Product] = [
    .executable(name: "usage-monitor", targets: ["UsageMonitorCLI"]),
    .library(name: "UsageMonitorCore", targets: ["UsageMonitorCore"]),
]

#if os(macOS)
products.insert(.executable(name: "UsageMonitor", targets: ["UsageMonitor"]), at: 0)
#endif

var targets: [Target] = [
    .target(
        name: "UsageMonitorCore",
        dependencies: [
            .product(name: "Crypto", package: "swift-crypto"),
        ],
        path: "Sources/UsageMonitorCore"
    ),
    .executableTarget(
        name: "UsageMonitorCLI",
        dependencies: ["UsageMonitorCore"],
        path: "Sources/UsageMonitorCLI"
    ),
    .testTarget(
        name: "UsageMonitorCoreTests",
        dependencies: ["UsageMonitorCore"],
        path: "Tests/UsageMonitorCoreTests"
    ),
    .testTarget(
        name: "UsageMonitorCLITests",
        dependencies: ["UsageMonitorCLI", "UsageMonitorCore"],
        path: "Tests/UsageMonitorCLITests"
    ),
]

#if os(macOS)
targets.insert(
    .executableTarget(
        name: "UsageMonitor",
        dependencies: ["UsageMonitorCore"],
        path: "Sources/UsageMonitor"
    ),
    at: 1
)
targets.append(
    .testTarget(
        name: "UsageMonitorTests",
        dependencies: ["UsageMonitor", "UsageMonitorCore"],
        path: "Tests/UsageMonitorTests"
    )
)
#endif

let package = Package(
    name: "UsageMonitor",
    platforms: [
        .macOS(.v13)
    ],
    products: products,
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.10.0"),
    ],
    targets: targets
)

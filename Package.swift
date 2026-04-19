// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ZhiPuMonitor",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ZhiPuMonitor",
            path: "Sources/ZhiPuMonitor",
            resources: [.copy("Resources")],
            linkerSettings: [.linkedFramework("IOKit")]
        )
    ]
)

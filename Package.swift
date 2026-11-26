// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "macTools",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "macTools", targets: ["MacTools"])],
    targets: [
        .target(name: "FinderKeys", publicHeadersPath: "include", linkerSettings: [
            .linkedFramework("AppKit"), .linkedFramework("ApplicationServices"), .linkedFramework("Carbon")
        ]),
        .target(name: "MacToolsCore"),
        .executableTarget(name: "MacTools", dependencies: ["MacToolsCore", "FinderKeys"],
                          linkerSettings: [.linkedFramework("SwiftUI")]),
        .executableTarget(name: "MacToolsUpdate", dependencies: ["MacToolsCore"], path: "Sources/MacToolsUpdater"),
        .executableTarget(name: "MacToolsCoreTests", dependencies: ["MacToolsCore"], path: "Tests/MacToolsCoreTests")
    ]
)

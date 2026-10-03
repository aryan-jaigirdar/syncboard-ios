// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SyncboardCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "SyncboardCore", targets: ["SyncboardCore"])],
    targets: [
        .target(name: "SyncboardCore"),
        .testTarget(name: "SyncboardCoreTests", dependencies: ["SyncboardCore"], resources: [.copy("sync-contract.json")])
    ]
)

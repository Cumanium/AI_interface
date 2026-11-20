// swift-tools-version: 6.0
import PackageDescription

// UI や MLX に依存しないロジック（台本・文字送り・設定・計測値）をまとめたパッケージ。
// Linux でも `swift test` でテストできるよう、Foundation 以外に依存しない。
let package = Package(
    name: "PropCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PropCore", targets: ["PropCore"])
    ],
    targets: [
        .target(name: "PropCore"),
        .testTarget(name: "PropCoreTests", dependencies: ["PropCore"]),
    ]
)

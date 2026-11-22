// swift-tools-version: 5.10
// 変換処理だけをまとめたパッケージ。アプリ本体から切り離しておき、将来は無音カメラからも読み込めるようにする
import PackageDescription

let package = Package(
    name: "IllustrationKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "IllustrationKit", targets: ["IllustrationKit"]),
    ],
    targets: [
        .target(name: "IllustrationKit"),
        // ステップ1の試作用。Mac 上で手元の写真をまとめて変換し、結果を並べて見る
        .executableTarget(name: "IllustPrototype", dependencies: ["IllustrationKit"]),
        .testTarget(name: "IllustrationKitTests", dependencies: ["IllustrationKit"]),
    ]
)
